#Requires -Version 5.1
# =============================================================================
# OpenClaw Safe-Box — setup.ps1
# First-run setup for Windows (PowerShell 5.1+ / PowerShell 7+)
# =============================================================================
#
# Run this from PowerShell (not Command Prompt):
#   .\setup.ps1
#
# If you see "cannot be loaded because running scripts is disabled", run:
#   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
# Then try again.
# =============================================================================
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# =============================================================================
# Formatting helpers
# =============================================================================
function Write-Step   { param($msg) Write-Host "`n▸ $msg" -ForegroundColor White }
function Write-Ok     { param($msg) Write-Host "  ✓  $msg" -ForegroundColor Green }
function Write-Info   { param($msg) Write-Host "  i  $msg" -ForegroundColor Cyan }
function Write-Warn   { param($msg) Write-Host "  ⚠  $msg" -ForegroundColor Yellow }
function Write-Fail   {
  param($msg)
  Write-Host "`nError: $msg`n" -ForegroundColor Red
  exit 1
}
function Write-Dim    { param($msg) Write-Host "  $msg" -ForegroundColor DarkGray }
function Write-Header {
  param($subtitle = "Setup")
  Write-Host ""
  Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
  Write-Host "  OpenClaw Safe-Box — $subtitle" -ForegroundColor Cyan
  Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
}

function Read-Value {
  param(
    [string]$Prompt,
    [string]$Default = "",
    [switch]$Secret
  )
  if ($Default) {
    Write-Host "  (press Enter to keep existing value)" -ForegroundColor DarkGray
  }
  Write-Host -NoNewline "  → "
  if ($Secret) {
    $secure = Read-Host -AsSecureString
    $value = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
      [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    )
  } else {
    $value = Read-Host
  }
  if ([string]::IsNullOrWhiteSpace($value)) { $value = $Default }
  return $value
}

# =============================================================================
# Resolve script directory
# =============================================================================
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# =============================================================================
# 1. Welcome
# =============================================================================
Write-Header
Write-Host ""
Write-Host "  This script will set up OpenClaw Safe-Box on your machine." -ForegroundColor White
Write-Host "  It takes about 3-5 minutes depending on your internet speed." -ForegroundColor White
Write-Host ""
Write-Dim "You'll need:"
Write-Dim "  • Docker Desktop running"
Write-Dim "  • An Anthropic or OpenAI API key"
Write-Dim "  • A Telegram bot token (or another supported channel)"
Write-Host ""

# =============================================================================
# 2. Execution policy check (friendly guidance)
# =============================================================================
$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -eq 'Restricted') {
  Write-Fail ("Script execution is disabled for your user.`n`n" +
    "  Fix it by running this in PowerShell, then try again:`n" +
    "    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned")
}

# =============================================================================
# 3. Prerequisite checks
# =============================================================================
Write-Step "Checking prerequisites"

# Docker CLI
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  Write-Fail ("Docker is not installed.`n`n" +
    "  Please install Docker Desktop from https://www.docker.com/products/docker-desktop`n" +
    "  then re-run this script.")
}
Write-Ok "Docker CLI found"

# Docker daemon
$dockerInfo = docker info 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Fail ("Docker is not running.`n`n" +
    "  Please open Docker Desktop from your Start menu or system tray,`n" +
    "  wait for it to finish starting (the whale icon stops animating),`n" +
    "  then re-run this script.")
}
Write-Ok "Docker daemon is running"

# Docker Compose v2
$composeVersion = docker compose version --short 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Fail ("Docker Compose v2 is not available.`n`n" +
    "  Please update Docker Desktop to version 3.6 or later.")
}
Write-Ok "Docker Compose v2 found ($composeVersion)"

# RAM check (warn only)
$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
if ($os) {
  $ramMB = [math]::Round($os.TotalVisibleMemorySize / 1024)
  if ($ramMB -lt 2048) {
    Write-Warn "Your machine has less than 2 GB of RAM. OpenClaw may run slowly."
  }
}

