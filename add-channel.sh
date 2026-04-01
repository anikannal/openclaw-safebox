#!/usr/bin/env bash
# =============================================================================
# OpenClaw Safe-Box — add-channel.sh
# Day-2 helper: connect a messaging channel to your OpenClaw gateway
# =============================================================================
#
# Usage:
#   ./add-channel.sh telegram
#   ./add-channel.sh discord
#   ./add-channel.sh slack
#   ./add-channel.sh whatsapp
#
# =============================================================================
set -euo pipefail

# =============================================================================
# Formatting helpers (same palette as setup.sh)
# =============================================================================
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
RESET='\033[0m'

step()  { echo ""; echo -e "${BOLD}▸ $1${RESET}"; }
ok()    { echo -e "  ${GREEN}✓${RESET}  $1"; }
info()  { echo -e "  ${CYAN}i${RESET}  $1"; }
warn()  { echo -e "  ${YELLOW}⚠${RESET}  $1"; }
fail()  { echo ""; echo -e "${RED}${BOLD}Error:${RESET} $1"; echo ""; exit 1; }

# =============================================================================
# Resolve script directory
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# Parse arguments
# =============================================================================
CHANNEL="${1:-}"

usage() {
  echo ""
  echo -e "${BOLD}Usage:${RESET}  ./add-channel.sh <channel>"
  echo ""
  echo -e "  Supported channels:"
  echo -e "    ${BOLD}telegram${RESET}   — chat via a Telegram bot"
  echo -e "    ${BOLD}discord${RESET}    — chat in a Discord server"
  echo -e "    ${BOLD}slack${RESET}      — chat in a Slack workspace"
  echo -e "    ${BOLD}whatsapp${RESET}   — chat via WhatsApp (requires QR code scan)"
  echo ""
  echo -e "  Example:  ${DIM}./add-channel.sh telegram${RESET}"
  echo ""
}

if [[ -z "$CHANNEL" ]]; then
  usage
  exit 1
fi

case "$CHANNEL" in
  telegram|discord|slack|whatsapp) ;;
  *)
    fail "Unknown channel: '${CHANNEL}'\n\n  Supported: telegram, discord, slack, whatsapp\n  Run './add-channel.sh' with no arguments to see usage."
    ;;
esac

# =============================================================================
# Header
# =============================================================================
echo ""
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${CYAN}${BOLD}  OpenClaw Safe-Box — Add channel: ${CHANNEL}${RESET}"
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

# =============================================================================
# 1. Prerequisite checks
# =============================================================================
step "Checking prerequisites"

if ! command -v docker &>/dev/null; then
  fail "Docker is not installed. Run ./setup.sh first."
fi
ok "Docker found"

if ! docker info &>/dev/null 2>&1; then
  fail "Docker is not running. Please open Docker Desktop and try again."
fi
ok "Docker daemon is running"

if [[ ! -f "$SCRIPT_DIR/.env" ]]; then
  fail ".env file not found.\n\n  Please run ./setup.sh first to complete initial setup."
fi

# Load .env so we can pass OPENCLAW_GATEWAY_TOKEN to the CLI container
# shellcheck disable=SC1090
set -a; source "$SCRIPT_DIR/.env"; set +a
ok ".env loaded"

# =============================================================================
# 2. Confirm the gateway is running
# =============================================================================
step "Checking gateway status"

if ! docker compose --project-directory "$SCRIPT_DIR" ps --status running openclaw-gateway 2>/dev/null | grep -q "openclaw-gateway"; then
  fail "The OpenClaw gateway is not running.\n\n  Start it first:\n    docker compose up -d\n  Then try adding the channel again."
fi

# Ping the healthcheck endpoint
if ! docker compose --project-directory "$SCRIPT_DIR" exec -T openclaw-gateway \
     wget -qO- http://127.0.0.1:18789/healthz &>/dev/null; then
  fail "The gateway is running but not responding to health checks.\n\n  Check the logs:\n    docker compose logs --tail=50 openclaw-gateway"
fi

ok "Gateway is up and healthy"

# =============================================================================
# 3. Collect channel-specific credentials
# =============================================================================
step "Channel setup: ${CHANNEL}"

