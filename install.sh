#!/usr/bin/env bash

# install.sh installs the BrikByteOS `bb` CLI on Linux and macOS.
#
# Purpose:
#   Provide a secure, deterministic installer that downloads the correct
#   BrikByteOS release archive, verifies it before extraction, installs `bb`
#   into a user-local directory, and verifies the final installation.
#
# Security contract:
#   - Stable releases are installed by default.
#   - Prereleases are never installed by default.
#   - Explicit version installation is supported.
#   - RC installation is allowed only when the exact RC version is requested.
#   - Checksums are always verified before extraction.
#   - Checksum mismatch blocks installation.
#   - Optional signature/provenance verification can run when explicitly enabled.
#   - Shell profiles are not modified automatically.
#   - Root/admin install paths are not required by default.
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/BrikByte-Studios/bb-cli-releases/main/install.sh | bash
#   curl -sSL https://raw.githubusercontent.com/BrikByte-Studios/bb-cli-releases/main/install.sh | bash -s -- --version v0.1.0
#   curl -sSL https://raw.githubusercontent.com/BrikByte-Studios/bb-cli-releases/main/install.sh | bash -s -- --dry-run
#
# Environment overrides:
#   BRIKBYTEOS_REPO=BrikByte-Studios/bb-cli-releases
#   BRIKBYTEOS_INSTALL_DIR=$HOME/.local/bin
#   BRIKBYTEOS_SIGNATURE_MODE=cosign-bundle

set -euo pipefail

readonly default_repo="BrikByte-Studios/bb-cli-releases"
readonly binary_name="bb"

repo="${BRIKBYTEOS_REPO:-$default_repo}"
install_dir="${BRIKBYTEOS_INSTALL_DIR:-$HOME/.local/bin}"
version=""
dry_run="false"
verify_signature="false"
signature_required="false"
signature_mode="${BRIKBYTEOS_SIGNATURE_MODE:-cosign-bundle}"

fail() {
  echo "BrikByteOS installer failed: $*" >&2
  exit 1
}

log() {
  echo "brikbyteos-installer: $*"
}

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    fail "required command not found: ${command_name}"
  fi
}

usage() {
  cat <<'USAGE'
BrikByteOS bb installer

Usage:
  install.sh [options]

Options:
  --version <version>       Install exact version, e.g. v0.1.0 or v0.2.0-rc.1
  --install-dir <dir>       Install directory. Default: ~/.local/bin
  --repo <owner/repo>       GitHub repo. Default: BrikByte-Studios/bb-cli
  --dry-run                 Print planned actions without writing files
  --verify-signature        Optionally verify signature/provenance before extraction
  --signature-mode <mode>   cosign-bundle or github-attestation
  --signature-required      Require signature/provenance verification
  -h, --help                Show help

Default behavior:
  Without --version, installer resolves the latest stable GitHub Release.

RC behavior:
  Release candidates are never installed by default.
  To install an RC, explicitly pass the exact RC version:

    install.sh --version v0.2.0-rc.1

Security:
  Checksum verification is mandatory.
  Signature/provenance verification is optional unless --signature-required is used.
USAGE
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version)
        [[ $# -ge 2 ]] || fail "--version requires a value"
        version="$2"
        shift 2
        ;;
      --install-dir)
        [[ $# -ge 2 ]] || fail "--install-dir requires a value"
        install_dir="$2"
        shift 2
        ;;
      --repo)
        [[ $# -ge 2 ]] || fail "--repo requires a value"
        repo="$2"
        shift 2
        ;;
      --dry-run)
        dry_run="true"
        shift
        ;;
      --verify-signature)
        verify_signature="true"
        shift
        ;;
      --signature-mode)
        [[ $# -ge 2 ]] || fail "--signature-mode requires a value"
        signature_mode="$2"
        shift 2
        ;;
      --signature-required)
        verify_signature="true"
        signature_required="true"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail "unknown option: $1"
        ;;
    esac
  done
}

detect_os() {
  local uname_s
  uname_s="$(uname -s)"

  case "$uname_s" in
    Linux)
      echo "linux"
      ;;
    Darwin)
      echo "darwin"
      ;;
    *)
      fail "unsupported operating system: ${uname_s}"
      ;;
  esac
}

detect_arch() {
  local uname_m
  uname_m="$(uname -m)"

  case "$uname_m" in
    x86_64|amd64)
      echo "amd64"
      ;;
    arm64|aarch64)
      echo "arm64"
      ;;
    *)
      fail "unsupported architecture: ${uname_m}"
      ;;
  esac
}