# =============================================================================
# 4. Detect re-run (idempotency)
# =============================================================================
$EnvFile   = Join-Path $ScriptDir ".env"
$ExistingEnv = @{}
$IsRerun   = $false

if (Test-Path $EnvFile) {
  $IsRerun = $true
  # Parse existing .env into a hashtable
  Get-Content $EnvFile | Where-Object { $_ -match '^\s*([^#][^=]+)=(.*)' } | ForEach-Object {
    $key, $val = $_ -split '=', 2
    $ExistingEnv[$key.Trim()] = $val.Trim()
  }
  Write-Host ""
  Write-Warn "A .env file already exists from a previous setup."
  Write-Dim "Existing values will be used as defaults. Press Enter to keep them."
}

# Helper: get value from existing .env or return empty
function Existing { param($key) if ($ExistingEnv.ContainsKey($key)) { $ExistingEnv[$key] } else { "" } }

# =============================================================================
# 5. Collect configuration
# =============================================================================
Write-Step "Configuration"

# ── AI provider ──────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  AI provider" -ForegroundColor White
Write-Dim "You need an API key for at least one AI provider."
Write-Host ""
Write-Host "  Anthropic API key " -NoNewline; Write-Dim "(get one at console.anthropic.com — recommended)"
Write-Dim "Leave blank to skip if you're using OpenAI instead."
$NewAnthropicKey = Read-Value -Default (Existing "ANTHROPIC_API_KEY")

Write-Host ""
Write-Host "  OpenAI API key " -NoNewline; Write-Dim "(get one at platform.openai.com)"
Write-Dim "Leave blank to skip if you're using Anthropic instead."
$NewOpenAIKey = Read-Value -Default (Existing "OPENAI_API_KEY")

if ([string]::IsNullOrWhiteSpace($NewAnthropicKey) -and [string]::IsNullOrWhiteSpace($NewOpenAIKey)) {
  Write-Fail "You must provide at least one AI provider API key (Anthropic or OpenAI)."
}

# ── Messaging channel ─────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Messaging channel" -ForegroundColor White
Write-Dim "Add a channel now so you can talk to OpenClaw. You can add more later."
Write-Host ""
Write-Host "  Telegram bot token " -NoNewline; Write-Dim "(create a bot via @BotFather on Telegram)"
Write-Dim "Leave blank to skip — you can add it later via .\add-channel.ps1"
$NewTelegramToken = Read-Value -Default (Existing "TELEGRAM_BOT_TOKEN")

# ── Workspace path ────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Workspace folder" -ForegroundColor White
Write-Dim "This is the ONLY folder on your laptop that OpenClaw can access."
Write-Dim "The agent can create and read files here. Everything else is blocked."
Write-Host ""
Write-Host "  Workspace path:"
$DefaultWorkspace = Join-Path $env:USERPROFILE "openclaw-workspace"
$ExistingWorkspace = Existing "OPENCLAW_WORKSPACE"
if ([string]::IsNullOrWhiteSpace($ExistingWorkspace)) { $ExistingWorkspace = $DefaultWorkspace }
$NewWorkspace = Read-Value -Default $ExistingWorkspace
# Normalise to absolute path with forward slashes for Docker
$NewWorkspace = [System.IO.Path]::GetFullPath($NewWorkspace)
$NewWorkspaceDocker = $NewWorkspace -replace '\\', '/'

# =============================================================================
# 6. Generate gateway token
# =============================================================================
Write-Step "Generating gateway token"