# ── Telegram ─────────────────────────────────────────────────────────────────
if [[ "$CHANNEL" == "telegram" ]]; then
  echo ""
  echo -e "  You need a Telegram bot token. If you haven't created one yet:"
  echo ""
  echo -e "  ${DIM}  1. Open Telegram and search for @BotFather${RESET}"
  echo -e "  ${DIM}  2. Send the message: /newbot${RESET}"
  echo -e "  ${DIM}  3. Follow the prompts to name your bot${RESET}"
  echo -e "  ${DIM}  4. BotFather will give you a token like: 123456:ABCdef...${RESET}"
  echo ""
  echo -e "  Telegram bot token:"

  TOKEN="${TELEGRAM_BOT_TOKEN:-}"
  if [[ -n "$TOKEN" ]]; then
    echo -e "  ${DIM}(found in .env — press Enter to use it, or paste a new one)${RESET}"
    read -rp "  → " INPUT
    TOKEN="${INPUT:-$TOKEN}"
  else
    read -rp "  → " TOKEN
  fi

  [[ -z "$TOKEN" ]] && fail "No token provided. Nothing was changed."

  # Basic format check: should look like 123456789:ABCdef...
  if ! echo "$TOKEN" | grep -qE '^[0-9]+:[A-Za-z0-9_-]{35,}$'; then
    warn "That token doesn't look like a standard Telegram bot token."
    warn "Proceeding anyway — OpenClaw will report an error if it's invalid."
  fi

  echo ""
  info "Connecting Telegram bot to your OpenClaw gateway..."

  docker compose --project-directory "$SCRIPT_DIR" run --rm \
    openclaw-cli \
    channels add --channel telegram --token "$TOKEN" \
    && CHANNEL_OK=true || CHANNEL_OK=false

  if [[ "$CHANNEL_OK" == "true" ]]; then
    # Persist the token to .env so re-running setup.sh doesn't lose it
    if grep -q "^TELEGRAM_BOT_TOKEN=" "$SCRIPT_DIR/.env"; then
      sed -i.bak "s|^TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=${TOKEN}|" "$SCRIPT_DIR/.env" && rm -f "$SCRIPT_DIR/.env.bak"
    else
      echo "TELEGRAM_BOT_TOKEN=${TOKEN}" >> "$SCRIPT_DIR/.env"
    fi
  fi
fi

# ── Discord ───────────────────────────────────────────────────────────────────
if [[ "$CHANNEL" == "discord" ]]; then
  echo ""
  echo -e "  You need a Discord bot token. If you haven't created one yet:"
  echo ""
  echo -e "  ${DIM}  1. Go to https://discord.com/developers/applications${RESET}"
  echo -e "  ${DIM}  2. Click 'New Application', give it a name${RESET}"
  echo -e "  ${DIM}  3. Go to 'Bot' in the left menu → 'Reset Token'${RESET}"
  echo -e "  ${DIM}  4. Enable 'Server Members Intent' and 'Message Content Intent'${RESET}"
  echo -e "  ${DIM}  5. Invite the bot to your server via OAuth2 → URL Generator${RESET}"
  echo ""
  echo -e "  Discord bot token:"

  TOKEN="${DISCORD_BOT_TOKEN:-}"
  if [[ -n "$TOKEN" ]]; then
    echo -e "  ${DIM}(found in .env — press Enter to use it, or paste a new one)${RESET}"
    read -rp "  → " INPUT
    TOKEN="${INPUT:-$TOKEN}"
  else
    read -rp "  → " TOKEN
  fi

  [[ -z "$TOKEN" ]] && fail "No token provided. Nothing was changed."

  echo ""
  info "Connecting Discord bot to your OpenClaw gateway..."

  docker compose --project-directory "$SCRIPT_DIR" run --rm \
    openclaw-cli \
    channels add --channel discord --token "$TOKEN" \
    && CHANNEL_OK=true || CHANNEL_OK=false

  if [[ "$CHANNEL_OK" == "true" ]]; then
    if grep -q "^DISCORD_BOT_TOKEN=" "$SCRIPT_DIR/.env"; then
      sed -i.bak "s|^DISCORD_BOT_TOKEN=.*|DISCORD_BOT_TOKEN=${TOKEN}|" "$SCRIPT_DIR/.env" && rm -f "$SCRIPT_DIR/.env.bak"
    else
      echo "DISCORD_BOT_TOKEN=${TOKEN}" >> "$SCRIPT_DIR/.env"
    fi
  fi
fi

