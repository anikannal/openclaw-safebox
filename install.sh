#!/usr/bin/env bash
# =============================================================================
# OpenClaw Safe-Box — install.sh
# One-line installer for Mac and Linux
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/anikannal/openclaw-safebox/main/install.sh | bash
#
# What this does:
#   1. Checks that Docker is installed and running
#   2. Downloads the Safe-Box files to ~/openclaw-safebox
#      (uses git clone if available, zip download otherwise)
#   3. Hands off to setup.sh for the guided first-run configuration
# =============================================================================
set -euo pipefail

# =============================================================================
# Config — update anikannal before publishing
# =============================================================================
REPO_URL="https://github.com/anikannal/openclaw-safebox.git"
ZIP_URL="https://github.com/anikannal/openclaw-safebox/archive/refs/heads/main.zip"
INSTALL_DIR="${OPENCLAW_INSTALL_DIR:-$HOME/openclaw-safebox}"

# =============================================================================
# Formatting
# =============================================================================
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
RESET='\033[0m'

step() { echo ""; echo -e "${BOLD}▸ $1${RESET}"; }
ok()   { echo -e "  ${GREEN}✓${RESET}  $1"; }
warn() { echo -e "  ${YELLOW}⚠${RESET}  $1"; }
fail() { echo ""; echo -e "${RED}${BOLD}Error:${RESET} $1"; echo ""; exit 1; }

# =============================================================================
# Welcome
# =============================================================================
echo ""
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${CYAN}${BOLD}  OpenClaw Safe-Box — Installer${RESET}"
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "  Installing to: ${BOLD}${INSTALL_DIR}${RESET}"
echo -e "  ${DIM}Set OPENCLAW_INSTALL_DIR to change this.${RESET}"

# =============================================================================
# 1. Check Docker
# =============================================================================
step "Checking Docker"

if ! command -v docker &>/dev/null; then
  fail "Docker is not installed.\n\n  Please install Docker Desktop from https://www.docker.com/products/docker-desktop\n  then re-run this installer."
fi
ok "Docker CLI found"

if ! docker info &>/dev/null 2>&1; then
  fail "Docker is not running.\n\n  Please open Docker Desktop and wait for it to finish starting,\n  then re-run this installer."
fi
ok "Docker daemon is running"

if ! docker compose version &>/dev/null 2>&1; then
  fail "Docker Compose v2 is not available. Please update Docker Desktop."
fi
ok "Docker Compose v2 found"

# =============================================================================
# 2. Download Safe-Box files
# =============================================================================
step "Downloading OpenClaw Safe-Box"

if [[ -d "$INSTALL_DIR/.git" ]]; then
  # Already a git repo — pull latest
  echo -e "  ${DIM}Existing installation found — updating to latest version...${RESET}"
  git -C "$INSTALL_DIR" pull --ff-only \
    && ok "Updated to latest version" \
    || warn "Could not auto-update (local changes present). Continuing with existing files."

elif command -v git &>/dev/null; then
  # Fresh clone
  echo -e "  ${DIM}Cloning repository...${RESET}"
  git clone --depth 1 "$REPO_URL" "$INSTALL_DIR" \
    && ok "Downloaded via git" \
    || fail "git clone failed. Check your internet connection and try again."

else
  # No git — fall back to zip download
  warn "git not found — downloading zip instead"

  if [[ -d "$INSTALL_DIR" ]]; then
    warn "Directory already exists at ${INSTALL_DIR}. Skipping download — using existing files."
  else
    # Need curl or wget
    TMP_ZIP="$(mktemp /tmp/openclaw-safebox-XXXXXX.zip)"

    if command -v curl &>/dev/null; then
      echo -e "  ${DIM}Downloading via curl...${RESET}"
      curl -fsSL "$ZIP_URL" -o "$TMP_ZIP" \
        || fail "Download failed. Check your internet connection and try again."
    elif command -v wget &>/dev/null; then
      echo -e "  ${DIM}Downloading via wget...${RESET}"
      wget -q "$ZIP_URL" -O "$TMP_ZIP" \
        || fail "Download failed. Check your internet connection and try again."
    else
      fail "Neither git, curl, nor wget is available.\n\n  Please install one of them, or download the zip manually from:\n  https://github.com/anikannal/openclaw-safebox"
    fi

    # Unzip — the archive extracts to openclaw-safebox-main/
    TMP_DIR="$(mktemp -d /tmp/openclaw-safebox-XXXXXX)"
    unzip -q "$TMP_ZIP" -d "$TMP_DIR" \
      || fail "Could not unzip the downloaded file."
    rm -f "$TMP_ZIP"

    mv "$TMP_DIR"/openclaw-safebox-main "$INSTALL_DIR" \
      || fail "Could not move files to ${INSTALL_DIR}."
    rm -rf "$TMP_DIR"
    ok "Downloaded and extracted"
  fi
fi

# Ensure setup scripts are executable (preserved by git, but safe to re-set)
chmod +x "$INSTALL_DIR/setup.sh" "$INSTALL_DIR/add-channel.sh" 2>/dev/null || true

# =============================================================================
# 3. Hand off to setup.sh
# =============================================================================
step "Starting setup"
echo ""
echo -e "  Files are ready at: ${BOLD}${INSTALL_DIR}${RESET}"
echo -e "  ${DIM}Launching setup.sh...${RESET}"
echo ""

exec "$INSTALL_DIR/setup.sh"