$ExistingToken = Existing "OPENCLAW_GATEWAY_TOKEN"
if (-not [string]::IsNullOrWhiteSpace($ExistingToken)) {
  Write-Ok "Keeping existing gateway token"
  $NewGatewayToken = $ExistingToken
} else {
  # Cryptographically random 48-character hex token via .NET
  $bytes = [byte[]]::new(24)
  [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
  $NewGatewayToken = -join ($bytes | ForEach-Object { $_.ToString('x2') })
  Write-Ok "Generated new gateway token"
}

# =============================================================================
# 7. Write .env
# =============================================================================
Write-Step "Writing configuration to .env"

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm 'UTC'")

$envContent = @"
# OpenClaw Safe-Box — configuration
# Generated by setup.ps1 on $timestamp
# Do not commit this file to version control.

# Gateway authentication token (auto-generated — do not share)
OPENCLAW_GATEWAY_TOKEN=$NewGatewayToken

# AI provider(s)
ANTHROPIC_API_KEY=$NewAnthropicKey
OPENAI_API_KEY=$NewOpenAIKey

# Messaging channels
TELEGRAM_BOT_TOKEN=$NewTelegramToken
DISCORD_BOT_TOKEN=$(Existing "DISCORD_BOT_TOKEN")
SLACK_BOT_TOKEN=$(Existing "SLACK_BOT_TOKEN")
SLACK_APP_TOKEN=$(Existing "SLACK_APP_TOKEN")

# Docker image
OPENCLAW_IMAGE=$(if (Existing "OPENCLAW_IMAGE") { Existing "OPENCLAW_IMAGE" } else { "ghcr.io/openclaw/openclaw:latest" })

# Workspace folder (the only host directory OpenClaw can access)
# Forward slashes required for Docker volume mounts on Windows
OPENCLAW_WORKSPACE=$NewWorkspaceDocker

# Timezone
TZ=$(if (Existing "TZ") { Existing "TZ" } else { "UTC" })
"@

Set-Content -Path $EnvFile -Value $envContent -Encoding UTF8

# Restrict .env permissions to current user only (equivalent of chmod 600)
try {
  $acl = Get-Acl $EnvFile
  $acl.SetAccessRuleProtection($true, $false)   # disable inheritance, remove inherited rules
  $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $env:USERNAME, "FullControl", "Allow"
  )
  $acl.SetAccessRule($rule)
  Set-Acl -Path $EnvFile -AclObject $acl
  Write-Ok ".env written (permissions restricted to current user only)"
} catch {
  Write-Ok ".env written"
  Write-Warn "Could not restrict .env file permissions — consider doing this manually."
}

# =============================================================================
# 8. Create workspace directory
# =============================================================================
Write-Step "Setting up workspace folder"

if (Test-Path $NewWorkspace) {
  Write-Ok "Workspace already exists: $NewWorkspace"
} else {
  New-Item -ItemType Directory -Path $NewWorkspace -Force | Out-Null
  Write-Ok "Created workspace: $NewWorkspace"
}

# Write README inside workspace
$readmePath = Join-Path $NewWorkspace "README.txt"
if (-not (Test-Path $readmePath)) {
  @"
This folder is your OpenClaw Safe-Box workspace.

OpenClaw can read and write files here. This is the ONLY folder on your
computer that OpenClaw has access to. Everything else (your Documents,
Downloads, Desktop, etc.) is blocked by the container.

You can:
  - Put files here for OpenClaw to read and process
  - Ask OpenClaw to create documents and they'll appear here
  - Organise it into subfolders however you like

Deleting this folder (or running 'docker compose down -v') removes all
OpenClaw data from your machine.
"@ | Set-Content -Path $readmePath -Encoding UTF8
}

# =============================================================================
# 9. Pull Docker image
# =============================================================================
Write-Step "Pulling OpenClaw Docker image"
Write-Dim "This may take a minute on first run (image is ~400 MB)..."
Write-Host ""

$image = if ($ExistingEnv.ContainsKey("OPENCLAW_IMAGE") -and $ExistingEnv["OPENCLAW_IMAGE"]) {
  $ExistingEnv["OPENCLAW_IMAGE"]
} else {
  "ghcr.io/openclaw/openclaw:latest"
}

