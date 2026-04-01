#!/usr/bin/env bash
# =============================================================================
# OpenClaw Safe-Box — setup.sh
# First-run setup for Mac and Linux
# =============================================================================
set -euo pipefail

# =============================================================================
# Formatting helpers
# =============================================================================
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
RESET='\033[0m'

print_header() {
  echo ""
  echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${CYAN}${BOLD}  OpenClaw Safe-Box — Setup${RESET}"
  echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""
}

step() {
  echo ""
  echo -e "${BOLD}▸ $1${RESET}"
}

ok() {
  echo -e "  ${GREEN}✓${RESET}  $1"
}

warn() {
  echo -e "  ${YELLOW}⚠${RESET}  $1"
}

fail() {
  echo ""
  echo -e "${RED}${BOLD}Error:${RESET} $1"
  echo ""
  exit 1
}

prompt() {
  # prompt <variable_name> <message> [optional: default_value]
  local var_name="$1"
  local message="$2"
  local default="${3:-}"
  local value=""

  if [[ -n "$default" ]]; then
    echo -e "  ${DIM}(press Enter to keep: ${default})${RESET}"
    read -rp "  → " value
    value="${value:-$default}"
  else
    read -rp "  → " value
  fi

  # Assign to the named variable
  printf -v "$var_name" '%s' "$value"
}

prompt_secret() {
  # Like prompt but hides input
  local var_name="$1"
  local value=""
  read -rsp "  → " value
  echo ""
  printf -v "$var_name" '%s' "$value"
}

# =============================================================================
# Script directory — resolve to where this script lives (not cwd)
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# 1. Welcome
# =============================================================================
print_header
echo -e "  This script will set up OpenClaw Safe-Box on your machine."
echo -e "  It takes about 3–5 minutes depending on your internet speed."
echo ""
echo -e "  ${DIM}You'll need:${RESET}"
echo -e "    • Docker Desktop running"
echo -e "    • An Anthropic or OpenAI API key"
echo -e "    • A Telegram bot token (or another supported channel)"
echo ""

# =============================================================================
# 2. Check prerequisites
# =============================================================================
step "Checking prerequisites"

# Docker CLI
if ! command -v docker &>/dev/null; then
  fail "Docker is not installed.\n\n  Please install Docker Desktop from https://www.docker.com/products/docker-desktop\n  then re-run this script."
fi
ok "Docker CLI found"

# Docker daemon
if ! docker info &>/dev/null 2>&1; then
  fail "Docker is not running.\n\n  Please open Docker Desktop and wait for it to finish starting,\n  then re-run this script."
fi
ok "Docker daemon is running"

# Docker Compose v2
if ! docker compose version &>/dev/null 2>&1; then
  fail "Docker Compose v2 is not available.\n\n  If you're on an older Docker version, please update Docker Desktop.\n  Docker Compose v2 is included in Docker Desktop 3.6+."
fi
COMPOSE_VERSION=$(docker compose version --short 2>/dev/null || echo "unknown")
ok "Docker Compose v2 found (${COMPOSE_VERSION})"

# Minimum RAM check (warn, don't fail)
if command -v free &>/dev/null; then
  TOTAL_RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
  if [[ "$TOTAL_RAM_MB" -lt 2048 ]]; then
    warn "Your machine has less than 2 GB of RAM. OpenClaw may run slowly."
  fi
fi

# =============================================================================
# 3. Detect if this is a re-run (idempotency)
# =============================================================================
EXISTING_ENV=false
if [[ -f "$SCRIPT_DIR/.env" ]]; then
  EXISTING_ENV=true
  # shellcheck disable=SC1090
  source "$SCRIPT_DIR/.env" 2>/dev/null || true
  echo ""
  warn "A .env file already exists from a previous setup."
  echo -e "  ${DIM}Existing values will be used as defaults. Press Enter to keep them.${RESET}"
fi

# =============================================================================
# 4. Collect configuration
# =============================================================================
step "Configuration"
echo ""

# ── AI provider ──────────────────────────────────────────────────────────────
echo -e "  ${BOLD}AI provider${RESET}"
echo -e "  ${DIM}You need an API key for at least one AI provider.${RESET}"
echo ""
echo -e "  Anthropic API key ${DIM}(get one at console.anthropic.com — recommended)${RESET}"
echo -e "  ${DIM}Leave blank to skip if you're using OpenAI instead.${RESET}"
NEW_ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"
prompt NEW_ANTHROPIC_API_KEY "" "${ANTHROPIC_API_KEY:-}"

echo ""
echo -e "  OpenAI API key ${DIM}(get one at platform.openai.com)${RESET}"
echo -e "  ${DIM}Leave blank to skip if you're using Anthropic instead.${RESET}"
NEW_OPENAI_API_KEY="${OPENAI_API_KEY:-}"
prompt NEW_OPENAI_API_KEY "" "${OPENAI_API_KEY:-}"

if [[ -z "$NEW_ANTHROPIC_API_KEY" && -z "$NEW_OPENAI_API_KEY" ]]; then
  fail "You must provide at least one AI provider API key (Anthropic or OpenAI)."
