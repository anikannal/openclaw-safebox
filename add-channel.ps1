#Requires -Version 5.1
# =============================================================================
# OpenClaw Safe-Box — add-channel.ps1
# Day-2 helper: connect a messaging channel to your OpenClaw gateway (Windows)
# =============================================================================
#
# Usage:
#   .\add-channel.ps1 telegram
#   .\add-channel.ps1 discord
#   .\add-channel.ps1 slack
#   .\add-channel.ps1 whatsapp
#
# =============================================================================
[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [string]$Channel = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# =============================================================================
# Formatting helpers
# =============================================================================
function Write-Step { param($msg) Write-Host "`n▸ $msg" -ForegroundColor White }
function Write-Ok   { param($msg) Write-Host "  ✓  $msg" -ForegroundColor Green }
function Write-Info { param($msg) Write-Host "  i  $msg" -ForegroundColor Cyan }
function Write-Warn { param($msg) Write-Host "  ⚠  $msg" -ForegroundColor Yellow }
function Write-Dim  { param($msg) Write-Host "  $msg" -ForegroundColor DarkGray }
function Write-Fail {
  param($msg)
  Write-Host "`nError: $msg`n" -ForegroundColor Red
  exit 1
}

function Read-Value {
  param([string]$Default = "")
  if ($Default) { Write-Dim "(press Enter to keep existing value)" }
  Write-Host -NoNewline "  → "
  $v = Read-Host
  if ([string]::IsNullOrWhiteSpace($v)) { $v = $Default }
  return $v
}

# Helper: update or append a key in .env
function Set-EnvValue {
  param([string]$Key, [string]$Value, [string]$EnvFile)
  $lines = Get-Content $EnvFile
  $found = $false
  $lines = $lines | ForEach-Object {
    if ($_ -match "^$Key=") { $found = $true; "$Key=$Value" } else { $_ }
  }
  if (-not $found) { $lines += "$Key=$Value" }
  Set-Content -Path $EnvFile -Value $lines -Encoding UTF8
}

# =============================================================================
# Resolve script directory and .env
# =============================================================================
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnvFile   = Join-Path $ScriptDir ".env"

# =============================================================================
# Validate channel argument
# =============================================================================
$SupportedChannels = @("telegram", "discord", "slack", "whatsapp")

if ([string]::IsNullOrWhiteSpace($Channel)) {
  Write-Host ""
  Write-Host "Usage:  .\add-channel.ps1 <channel>" -ForegroundColor White
  Write-Host ""
  Write-Host "  Supported channels:"
  Write-Host "    telegram   — chat via a Telegram bot" -ForegroundColor White
  Write-Host "    discord    — chat in a Discord server" -ForegroundColor White
  Write-Host "    slack      — chat in a Slack workspace" -ForegroundColor White
  Write-Host "    whatsapp   — chat via WhatsApp (requires QR code scan)" -ForegroundColor White
  Write-Host ""
  exit 1
}

$Channel = $Channel.ToLower()
if ($Channel -notin $SupportedChannels) {
  Write-Fail "Unknown channel: '$Channel'`n`n  Supported: telegram, discord, slack, whatsapp"
}

# =============================================================================
# Header
# =============================================================================
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  OpenClaw Safe-Box — Add channel: $Channel" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

# =============================================================================
# 1. Prerequisite checks
# =============================================================================
Write-Step "Checking prerequisites"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  Write-Fail "Docker is not installed. Run .\setup.ps1 first."
}
Write-Ok "Docker found"

$dockerInfo = docker info 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Fail "Docker is not running. Please open Docker Desktop and try again."
}
Write-Ok "Docker daemon is running"

if (-not (Test-Path $EnvFile)) {
  Write-Fail ".env file not found.`n`n  Please run .\setup.ps1 first to complete initial setup."
}

# Parse .env
$EnvValues = @{}
Get-Content $EnvFile | Where-Object { $_ -match '^\s*([^#][^=]+)=(.*)' } | ForEach-Object {
  $key, $val = $_ -split '=', 2
  $EnvValues[$key.Trim()] = $val.Trim()
}
Write-Ok ".env loaded"

function Existing { param($key) if ($EnvValues.ContainsKey($key)) { $EnvValues[$key] } else { "" } }

# =============================================================================
# 2. Confirm gateway is running and healthy
# =============================================================================
Write-Step "Checking gateway status"

