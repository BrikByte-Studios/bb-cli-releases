<#
.SYNOPSIS
Installs the BrikByteOS bb CLI on Windows.

.DESCRIPTION
Provides a secure, deterministic Windows installer for BrikByteOS bb.

The installer:
- resolves the latest stable release by default
- supports explicit version installation
- never installs prereleases by default
- downloads the RM.9 Windows archive
- downloads checksums.txt from the same release
- verifies SHA-256 before extraction
- extracts the archive
- installs bb.exe into a user-local install directory
- prints PATH guidance
- runs bb version after install
- supports dry-run mode
- optionally verifies signature/provenance when configured

.PARAMETER Version
Exact version to install, for example v0.1.0 or v0.2.0-rc.1.

.PARAMETER InstallDir
Destination directory. Defaults to $HOME\.local\bin.

.PARAMETER Repo
GitHub owner/repo. Defaults to BrikByte-Studios/bb-cli.

.PARAMETER DryRun
Print planned actions without downloading, extracting, or installing.

.PARAMETER VerifySignature
Enables optional signature/provenance verification.

.PARAMETER SignatureMode
Verification mode. Supported values: cosign-bundle, github-attestation.

.PARAMETER SignatureRequired
Requires signature/provenance verification.

.EXAMPLE
iwr https://raw.githubusercontent.com/BrikByte-Studios/brikbyteos-cli-releases/main/install.ps1 -useb | iex

.EXAMPLE
.\install.ps1 -Version v0.1.0

.EXAMPLE
.\install.ps1 -Version v0.1.0 -DryRun

.EXAMPLE
.\install.ps1 -Version v0.1.0 -VerifySignature -SignatureMode cosign-bundle
#>

