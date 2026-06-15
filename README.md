# BrikByteOS `bb` Public Releases

<div align="center">

# BrikByteOS `bb`

**Install the BrikByteOS CLI — Release Confidence Infrastructure for Modern Engineering Teams**

[![bb-cli-releases](https://img.shields.io/badge/bb--cli--releases-public%20distribution-success)](https://github.com/BrikByte-Studios/bb-cli-releases)
[![Latest Release](https://img.shields.io/github/v/release/BrikByte-Studios/bb-cli-releases?label=latest%20release)](https://github.com/BrikByte-Studios/bb-cli-releases/releases)
[![Platform](https://img.shields.io/badge/platform-linux%20%7C%20macOS%20%7C%20windows-blue)]()
[![Checksum](https://img.shields.io/badge/checksums-SHA--256-important)]()
[![License](https://img.shields.io/github/license/BrikByte-Studios/bb-cli-releases)](LICENSE)

</div>

---

## What is this repository?

This repository is the public distribution home for the BrikByteOS `bb` CLI.

It exists so users can install `bb` safely without needing access to the private source and build repository.

```text
bb-cli builds.
bb-cli-releases distributes.
```

That is the core rule.

The private source/build repository is:

```text
BrikByte-Studios/bb-cli
```

The public distribution repository is:

```text
BrikByte-Studios/bb-cli-releases
```

This repository does not build BrikByteOS.

It distributes trusted release outputs.

---

## What is BrikByteOS?

BrikByteOS is Release Confidence Infrastructure.

It helps engineering teams answer one serious question:

> Is this release actually ready to ship?

Modern teams already have CI pipelines, tests, security scans, performance tests, and API checks. The real problem is that those outputs are often scattered everywhere.

BrikByteOS turns that scattered evidence into a clearer release decision.

```text
Tests
Security
Performance
API
UI
CI Metadata
      ↓
BrikByteOS
      ↓
Release Confidence
```

The CLI command is:

```bash
bb
```

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

After installation:

```bash
bb version
```

Expected output should include:

```text
BrikByteOS bb
Version
Commit
Built
OS/Arch
```

---

## Inspect Before Running

Remote install commands are convenient, but it is wise to inspect scripts before running them.

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
bash install.sh --version v0.1.5
```

### Windows PowerShell

```powershell
.\install.ps1 -Version v0.1.5
```

---

## Install a Release Candidate

Release candidates are not installed by default.

To install a release candidate, request the exact RC version.

### Linux/macOS

```bash
bash install.sh --version v0.2.0-rc.1
```

### Windows PowerShell

```powershell
.\install.ps1 -Version v0.2.0-rc.1
```

A release candidate may be verified and still be a prerelease build.

Use RC builds for testing, validation, and early feedback.

---

## Dry Run

Dry-run mode shows what the installer would do without installing anything.

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

Default Linux/macOS install directory:

```text
$HOME/.local/bin
```

Default Windows install directory:

```text
$HOME\.local\bin
```

Make sure your install directory is on your PATH.

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

## Published Release Assets

A normal release may include:

```text
brikbyteos_<version>_linux_amd64.tar.gz
brikbyteos_<version>_linux_arm64.tar.gz
brikbyteos_<version>_darwin_amd64.tar.gz
brikbyteos_<version>_darwin_arm64.tar.gz
brikbyteos_<version>_windows_amd64.zip
checksums.txt
```

When signing and provenance material is enabled, releases may also include:

```text
*.sigstore.json
checksums.txt.sigstore.json
```

Example:

```text
brikbyteos_v0.1.5_linux_amd64.tar.gz
brikbyteos_v0.1.5_linux_amd64.tar.gz.sigstore.json
checksums.txt
checksums.txt.sigstore.json
```

---

## Security Model

Installer security behavior:

* latest stable release is installed by default
* prereleases are excluded by default
* release candidates require an exact version
* explicit version install is supported
* `checksums.txt` is downloaded from the same release
* SHA-256 checksum verification runs before extraction
* installation stops on checksum mismatch
* shell profiles are not modified automatically
* PATH is not silently changed
* optional signature/provenance verification may be supported when release assets provide it

Checksum verification is mandatory.

This matters because installers should be convenient, but they must not be reckless.

---

## Verify Installation

Run:

```bash
bb version
```

Example output:

```text
BrikByteOS bb

Version  v0.1.5
Commit   abc1234
Built    2026-06-13T10:00:00Z
OS/Arch  linux/amd64
```

Then check help:

```bash
bb --help
```

---

## Quick First Run

Inside a project folder:

```bash
bb init
bb doctor
bb run --all
bb gate evaluate
bb report generate
```

This gives you the basic BrikByteOS release confidence workflow:

```text
Initialize
   ↓
Diagnose
   ↓
Collect Evidence
   ↓
Evaluate Gates
   ↓
Generate Reports
```

---

## What `bb` Generates

A BrikByteOS run creates local evidence under:

```text
.bb/runs/<run-id>/
```

Example:

```text
.bb/
  runs/
    <run-id>/
      manifest.json
      gate-result.json
      raw/
      normalized/
      logs/
      artifacts/
      reports/
        report.json
        report.html
        summary.md
        junit.xml
```

These files help teams inspect release evidence instead of guessing from scattered logs.

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

This is the public distribution repository.

It is not the source/build repository.

---

## Release Authority

Release artifacts are built by the private `bb-cli` release pipeline and published here for public download.

This repository must not independently build, rebuild, or modify release binaries.

The rule remains:

```text
Source and build logic live in bb-cli.
Public install and distribution live in bb-cli-releases.
```

---

## Troubleshooting

If installation fails, check:

* the requested version exists in GitHub Releases
* your OS and architecture are supported
* the release contains the expected artifact
* `checksums.txt` exists
* checksum verification passes
* the install directory is writable
* the install directory is on your PATH

If `bb` installs but is not available globally, add the install directory to your PATH.

Linux/macOS example:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Windows PowerShell example:

```powershell
$env:Path += ";$HOME\.local\bin"
```

---

## Who is BrikByteOS For?

BrikByteOS is for teams that care about release confidence:

* software engineers
* QA engineers
* DevOps engineers
* platform teams
* release managers
* engineering leads
* software consultancies
* teams working in regulated environments

It is especially useful when a team needs more than:

```text
The pipeline is green.
```

They need:

```text
The release is ready.
```

---

## What BrikByteOS Is Not

BrikByteOS is not trying to replace GitHub Actions, GitLab CI, Jenkins, or Azure DevOps.

Those tools run workflows.

BrikByteOS evaluates release evidence.

```text
CI/CD runs the work.
BrikByteOS judges the release evidence.
```

---

## Project Philosophy

BrikByteOS is built on a simple belief:

> Good releases should be based on evidence, not vibes.

In real teams, especially growing teams, release confidence cannot depend only on someone saying:

```text
It should be fine.
```

BrikByteOS exists to make release decisions clearer, more repeatable, and more trustworthy.

---

## License

This repository is licensed under the MIT License.

See `LICENSE` for details.

---

## Maintainer

**BrikByte Studios**

Built from South Africa with a serious focus on software quality, release confidence, and engineering discipline.