Push-Location $ScriptDir
try {
  $ps = docker compose ps --status running openclaw-gateway 2>&1
  if ($ps -notmatch "openclaw-gateway") {
    Write-Fail ("The OpenClaw gateway is not running.`n`n" +
      "  Start it first:`n    docker compose up -d`n" +
      "  Then try adding the channel again.")
  }

  $health = docker compose exec -T openclaw-gateway wget -qO- http://127.0.0.1:18789/healthz 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-Fail ("The gateway is running but not responding to health checks.`n`n" +
      "  Check the logs:`n    docker compose logs --tail=50 openclaw-gateway")
  }
} finally {
  Pop-Location
}

Write-Ok "Gateway is up and healthy"

# =============================================================================
# 3. Collect credentials and connect
# =============================================================================
Write-Step "Channel setup: $Channel"
$ChannelOk = $false

# ── Telegram ─────────────────────────────────────────────────────────────────
if ($Channel -eq "telegram") {
  Write-Host ""
  Write-Host "  You need a Telegram bot token. If you haven't created one yet:" -ForegroundColor White
  Write-Host ""
  Write-Dim "  1. Open Telegram and search for @BotFather"
  Write-Dim "  2. Send the message: /newbot"
  Write-Dim "  3. Follow the prompts to name your bot"
  Write-Dim "  4. BotFather will give you a token like: 123456:ABCdef..."
  Write-Host ""
  Write-Host "  Telegram bot token:"
  $token = Read-Value -Default (Existing "TELEGRAM_BOT_TOKEN")
  if ([string]::IsNullOrWhiteSpace($token)) { Write-Fail "No token provided. Nothing was changed." }

  if ($token -notmatch '^\d+:[A-Za-z0-9_\-]{35,}$') {
    Write-Warn "That token doesn't look like a standard Telegram bot token."
    Write-Warn "Proceeding anyway — OpenClaw will report an error if it's invalid."
  }

  Write-Host ""
  Write-Info "Connecting Telegram bot to your OpenClaw gateway..."

  Push-Location $ScriptDir
  try {
    docker compose run --rm openclaw-cli channels add --channel telegram --token $token
    if ($LASTEXITCODE -eq 0) {
      $ChannelOk = $true
      Set-EnvValue -Key "TELEGRAM_BOT_TOKEN" -Value $token -EnvFile $EnvFile
    }
  } finally { Pop-Location }
}

# ── Discord ───────────────────────────────────────────────────────────────────
if ($Channel -eq "discord") {
  Write-Host ""
  Write-Host "  You need a Discord bot token. If you haven't created one yet:" -ForegroundColor White
  Write-Host ""
  Write-Dim "  1. Go to https://discord.com/developers/applications"
  Write-Dim "  2. Click 'New Application', give it a name"
  Write-Dim "  3. Go to 'Bot' in the left menu -> 'Reset Token'"
  Write-Dim "  4. Enable 'Server Members Intent' and 'Message Content Intent'"
  Write-Dim "  5. Invite the bot to your server via OAuth2 -> URL Generator"
  Write-Host ""
  Write-Host "  Discord bot token:"
  $token = Read-Value -Default (Existing "DISCORD_BOT_TOKEN")
  if ([string]::IsNullOrWhiteSpace($token)) { Write-Fail "No token provided. Nothing was changed." }

  Write-Host ""
  Write-Info "Connecting Discord bot to your OpenClaw gateway..."

  Push-Location $ScriptDir
  try {
    docker compose run --rm openclaw-cli channels add --channel discord --token $token
    if ($LASTEXITCODE -eq 0) {
      $ChannelOk = $true
      Set-EnvValue -Key "DISCORD_BOT_TOKEN" -Value $token -EnvFile $EnvFile
    }
  } finally { Pop-Location }
}