is_stable_version() {
  local candidate="$1"
  [[ "$candidate" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

is_rc_version() {
  local candidate="$1"
  [[ "$candidate" =~ ^v[0-9]+\.[0-9]+\.[0-9]+-rc\.([1-9]|[1-9][0-9]+)$ ]]
}

validate_requested_version() {
  local candidate="$1"

  if is_stable_version "$candidate"; then
    return 0
  fi

  if is_rc_version "$candidate"; then
    log "explicit release candidate install requested: ${candidate}"
    log "release candidates are prerelease builds and are not installed by default"
    return 0
  fi

  fail "invalid version '${candidate}'. Expected vMAJOR.MINOR.PATCH or vMAJOR.MINOR.PATCH-rc.N"
}

resolve_latest_stable_version() {
  local api_url
  api_url="https://api.github.com/repos/${repo}/releases/latest"

  require_command curl

  local resolved
  resolved="$(
    curl -fsSL \
      -H "User-Agent: brikbyteos-installer" \
      "$api_url" \
      | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
      | head -n 1
  )"

  [[ -n "$resolved" ]] || fail "could not resolve latest stable version from ${api_url}"

  if ! is_stable_version "$resolved"; then
    fail "latest stable endpoint returned non-stable version: ${resolved}"
  fi

  echo "$resolved"
}

artifact_extension_for_os() {
  local os="$1"

  case "$os" in
    linux|darwin)
      echo "tar.gz"
      ;;
    *)
      fail "unsupported artifact extension for OS: ${os}"
      ;;
  esac
}

download_file() {
  local url="$1"
  local output="$2"

  require_command curl

  if [[ "$dry_run" == "true" ]]; then
    log "dry-run: would download ${url} -> ${output}"
    return 0
  fi

  curl -fL --retry 3 --retry-delay 2 -o "$output" "$url"
}

