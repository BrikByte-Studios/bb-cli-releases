# Makefile for the public BrikByteOS bb distribution repository.
#
# This repository distributes installer scripts and public release assets.
# It must not build the private bb source code.

.PHONY: help verify verify-distribution shellcheck dry-run

help:
	@echo "BrikByteOS public distribution commands"
	@echo ""
	@echo "  make verify              Verify public distribution repo contract"
	@echo "  make dry-run             Run installer dry-run"
	@echo "  make shellcheck          Run shellcheck if available"

verify: verify-distribution shellcheck dry-run
	@echo "public distribution verification passed"

verify-distribution:
	./scripts/verify-distribution-repo.sh

shellcheck:
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck install.sh scripts/verify-distribution-repo.sh; \
	else \
		echo "shellcheck not installed; skipping."; \
	fi

dry-run:
	./install.sh --version v0.1.0 --dry-run