# ── Slack ─────────────────────────────────────────────────────────────────────
if ($Channel -eq "slack") {
  Write-Host ""
  Write-Host "  Slack requires two tokens: a Bot Token and an App-Level Token." -ForegroundColor White
  Write-Host ""
  Write-Dim "  Guide: https://docs.openclaw.ai/channels/slack"
  Write-Dim "  Short version:"
  Write-Dim "    1. Create a Slack app at https://api.slack.com/apps"
  Write-Dim "    2. Add OAuth scopes: app_mentions:read, chat:write, im:history, im:read"
  Write-Dim "    3. Enable Socket Mode (generates the app-level token, starts with xapp-)"
  Write-Dim "    4. Install the app to your workspace (generates bot token, starts with xoxb-)"
  Write-Host ""

  Write-Host "  Slack bot token (starts with xoxb-):"
  $botToken = Read-Value -Default (Existing "SLACK_BOT_TOKEN")
  if ([string]::IsNullOrWhiteSpace($botToken)) { Write-Fail "No bot token provided. Nothing was changed." }

  Write-Host ""
  Write-Host "  Slack app-level token (starts with xapp-):"
  $appToken = Read-Value -Default (Existing "SLACK_APP_TOKEN")
  if ([string]::IsNullOrWhiteSpace($appToken)) { Write-Fail "No app-level token provided. Nothing was changed." }

  if ($botToken -notmatch '^xoxb-') { Write-Warn "Bot token should start with 'xoxb-'. Proceeding anyway." }
  if ($appToken -notmatch '^xapp-') { Write-Warn "App token should start with 'xapp-'. Proceeding anyway." }

  Write-Host ""
  Write-Info "Connecting Slack to your OpenClaw gateway..."

  Push-Location $ScriptDir
  try {
    docker compose run --rm openclaw-cli channels add --channel slack --token $botToken --app-token $appToken
    if ($LASTEXITCODE -eq 0) {
      $ChannelOk = $true
      Set-EnvValue -Key "SLACK_BOT_TOKEN" -Value $botToken -EnvFile $EnvFile
      Set-EnvValue -Key "SLACK_APP_TOKEN" -Value $appToken -EnvFile $EnvFile
    }
  } finally { Pop-Location }
}

# ── WhatsApp ──────────────────────────────────────────────────────────────────
if ($Channel -eq "whatsapp") {
  Write-Host ""
  Write-Host "  WhatsApp setup requires scanning a QR code with your phone." -ForegroundColor White
  Write-Host "  This will open an interactive session — follow the on-screen instructions."
  Write-Host ""
  Write-Dim "  Have your phone ready and open WhatsApp -> Settings -> Linked Devices"
  Write-Host ""
  Read-Host "  Press Enter when ready"

  Write-Host ""
  Write-Info "Starting WhatsApp pairing session..."
  Write-Dim "(Scan the QR code with your phone when it appears)"
  Write-Host ""

  Push-Location $ScriptDir
  try {
    # -it equivalent on Windows: don't use -T, let PowerShell inherit the console
    docker compose run --rm openclaw-cli channels login
    if ($LASTEXITCODE -eq 0) { $ChannelOk = $true }
  } finally { Pop-Location }
}

# =============================================================================
# 4. Result
# =============================================================================
Write-Host ""

if ($ChannelOk) {
  $channelTitle = (Get-Culture).TextInfo.ToTitleCase($Channel)
  Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
  Write-Host "  $channelTitle connected successfully!" -ForegroundColor Green
  Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
  Write-Host ""

  switch ($Channel) {
    "telegram" {
      Write-Host "  Send a message to your Telegram bot and it should reply."
      Write-Dim "  If it doesn't respond within 30 seconds, check the logs:"
      Write-Dim "    docker compose logs --tail=50 openclaw-gateway"
    }
    "discord" {
      Write-Host "  Mention your bot in a Discord channel to start a conversation."
      Write-Dim "  Make sure the bot has been invited to your server with the right permissions."
    }
    "slack" {
      Write-Host "  Send your bot a direct message in Slack to start a conversation."
      Write-Dim "  You can also invite it to a channel with /invite @yourbot"
    }
    "whatsapp" {
      Write-Host "  WhatsApp is linked. Send a message to yourself or to the bot number."
      Write-Warn "WhatsApp may disconnect after a period of inactivity."
      Write-Dim "  Re-run .\add-channel.ps1 whatsapp to re-pair if needed."
    }
  }

  Write-Host ""
  Write-Dim "Add another channel anytime: .\add-channel.ps1 <telegram|discord|slack|whatsapp>"
  Write-Host ""
} else {
  Write-Host "  Channel setup failed." -ForegroundColor Red
  Write-Host ""
  Write-Host "  The openclaw-cli container reported an error. Common causes:"
  Write-Dim "    - Invalid token (check you copied the full token with no spaces)"
  Write-Dim "    - Token doesn't have the required permissions (see notes above)"
  Write-Dim "    - Gateway token mismatch (try running .\setup.ps1 again)"
  Write-Host ""
  Write-Host "  Full logs:"
  Write-Dim "    docker compose logs --tail=100 openclaw-gateway"
  Write-Host ""
  exit 1
}