Push-Location $ScriptDir
try {
  docker compose pull openclaw-gateway
  if ($LASTEXITCODE -ne 0) {
    Write-Fail ("Failed to pull the Docker image.`n`n" +
      "  Check your internet connection and try again.`n" +
      "  If the problem persists, try manually running:`n" +
      "    docker pull $image")
  }
  Write-Ok "Image pulled: $image"
} finally {
  Pop-Location
}

# =============================================================================
# 10. Start the gateway
# =============================================================================
Write-Step "Starting OpenClaw Safe-Box"

Push-Location $ScriptDir
try {
  $running = docker compose ps --status running openclaw-gateway 2>&1
  if ($running -match "openclaw-gateway") {
    Write-Warn "OpenClaw is already running — restarting with new configuration"
    docker compose restart openclaw-gateway | Out-Null
  } else {
    docker compose up -d openclaw-gateway | Out-Null
  }
  if ($LASTEXITCODE -ne 0) {
    Write-Fail ("Failed to start the container.`n`n" +
      "  Check the logs:`n    docker compose logs openclaw-gateway")
  }
  Write-Ok "Container started"
} finally {
  Pop-Location
}

# =============================================================================
# 11. Wait for gateway to be healthy
# =============================================================================
Write-Step "Waiting for gateway to start"
Write-Dim "(usually takes 15-30 seconds)"
Write-Host -NoNewline "  "

$attempts   = 0
$maxAttempts = 30
$healthy    = $false

while ($attempts -lt $maxAttempts) {
  $attempts++
  try {
    $result = docker compose --project-directory $ScriptDir exec -T openclaw-gateway `
      wget -qO- http://127.0.0.1:18789/healthz 2>&1
    if ($LASTEXITCODE -eq 0) { $healthy = $true; break }
  } catch { }
  Write-Host -NoNewline "."
  Start-Sleep -Seconds 3
}

Write-Host ""

if (-not $healthy) {
  Write-Fail ("The gateway didn't start within 90 seconds.`n`n" +
    "  Check the logs for errors:`n" +
    "    docker compose logs openclaw-gateway`n`n" +
    "  Then try restarting:`n" +
    "    docker compose up -d")
}

Write-Ok "Gateway is up and healthy"

# =============================================================================
# 12. Open browser
# =============================================================================
Write-Step "Opening Control UI"

$controlUiUrl = "http://localhost:18789"
Start-Process $controlUiUrl
Write-Ok "Control UI: $controlUiUrl"

# =============================================================================
# 13. Done — show token and next steps
# =============================================================================
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  Setup complete!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Your gateway token:" -ForegroundColor White
Write-Host ""
Write-Host "  $NewGatewayToken" -ForegroundColor Yellow
Write-Host ""
Write-Dim "  Copy this and paste it into the Control UI when prompted."
Write-Dim "  It's also saved in .env if you need it again."
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
if (-not [string]::IsNullOrWhiteSpace($NewTelegramToken)) {
  Write-Host "    1. Paste the token above into the Control UI at $controlUiUrl"
  Write-Host "    2. Message your Telegram bot — it should reply!"
} else {
  Write-Host "    1. Paste the token above into the Control UI at $controlUiUrl"
  Write-Host "    2. Add a messaging channel:  .\add-channel.ps1 telegram"
  Write-Host "    3. Message your bot and say hello!"
}
Write-Host ""
Write-Host "  Useful commands:" -ForegroundColor White
Write-Dim "  Stop OpenClaw:     docker compose stop"
Write-Dim "  Start OpenClaw:    docker compose up -d"
Write-Dim "  View logs:         docker compose logs -f openclaw-gateway"
Write-Dim "  Add a channel:     .\add-channel.ps1 <telegram|discord|slack>"
Write-Dim "  Full reset:        docker compose down -v"
Write-Host ""
Write-Host "  Your workspace: $NewWorkspace" -ForegroundColor White
Write-Dim "  This is the only folder OpenClaw can access on your machine."
Write-Host ""