# ── Slack ─────────────────────────────────────────────────────────────────────
if [[ "$CHANNEL" == "slack" ]]; then
  echo ""
  echo -e "  Slack requires two tokens: a Bot Token and an App-Level Token."
  echo ""
  echo -e "  ${DIM}  Guide: https://docs.openclaw.ai/channels/slack${RESET}"
  echo -e "  ${DIM}  Short version:${RESET}"
  echo -e "  ${DIM}    1. Create a Slack app at https://api.slack.com/apps${RESET}"
  echo -e "  ${DIM}    2. Add OAuth scopes: app_mentions:read, chat:write, im:history, im:read${RESET}"
  echo -e "  ${DIM}    3. Enable Socket Mode (generates the app-level token, starts with xapp-)${RESET}"
  echo -e "  ${DIM}    4. Install the app to your workspace (generates bot token, starts with xoxb-)${RESET}"
  echo ""

  echo -e "  Slack bot token ${DIM}(starts with xoxb-)${RESET}:"
  BOT_TOKEN="${SLACK_BOT_TOKEN:-}"
  if [[ -n "$BOT_TOKEN" ]]; then
    echo -e "  ${DIM}(found in .env — press Enter to use it, or paste a new one)${RESET}"
    read -rp "  → " INPUT
    BOT_TOKEN="${INPUT:-$BOT_TOKEN}"
  else
    read -rp "  → " BOT_TOKEN
  fi
  [[ -z "$BOT_TOKEN" ]] && fail "No bot token provided. Nothing was changed."

  echo ""
  echo -e "  Slack app-level token ${DIM}(starts with xapp-)${RESET}:"
  APP_TOKEN="${SLACK_APP_TOKEN:-}"
  if [[ -n "$APP_TOKEN" ]]; then
    echo -e "  ${DIM}(found in .env — press Enter to use it, or paste a new one)${RESET}"
    read -rp "  → " INPUT
    APP_TOKEN="${INPUT:-$APP_TOKEN}"
  else
    read -rp "  → " APP_TOKEN
  fi
  [[ -z "$APP_TOKEN" ]] && fail "No app-level token provided. Nothing was changed."

  # Basic prefix checks
  if ! echo "$BOT_TOKEN" | grep -q "^xoxb-"; then
    warn "Bot token should start with 'xoxb-'. Proceeding anyway."
  fi
  if ! echo "$APP_TOKEN" | grep -q "^xapp-"; then
    warn "App token should start with 'xapp-'. Proceeding anyway."
  fi

  echo ""
  info "Connecting Slack to your OpenClaw gateway..."

  docker compose --project-directory "$SCRIPT_DIR" run --rm \
    openclaw-cli \
    channels add --channel slack --token "$BOT_TOKEN" --app-token "$APP_TOKEN" \
    && CHANNEL_OK=true || CHANNEL_OK=false

  if [[ "$CHANNEL_OK" == "true" ]]; then
    for PAIR in "SLACK_BOT_TOKEN=${BOT_TOKEN}" "SLACK_APP_TOKEN=${APP_TOKEN}"; do
      KEY="${PAIR%%=*}"
      VAL="${PAIR#*=}"
      if grep -q "^${KEY}=" "$SCRIPT_DIR/.env"; then
        sed -i.bak "s|^${KEY}=.*|${KEY}=${VAL}|" "$SCRIPT_DIR/.env" && rm -f "$SCRIPT_DIR/.env.bak"
      else
        echo "${KEY}=${VAL}" >> "$SCRIPT_DIR/.env"
      fi
    done
  fi
fi

# ── WhatsApp ──────────────────────────────────────────────────────────────────
if [[ "$CHANNEL" == "whatsapp" ]]; then
  echo ""
  echo -e "  WhatsApp setup requires scanning a QR code with your phone."
  echo -e "  This will open an interactive session — follow the instructions on screen."
  echo ""
  echo -e "  ${DIM}  Have your phone ready and open WhatsApp → Settings → Linked Devices${RESET}"
  echo ""
  read -rp "  Press Enter when ready..."

  echo ""
  info "Starting WhatsApp pairing session..."
  echo -e "  ${DIM}(Scan the QR code with your phone when it appears)${RESET}"
  echo ""

  # WhatsApp login is interactive — no --T flag, no output piping
  docker compose --project-directory "$SCRIPT_DIR" run --rm \
    -it openclaw-cli \
    channels login \
    && CHANNEL_OK=true || CHANNEL_OK=false
fi

# =============================================================================
# 4. Result
# =============================================================================
echo ""

if [[ "${CHANNEL_OK:-false}" == "true" ]]; then
  echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${GREEN}${BOLD}  ${CHANNEL^} connected successfully!${RESET}"
  echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""

  case "$CHANNEL" in
    telegram)
      echo -e "  Send a message to your Telegram bot and it should reply."
      echo -e "  If it doesn't respond within 30 seconds, check the logs:"
      echo -e "  ${DIM}    docker compose logs --tail=50 openclaw-gateway${RESET}"
      ;;
    discord)
      echo -e "  Mention your bot in a Discord channel to start a conversation."
      echo -e "  Make sure the bot has been invited to your server with the right permissions."
      ;;
    slack)
      echo -e "  Send your bot a direct message in Slack to start a conversation."
      echo -e "  You can also invite it to a channel with /invite @yourbot"
      ;;
    whatsapp)
      echo -e "  WhatsApp is linked. Send a message to yourself or to the bot number."
      echo -e "  Note: WhatsApp may disconnect after a period of inactivity."
      echo -e "  Re-run ${BOLD}./add-channel.sh whatsapp${RESET} to re-pair if needed."
      ;;
  esac

  echo ""
  echo -e "  ${DIM}Add another channel anytime: ./add-channel.sh <telegram|discord|slack|whatsapp>${RESET}"
  echo ""
else
  echo -e "${RED}${BOLD}  Channel setup failed.${RESET}"
  echo ""
  echo -e "  The openclaw-cli container reported an error. Common causes:"
  echo -e "    • Invalid token (check you copied the full token with no spaces)"
  echo -e "    • Token doesn't have the required permissions (see notes above)"
  echo -e "    • Gateway token mismatch (try running ./setup.sh again)"
  echo ""
  echo -e "  Full logs:"
  echo -e "  ${DIM}    docker compose logs --tail=100 openclaw-gateway${RESET}"
  echo ""
  exit 1
fi