[CmdletBinding()]
param(
    [string]$Version = "",
    [string]$InstallDir = "$HOME\.local\bin",
    [string]$Repo = "BrikByte-Studios/bb-cli-releases",
    [switch]$DryRun,
    [switch]$VerifySignature,
    [ValidateSet("cosign-bundle", "github-attestation")]
    [string]$SignatureMode = "cosign-bundle",
    [switch]$SignatureRequired
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($SignatureRequired) {
    $VerifySignature = $true
}

function Fail {
    param([string]$Message)

    Write-Error "BrikByteOS installer failed: $Message"
    exit 1
}

function Log {
    param([string]$Message)

    Write-Host "brikbyteos-installer: $Message"
}

function Test-StableVersion {
    param([string]$Candidate)

    return $Candidate -match '^v[0-9]+\.[0-9]+\.[0-9]+$'
}

function Test-RcVersion {
    param([string]$Candidate)

    return $Candidate -match '^v[0-9]+\.[0-9]+\.[0-9]+-rc\.([1-9]|[1-9][0-9]+)$'
}

function Validate-RequestedVersion {
    param([string]$Candidate)

    if (Test-StableVersion $Candidate) {
        return
    }

    if (Test-RcVersion $Candidate) {
        Log "explicit release candidate install requested: $Candidate"
        Log "release candidates are prerelease builds and are not installed by default"
        return
    }

    Fail "invalid version '$Candidate'. Expected vMAJOR.MINOR.PATCH or vMAJOR.MINOR.PATCH-rc.N"
}

function Resolve-LatestStableVersion {
    $ApiUrl = "https://api.github.com/repos/$Repo/releases/latest"

    $Response = Invoke-RestMethod -Uri $ApiUrl -Headers @{
        "User-Agent" = "brikbyteos-installer"
    }

    $Resolved = [string]$Response.tag_name

    if ([string]::IsNullOrWhiteSpace($Resolved)) {
        Fail "could not resolve latest stable version from $ApiUrl"
    }

    if (-not (Test-StableVersion $Resolved)) {
        Fail "latest stable endpoint returned non-stable version: $Resolved"
    }

    return $Resolved
}

function Detect-Arch {
    $Arch = $env:PROCESSOR_ARCHITECTURE

    switch -Regex ($Arch) {
        'AMD64' { return "amd64" }
        'x64' { return "amd64" }
        default { Fail "unsupported Windows architecture: $Arch" }
    }
}

function Download-File {
    param(
        [string]$Url,
        [string]$Output
    )

    if ($DryRun) {
        Log "dry-run: would download $Url -> $Output"
        return
    }

    Invoke-WebRequest -Uri $Url -OutFile $Output -UseBasicParsing
}

function Get-ExpectedChecksum {
    param(
        [string]$ChecksumFile,
        [string]$ArtifactName
    )

    if (-not (Test-Path $ChecksumFile)) {
        Fail "checksum file missing: $ChecksumFile"
    }

    if ($ArtifactName.Contains("/") -or $ArtifactName.Contains("\")) {
        Fail "artifact name must be a basename for checksum lookup: $ArtifactName"
    }

    $Matches = Get-Content $ChecksumFile | Where-Object {
        $Parts = $_ -split '\s+'
        $Parts.Count -ge 2 -and $Parts[1] -eq $ArtifactName
    }

    if ($Matches.Count -eq 0) {
        Fail "checksum file does not contain artifact: $ArtifactName"
    }

    if ($Matches.Count -ne 1) {
        Fail "checksum file must contain exactly one entry for $ArtifactName; found $($Matches.Count)"
    }

    $ExpectedHash = (($Matches[0] -split '\s+')[0]).ToLowerInvariant()

    if ($ExpectedHash -notmatch '^[a-fA-F0-9]{64}$') {
        Fail "invalid SHA-256 checksum format for $ArtifactName"
    }

    return $ExpectedHash
}

function Verify-Checksum {
    param(
        [string]$ChecksumFile,
        [string]$ArtifactFile
    )

    if ($DryRun) {
        Log "dry-run: would verify checksum for $ArtifactFile"
        return
    }

    if (-not (Test-Path $ArtifactFile)) {
        Fail "artifact file missing: $ArtifactFile"
    }

    $ArtifactName = Split-Path $ArtifactFile -Leaf
    $ExpectedHash = Get-ExpectedChecksum -ChecksumFile $ChecksumFile -ArtifactName $ArtifactName
    $ActualHash = (Get-FileHash -Algorithm SHA256 -Path $ArtifactFile).Hash.ToLowerInvariant()

    if ($ActualHash -ne $ExpectedHash) {
        Fail "checksum mismatch for $ArtifactName. Expected $ExpectedHash, got $ActualHash. Refusing to extract or install."
    }

    Log "checksum verified: $ArtifactName"
}

function Verify-CosignBundleSignature {
    param(
        [string]$ArtifactFile,
        [string]$BundleFile
    )

    if ($DryRun) {
        Log "dry-run: would verify Cosign bundle $BundleFile for $ArtifactFile"
        return
    }

    if (-not (Test-Path $ArtifactFile)) {
        Fail "artifact file missing: $ArtifactFile"
    }

    if (-not (Test-Path $BundleFile)) {
        if ($SignatureRequired) {
            Fail "signature bundle missing and signature verification is required: $BundleFile"
        }

        Log "signature bundle missing; skipping optional signature verification: $BundleFile"
        return
    }

    $Cosign = Get-Command cosign -ErrorAction SilentlyContinue
    if ($null -eq $Cosign) {
        Fail "required command not found: cosign"
    }

    & cosign verify-blob --bundle $BundleFile $ArtifactFile

    if ($LASTEXITCODE -ne 0) {
        Fail "Cosign signature verification failed for $ArtifactFile"
    }

    Log "Cosign signature bundle verified: $(Split-Path $ArtifactFile -Leaf)"
}

function Verify-GitHubAttestation {
    param([string]$ArtifactFile)

    if ($DryRun) {
        Log "dry-run: would verify GitHub attestation for $ArtifactFile"
        return
    }

    if (-not (Test-Path $ArtifactFile)) {
        Fail "artifact file missing: $ArtifactFile"
    }

    $Gh = Get-Command gh -ErrorAction SilentlyContinue
    if ($null -eq $Gh) {
        Fail "required command not found: gh"
    }

    & gh attestation verify $ArtifactFile -R $Repo

    if ($LASTEXITCODE -ne 0) {
        Fail "GitHub artifact attestation verification failed for $ArtifactFile"
    }

    Log "GitHub artifact attestation verified: $(Split-Path $ArtifactFile -Leaf)"
}

function Verify-OptionalSignature {
    param(
        [string]$ArtifactFile,
        [string]$BundleFile
    )

    if (-not $VerifySignature -and -not $SignatureRequired) {
        Log "signature verification not requested; checksum verification remains enforced"
        return
    }

    switch ($SignatureMode) {
        "cosign-bundle" {
            Verify-CosignBundleSignature -ArtifactFile $ArtifactFile -BundleFile $BundleFile
        }
        "github-attestation" {
            Verify-GitHubAttestation -ArtifactFile $ArtifactFile
        }
        default {
            Fail "unsupported signature verification mode: $SignatureMode"
        }
    }
}

function Extract-ArchiveFile {
    param(
        [string]$Archive,
        [string]$TargetDir
    )

    if ($DryRun) {
        Log "dry-run: would extract $Archive -> $TargetDir"
        return
    }

    New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
    Expand-Archive -Path $Archive -DestinationPath $TargetDir -Force
}

function Install-Binary {
    param(
        [string]$ExtractedDir,
        [string]$DestinationDir
    )

    $ArchiveRoot = Join-Path $ExtractedDir "brikbyteos"
    $SourceBinary = Join-Path $ArchiveRoot "bb.exe"
    $DestinationBinary = Join-Path $DestinationDir "bb.exe"

    if ($DryRun) {
        Log "dry-run: would install $SourceBinary -> $DestinationBinary"
        return
    }

    if (-not (Test-Path $SourceBinary)) {
        Fail "extracted binary missing: $SourceBinary"
    }

    New-Item -ItemType Directory -Force -Path $DestinationDir | Out-Null
    Copy-Item -Path $SourceBinary -Destination $DestinationBinary -Force
}

function Print-PathGuidance {
    $PathParts = $env:PATH -split ';'

    if ($PathParts -notcontains $InstallDir) {
        Log "PATH guidance: add this directory to your PATH if bb is not globally available:"
        Write-Host $InstallDir
    }
}

$Os = "windows"
$Arch = Detect-Arch

if ([string]::IsNullOrWhiteSpace($Version)) {
    if ($DryRun) {
        $Version = "v0.0.0-dry-run"
        Log "dry-run: latest stable version resolution skipped"
    }
    else {
        $Version = Resolve-LatestStableVersion
        Log "latest stable version resolved: $Version"
    }
}
else {
    Validate-RequestedVersion $Version
}

if (Test-RcVersion $Version) {
    Log "installing explicitly requested RC version: $Version"
}
elseif (-not (Test-StableVersion $Version) -and -not $DryRun) {
    Fail "resolved version is neither stable nor valid RC: $Version"
}

$ArchiveName = "brikbyteos_${Version}_${Os}_${Arch}.zip"
$BaseUrl = "https://github.com/$Repo/releases/download/$Version"

$TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("brikbyteos-" + [System.Guid]::NewGuid().ToString())
$ArchivePath = Join-Path $TempDir $ArchiveName
$ChecksumPath = Join-Path $TempDir "checksums.txt"
$SignatureBundlePath = Join-Path $TempDir "$ArchiveName.sigstore.json"
$ExtractDir = Join-Path $TempDir "extract"

Log "repo: $Repo"
Log "version: $Version"
Log "os/arch: $Os/$Arch"
Log "artifact: $ArchiveName"
Log "install dir: $InstallDir"
Log "prereleases excluded by default: true"
Log "checksum verification: required"
Log "signature verification: $VerifySignature"
Log "signature mode: $SignatureMode"

try {
    if (-not $DryRun) {
        New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
    }

    Download-File "$BaseUrl/$ArchiveName" $ArchivePath
    Download-File "$BaseUrl/checksums.txt" $ChecksumPath

    if ($VerifySignature -and $SignatureMode -eq "cosign-bundle") {
        Download-File "$BaseUrl/$ArchiveName.sigstore.json" $SignatureBundlePath
    }

    Verify-Checksum $ChecksumPath $ArchivePath
    Verify-OptionalSignature $ArchivePath $SignatureBundlePath
    Extract-ArchiveFile $ArchivePath $ExtractDir
    Install-Binary $ExtractDir $InstallDir

    if ($DryRun) {
        Log "dry-run complete"
        exit 0
    }

    $InstalledBinary = Join-Path $InstallDir "bb.exe"
    Log "installed bb to $InstalledBinary"

    Print-PathGuidance

    & $InstalledBinary version
}
finally {
    if (-not $DryRun -and (Test-Path $TempDir)) {
        Remove-Item -Recurse -Force $TempDir
    }
}