fi

# ── Messaging channel ─────────────────────────────────────────────────────────
echo ""
echo -e "  ${BOLD}Messaging channel${RESET}"
echo -e "  ${DIM}Add a channel now so you can talk to OpenClaw. You can add more later.${RESET}"
echo ""
echo -e "  Telegram bot token ${DIM}(create a bot via @BotFather on Telegram)${RESET}"
echo -e "  ${DIM}Leave blank to skip — you can add it later via ./add-channel.sh${RESET}"
NEW_TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
prompt NEW_TELEGRAM_BOT_TOKEN "" "${TELEGRAM_BOT_TOKEN:-}"

# ── Workspace path ────────────────────────────────────────────────────────────
echo ""
echo -e "  ${BOLD}Workspace folder${RESET}"
echo -e "  ${DIM}This is the ONLY folder on your laptop that OpenClaw can access.${RESET}"
echo -e "  ${DIM}The agent can create and read files here. Everything else is blocked.${RESET}"
echo ""
echo -e "  Workspace path:"
DEFAULT_WORKSPACE="$HOME/openclaw-workspace"
NEW_OPENCLAW_WORKSPACE="${OPENCLAW_WORKSPACE:-$DEFAULT_WORKSPACE}"
prompt NEW_OPENCLAW_WORKSPACE "" "${NEW_OPENCLAW_WORKSPACE}"
# Expand ~ if present
NEW_OPENCLAW_WORKSPACE="${NEW_OPENCLAW_WORKSPACE/#\~/$HOME}"

