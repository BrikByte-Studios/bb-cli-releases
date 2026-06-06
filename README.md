# BrikByteOS bb Public Releases

This repository is the public distribution surface for the BrikByteOS `bb` CLI.

It provides public installer scripts, public release downloads, checksums, and verification material for users who want to install `bb`.

---

## Purpose

This repository exists so users can install BrikByteOS `bb` without needing access to the private source/build repository.

The private source repository remains:

```text
BrikByte-Studios/bb-cli
```

This public distribution repository is:

```text
BrikByte-Studios/bb-cli-releases
```

Core rule:

```text
bb-cli builds.
bb-cli-releases distributes.
```

This repository distributes trusted release outputs.

It does not build them.

---

## Install

### Linux/macOS

```bash
curl -sSL https://raw.githubusercontent.com/BrikByte-Studios/bb-cli-releases/main/install.sh | bash
```

### Windows PowerShell

```powershell
iwr https://raw.githubusercontent.com/BrikByte-Studios/bb-cli-releases/main/install.ps1 -useb | iex
```

---

## Inspect Before Running

Remote installer commands are convenient, but you may want to inspect the script before running it.

### Linux/macOS

```bash
curl -sSL https://raw.githubusercontent.com/BrikByte-Studios/bb-cli-releases/main/install.sh -o install.sh
less install.sh
bash install.sh --dry-run
bash install.sh
```

### Windows PowerShell

```powershell
iwr https://raw.githubusercontent.com/BrikByte-Studios/bb-cli-releases/main/install.ps1 -OutFile install.ps1
notepad .\install.ps1
.\install.ps1 -DryRun
.\install.ps1
```

---

## Install a Specific Version

### Linux/macOS

```bash
bash install.sh --version v0.1.0
```

### Windows PowerShell

```powershell
.\install.ps1 -Version v0.1.0
```

---

## Install a Release Candidate

Release candidates are not installed by default.

To install a release candidate, explicitly request the exact RC version.

### Linux/macOS

```bash
bash install.sh --version v0.2.0-rc.1
```

### Windows PowerShell

```powershell
.\install.ps1 -Version v0.2.0-rc.1
```

A verified release candidate is still a prerelease build.

Use RC builds for testing and validation.

---

## Dry Run

Dry-run mode prints what the installer would do without installing `bb`.

### Linux/macOS

```bash
bash install.sh --dry-run
```

### Windows PowerShell

```powershell
.\install.ps1 -DryRun
```

Dry-run mode should not:

* install `bb`
* extract archives
* write install files
* modify shell profiles
* modify PATH

---

## Custom Install Directory

### Linux/macOS

```bash
bash install.sh --install-dir "$HOME/bin"
```

### Windows PowerShell

```powershell
.\install.ps1 -InstallDir "$HOME\.local\bin"
```

---

## What Gets Published Here

Public releases may include:

```text
brikbyteos_<version>_linux_amd64.tar.gz
brikbyteos_<version>_linux_arm64.tar.gz
brikbyteos_<version>_darwin_amd64.tar.gz
brikbyteos_<version>_darwin_arm64.tar.gz
brikbyteos_<version>_windows_amd64.zip
checksums.txt
```

When signing material is enabled, releases may also include:

```text
*.sigstore.json
```

Examples:

```text
brikbyteos_v0.1.0_linux_amd64.tar.gz.sigstore.json
brikbyteos_v0.1.0_windows_amd64.zip.sigstore.json
checksums.txt.sigstore.json
```

---

## Supported Platforms

| OS      | Architecture | Artifact  |
| ------- | ------------ | --------- |
| Linux   | amd64        | `.tar.gz` |
| Linux   | arm64        | `.tar.gz` |
| macOS   | amd64        | `.tar.gz` |
| macOS   | arm64        | `.tar.gz` |
| Windows | amd64        | `.zip`    |

Unsupported by default:

```text
windows/arm64
linux/armv7
alpine/musl
```

---

## Security

Installer security behavior:

* latest stable release is installed by default
* prereleases are excluded by default
* explicit version install is supported
* release candidates require an exact version
* `checksums.txt` is downloaded from the same release
* SHA-256 checksum verification runs before extraction
* installation stops on checksum mismatch
* shell profiles are not modified automatically
* optional signature/provenance verification may be supported

Checksum verification is mandatory.

Signature and attestation verification may be available when release assets include the required verification material.

---

## Verify Installation

After installation, run:

```bash
bb version
```

Expected output should include:

```text
BrikByteOS bb
Version:
Commit:
Built:
OS/Arch:
```

---

## Repository Responsibility

This repository should contain:

```text
README.md
LICENSE
Makefile
install.sh
install.ps1
docs/install/README.md
scripts/verify-distribution-repo.sh
```

This repository should not contain:

```text
go.mod
go.sum
cmd/
internal/
.goreleaser.yaml
```

Reason:

This is a public distribution repository.

It is not the source/build repository.

---

## Release Authority

Release artifacts are built by the private `bb-cli` release pipeline and published here for public download.

This repository must not independently build, rebuild, or modify release binaries.

---

## Troubleshooting

If installation fails:

* confirm the requested version exists in GitHub Releases
* confirm your OS and architecture are supported
* confirm the release contains the expected artifact
* confirm `checksums.txt` exists
* confirm checksum verification passes
* confirm the install directory is writable
* confirm the install directory is on your PATH

If `bb` installs but is not available globally, add the install directory to your PATH.

Default Linux/macOS install directory:

```text
$HOME/.local/bin
```

Default Windows install directory:

```text
$HOME\.local\bin
```

---

## License

This repository is licensed under the MIT License.

See `LICENSE` for details.
