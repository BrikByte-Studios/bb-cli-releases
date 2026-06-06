#!/usr/bin/env bash

# verify-distribution-repo.sh validates the public BrikByteOS bb distribution
# repository.
#
# Purpose:
#   Ensure this repository remains a public distribution surface and does not
#   accidentally become a second source/build repository.
#
# This script verifies:
#   - install.sh exists
#   - install.ps1 exists
#   - README.md documents distribution-only responsibility
#   - installers default to the public bb-cli-releases repository
#   - no Go source/build configuration is present
#   - no private key-like files are present
#
# This script does not:
#   - install bb
#   - publish releases
#   - download release artifacts

set -euo pipefail

fail() {
  echo "distribution repo verification failed: $*" >&2
  exit 1
}

require_file() {
  local file="$1"
  [[ -f "$file" ]] || fail "required file missing: ${file}"
}

require_text() {
  local file="$1"
  local text="$2"

  if ! grep -Fq -- "$text" "$file"; then
    fail "expected '${text}' in ${file}"
  fi
}

reject_path() {
  local path="$1"

  if [[ -e "$path" ]]; then
    fail "unexpected build/source path exists: ${path}"
  fi
}

require_file "README.md"
require_file "install.sh"
require_file "install.ps1"

bash -n install.sh

require_text "README.md" "public distribution surface"
require_text "README.md" "It does not build them."
require_text "install.sh" 'readonly default_repo="BrikByte-Studios/bb-cli-releases"'
# shellcheck disable=SC2016
require_text "install.ps1" '[string]$Repo = "BrikByte-Studios/bb-cli-releases"'

reject_path "go.mod"
reject_path "go.sum"
reject_path "cmd"
reject_path "internal"
reject_path ".goreleaser.yaml"

if find . \
  -path "./.git" -prune -o \
  -type f \( -name "*.pem" -o -name "*.key" -o -name "*.p12" -o -name "*.pfx" -o -name "cosign.key" \) -print \
  | grep -q .; then
  fail "private key-like file found"
fi

echo "distribution repo verification passed"