# ── Timezone ──────────────────────────────────────────────────────────────────
# Auto-detect from system, let user override
DETECTED_TZ=$(cat /etc/timezone 2>/dev/null || \
              readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||' || \
              echo "UTC")
NEW_TZ="${TZ:-$DETECTED_TZ}"

# =============================================================================
# 5. Generate gateway token (if not already set)
# =============================================================================
step "Generating gateway token"

if [[ -n "${OPENCLAW_GATEWAY_TOKEN:-}" ]]; then
  ok "Keeping existing gateway token"
  NEW_GATEWAY_TOKEN="$OPENCLAW_GATEWAY_TOKEN"
else
  # Generate a cryptographically random 48-character hex token
  if command -v openssl &>/dev/null; then
    NEW_GATEWAY_TOKEN=$(openssl rand -hex 24)
  else
    # Fallback: /dev/urandom
    NEW_GATEWAY_TOKEN=$(head -c 24 /dev/urandom | xxd -p | tr -d '\n')
  fi
  ok "Generated new gateway token"
fi

# =============================================================================
# 6. Write .env
# =============================================================================
step "Writing configuration to .env"

cat > "$SCRIPT_DIR/.env" << EOF
# OpenClaw Safe-Box — configuration
# Generated by setup.sh on $(date -u '+%Y-%m-%d %H:%M UTC')
# Do not commit this file to version control.

# Gateway authentication token (auto-generated — do not share)
OPENCLAW_GATEWAY_TOKEN=${NEW_GATEWAY_TOKEN}

# AI provider(s)
ANTHROPIC_API_KEY=${NEW_ANTHROPIC_API_KEY}
OPENAI_API_KEY=${NEW_OPENAI_API_KEY}

# Messaging channels
TELEGRAM_BOT_TOKEN=${NEW_TELEGRAM_BOT_TOKEN}
DISCORD_BOT_TOKEN=${DISCORD_BOT_TOKEN:-}
SLACK_BOT_TOKEN=${SLACK_BOT_TOKEN:-}
SLACK_APP_TOKEN=${SLACK_APP_TOKEN:-}

# Docker image
OPENCLAW_IMAGE=${OPENCLAW_IMAGE:-ghcr.io/openclaw/openclaw:latest}

# Workspace folder (the only host directory OpenClaw can access)
OPENCLAW_WORKSPACE=${NEW_OPENCLAW_WORKSPACE}

# Timezone
TZ=${NEW_TZ}
EOF

# Restrict .env to owner-read only — no group/other access
chmod 600 "$SCRIPT_DIR/.env"
ok ".env written (permissions restricted to owner-only)"

# =============================================================================
# 7. Create workspace directory
# =============================================================================
step "Setting up workspace folder"

if [[ -d "$NEW_OPENCLAW_WORKSPACE" ]]; then
  ok "Workspace already exists: ${NEW_OPENCLAW_WORKSPACE}"
else
  mkdir -p "$NEW_OPENCLAW_WORKSPACE"
  ok "Created workspace: ${NEW_OPENCLAW_WORKSPACE}"
fi

# Write a README inside the workspace so users understand it
if [[ ! -f "$NEW_OPENCLAW_WORKSPACE/README.txt" ]]; then
  cat > "$NEW_OPENCLAW_WORKSPACE/README.txt" << 'EOF'
This folder is your OpenClaw Safe-Box workspace.

OpenClaw can read and write files here. This is the ONLY folder on your
computer that OpenClaw has access to. Everything else (your Documents,
Downloads, Desktop, etc.) is blocked by the container.

You can:
  • Put files here for OpenClaw to read and process
  • Ask OpenClaw to create documents and they'll appear here
  • Organise it into subfolders however you like

Deleting this folder (or running 'docker compose down -v') removes all
OpenClaw data from your machine.
EOF
fi

# =============================================================================
# 8. Pull Docker image
# =============================================================================
step "Pulling OpenClaw Docker image"
echo -e "  ${DIM}This may take a minute on first run (image is ~400 MB)...${RESET}"
echo ""

IMAGE="${OPENCLAW_IMAGE:-ghcr.io/openclaw/openclaw:latest}"
if docker compose --project-directory "$SCRIPT_DIR" pull openclaw-gateway 2>&1 | \
   sed 's/^/    /'; then
  ok "Image pulled: ${IMAGE}"
else
  fail "Failed to pull the Docker image.\n\n  Check your internet connection and try again.\n  If the problem persists, try manually running:\n    docker pull ${IMAGE}"
fi

# =============================================================================
# 9. Start the gateway
# =============================================================================
step "Starting OpenClaw Safe-Box"

# If already running, restart so new config takes effect
if docker compose --project-directory "$SCRIPT_DIR" ps --status running openclaw-gateway 2>/dev/null | grep -q "openclaw-gateway"; then
  warn "OpenClaw is already running — restarting with new configuration"
  docker compose --project-directory "$SCRIPT_DIR" restart openclaw-gateway 2>&1 | sed 's/^/    /'
else
  docker compose --project-directory "$SCRIPT_DIR" up -d openclaw-gateway 2>&1 | sed 's/^/    /'
fi

# =============================================================================
# 10. Wait for the gateway to be healthy
# =============================================================================
step "Waiting for gateway to start"
echo -e "  ${DIM}(usually takes 15–30 seconds)${RESET}"

ATTEMPTS=0
MAX_ATTEMPTS=30
until docker compose --project-directory "$SCRIPT_DIR" exec -T openclaw-gateway \
      wget -qO- http://127.0.0.1:18789/healthz &>/dev/null; do
  ATTEMPTS=$((ATTEMPTS + 1))
  if [[ "$ATTEMPTS" -ge "$MAX_ATTEMPTS" ]]; then
    echo ""
    fail "The gateway didn't start within 90 seconds.\n\n  Check the logs for errors:\n    docker compose logs openclaw-gateway\n\n  Then try restarting:\n    docker compose up -d"
  fi
  printf "."
  sleep 3
done
echo ""
ok "Gateway is up and healthy"

# =============================================================================
# 11. Open browser and show token
# =============================================================================
step "Opening Control UI"

CONTROL_UI_URL="http://localhost:18789"

# Try to open the browser automatically
if command -v open &>/dev/null; then       # macOS
  open "$CONTROL_UI_URL"
elif command -v xdg-open &>/dev/null; then # Linux
  xdg-open "$CONTROL_UI_URL" &>/dev/null &
fi

ok "Control UI: ${CONTROL_UI_URL}"

# =============================================================================
# 12. Done — show token and next steps
# =============================================================================
echo ""
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}${BOLD}  Setup complete!${RESET}"
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "  ${BOLD}Your gateway token:${RESET}"
echo ""
echo -e "  ${YELLOW}${BOLD}  ${NEW_GATEWAY_TOKEN}  ${RESET}"
echo ""
echo -e "  ${DIM}↑ Copy this and paste it into the Control UI when prompted.${RESET}"
echo -e "  ${DIM}  It's also saved in .env if you need it again.${RESET}"
echo ""
echo -e "  ${BOLD}Next steps:${RESET}"
if [[ -n "$NEW_TELEGRAM_BOT_TOKEN" ]]; then
  echo -e "    1. Paste the token above into the Control UI at ${CONTROL_UI_URL}"
  echo -e "    2. Message your Telegram bot — it should reply!"
else
  echo -e "    1. Paste the token above into the Control UI at ${CONTROL_UI_URL}"
  echo -e "    2. Add a messaging channel: ${BOLD}./add-channel.sh telegram${RESET}"
  echo -e "    3. Message your bot and say hello!"
fi
echo ""
echo -e "  ${BOLD}Useful commands:${RESET}"
echo -e "  ${DIM}  Stop OpenClaw:     docker compose stop${RESET}"
echo -e "  ${DIM}  Start OpenClaw:    docker compose up -d${RESET}"
echo -e "  ${DIM}  View logs:         docker compose logs -f openclaw-gateway${RESET}"
echo -e "  ${DIM}  Add a channel:     ./add-channel.sh <telegram|discord|slack>${RESET}"
echo -e "  ${DIM}  Full reset:        docker compose down -v${RESET}"
echo ""
echo -e "  ${BOLD}Your workspace:${RESET} ${NEW_OPENCLAW_WORKSPACE}"
echo -e "  ${DIM}  This is the only folder OpenClaw can access on your machine.${RESET}"
echo ""