extract_expected_checksum() {
  local checksum_file="$1"
  local artifact_name="$2"

  [[ -f "$checksum_file" ]] || fail "checksum file missing: ${checksum_file}"

  if [[ "$artifact_name" == */* || "$artifact_name" == /* ]]; then
    fail "artifact name must be a basename for checksum lookup: ${artifact_name}"
  fi

  local line_count
  line_count="$(
    awk -v artifact="$artifact_name" '$2 == artifact { count++ } END { print count + 0 }' "$checksum_file"
  )"

  if [[ "$line_count" -eq 0 ]]; then
    fail "checksum file does not contain artifact: ${artifact_name}"
  fi

  if [[ "$line_count" -ne 1 ]]; then
    fail "checksum file must contain exactly one entry for ${artifact_name}; found ${line_count}"
  fi

  local expected_hash
  expected_hash="$(
    awk -v artifact="$artifact_name" '$2 == artifact { print $1 }' "$checksum_file"
  )"

  if [[ ! "$expected_hash" =~ ^[a-fA-F0-9]{64}$ ]]; then
    fail "invalid SHA-256 checksum format for ${artifact_name}"
  fi

  printf '%s\n' "$expected_hash"
}

compute_sha256() {
  local artifact_file="$1"

  [[ -f "$artifact_file" ]] || fail "artifact file missing: ${artifact_file}"

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$artifact_file" | awk '{ print $1 }'
    return 0
  fi

  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$artifact_file" | awk '{ print $1 }'
    return 0
  fi

  fail "required checksum command not found: sha256sum or shasum"
}

verify_checksum() {
  local checksum_file="$1"
  local artifact_file="$2"

  if [[ "$dry_run" == "true" ]]; then
    log "dry-run: would verify checksum for ${artifact_file}"
    return 0
  fi

  local artifact_name
  artifact_name="$(basename "$artifact_file")"

  local expected_hash
  local actual_hash

  expected_hash="$(extract_expected_checksum "$checksum_file" "$artifact_name")"
  actual_hash="$(compute_sha256 "$artifact_file")"

  if [[ "${actual_hash,,}" != "${expected_hash,,}" ]]; then
    fail "checksum mismatch for ${artifact_name}. Expected ${expected_hash}, got ${actual_hash}. Refusing to extract or install."
  fi

  log "checksum verified: ${artifact_name}"
}

validate_signature_mode() {
  case "$1" in
    cosign-bundle|github-attestation)
      return 0
      ;;
    *)
      fail "unsupported signature verification mode: $1. Expected cosign-bundle or github-attestation"
      ;;
  esac
}

verify_cosign_bundle_signature() {
  local artifact_file="$1"
  local bundle_file="$2"

  if [[ "$dry_run" == "true" ]]; then
    log "dry-run: would verify Cosign bundle ${bundle_file} for ${artifact_file}"
    return 0
  fi

  [[ -f "$artifact_file" ]] || fail "artifact file missing: ${artifact_file}"

  if [[ ! -f "$bundle_file" ]]; then
    if [[ "$signature_required" == "true" ]]; then
      fail "signature bundle missing and signature verification is required: ${bundle_file}"
    fi

    log "signature bundle missing; skipping optional signature verification: ${bundle_file}"
    return 0
  fi

  require_command cosign

  cosign verify-blob --bundle "$bundle_file" "$artifact_file"

  log "Cosign signature bundle verified: $(basename "$artifact_file")"
}

verify_github_attestation() {
  local artifact_file="$1"

  if [[ "$dry_run" == "true" ]]; then
    log "dry-run: would verify GitHub attestation for ${artifact_file}"
    return 0
  fi

  [[ -f "$artifact_file" ]] || fail "artifact file missing: ${artifact_file}"

  require_command gh

  gh attestation verify "$artifact_file" -R "$repo"

  log "GitHub artifact attestation verified: $(basename "$artifact_file")"
}

verify_optional_signature() {
  local artifact_file="$1"
  local bundle_file="$2"

  if [[ "$verify_signature" != "true" ]]; then
    log "signature verification not requested; checksum verification remains enforced"
    return 0
  fi

  validate_signature_mode "$signature_mode"

  case "$signature_mode" in
    cosign-bundle)
      verify_cosign_bundle_signature "$artifact_file" "$bundle_file"
      ;;
    github-attestation)
      verify_github_attestation "$artifact_file"
      ;;
  esac
}

extract_archive() {
  local archive="$1"
  local target_dir="$2"

  if [[ "$dry_run" == "true" ]]; then
    log "dry-run: would extract ${archive} -> ${target_dir}"
    return 0
  fi

  require_command tar

  mkdir -p "$target_dir"
  tar -xzf "$archive" -C "$target_dir"
}

install_binary() {
  local extracted_dir="$1"
  local destination_dir="$2"

  local source_binary="${extracted_dir}/brikbyteos/${binary_name}"
  local destination_binary="${destination_dir}/${binary_name}"

  if [[ "$dry_run" == "true" ]]; then
    log "dry-run: would install ${source_binary} -> ${destination_binary}"
    return 0
  fi

  [[ -f "$source_binary" ]] || fail "extracted binary missing: ${source_binary}"

  mkdir -p "$destination_dir"

  if [[ ! -w "$destination_dir" ]]; then
    fail "install directory is not writable: ${destination_dir}"
  fi

  install -m 0755 "$source_binary" "$destination_binary"
}

print_path_guidance() {
  if [[ ":$PATH:" != *":${install_dir}:"* ]]; then
    log "PATH guidance: add this to your shell profile if bb is not globally available:"
    echo "export PATH=\"${install_dir}:\$PATH\""
  fi
}

main() {
  parse_args "$@"

  require_command uname
  require_command mktemp

  local os
  local arch
  local extension
  os="$(detect_os)"
  arch="$(detect_arch)"
  extension="$(artifact_extension_for_os "$os")"

  if [[ -z "$version" ]]; then
    if [[ "$dry_run" == "true" ]]; then
      version="v0.0.0-dry-run"
      log "dry-run: latest stable version resolution skipped"
    else
      version="$(resolve_latest_stable_version)"
      log "latest stable version resolved: ${version}"
    fi
  else
    validate_requested_version "$version"
  fi

  if is_rc_version "$version"; then
    log "installing explicitly requested RC version: ${version}"
  elif ! is_stable_version "$version" && [[ "$dry_run" != "true" ]]; then
    fail "resolved version is neither stable nor valid RC: ${version}"
  fi

  local archive_name
  archive_name="brikbyteos_${version}_${os}_${arch}.${extension}"

  local base_url
  base_url="https://github.com/${repo}/releases/download/${version}"

  local tmp_dir
  tmp_dir="$(mktemp -d)"

  cleanup() {
    if [[ -n "${tmp_dir:-}" && -d "$tmp_dir" ]]; then
      rm -rf "$tmp_dir"
    fi
  }

  trap cleanup EXIT

  local archive_path="${tmp_dir}/${archive_name}"
  local checksum_path="${tmp_dir}/checksums.txt"
  local signature_bundle_path="${tmp_dir}/${archive_name}.sigstore.json"
  local extract_dir="${tmp_dir}/extract"

  log "repo: ${repo}"
  log "version: ${version}"
  log "os/arch: ${os}/${arch}"
  log "artifact: ${archive_name}"
  log "install dir: ${install_dir}"
  log "prereleases excluded by default: true"
  log "checksum verification: required"
  log "signature verification: ${verify_signature}"
  log "signature mode: ${signature_mode}"

  download_file "${base_url}/${archive_name}" "$archive_path"
  download_file "${base_url}/checksums.txt" "$checksum_path"

  if [[ "$verify_signature" == "true" && "$signature_mode" == "cosign-bundle" ]]; then
    download_file "${base_url}/${archive_name}.sigstore.json" "$signature_bundle_path"
  fi

  verify_checksum "$checksum_path" "$archive_path"
  verify_optional_signature "$archive_path" "$signature_bundle_path"
  extract_archive "$archive_path" "$extract_dir"
  install_binary "$extract_dir" "$install_dir"

  if [[ "$dry_run" == "true" ]]; then
    log "dry-run complete"
    exit 0
  fi

  log "installed ${binary_name} to ${install_dir}/${binary_name}"
  print_path_guidance

  "${install_dir}/${binary_name}" version
}

main "$@"