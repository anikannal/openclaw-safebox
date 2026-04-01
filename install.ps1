#Requires -Version 5.1
# =============================================================================
# OpenClaw Safe-Box — install.ps1
# One-line installer for Windows (PowerShell)
#
# Usage (run in PowerShell):
#   irm https://raw.githubusercontent.com/YOUR_USERNAME/openclaw-safebox/main/install.ps1 | iex
#
# What this does:
#   1. Checks that Docker is installed and running
#   2. Downloads the Safe-Box files to ~/openclaw-safebox
#      (uses git clone if available, zip download otherwise)
#   3. Hands off to setup.ps1 for the guided first-run configuration
# =============================================================================
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# =============================================================================
# Config — update YOUR_USERNAME before publishing
# =============================================================================
$RepoUrl  = "https://github.com/YOUR_USERNAME/openclaw-safebox.git"
$ZipUrl   = "https://github.com/YOUR_USERNAME/openclaw-safebox/archive/refs/heads/main.zip"
$InstallDir = if ($env:OPENCLAW_INSTALL_DIR) { $env:OPENCLAW_INSTALL_DIR } `
              else { Join-Path $env:USERPROFILE "openclaw-safebox" }

# =============================================================================
# Formatting
# =============================================================================
function Write-Step { param($msg) Write-Host "`n▸ $msg" -ForegroundColor White }
function Write-Ok   { param($msg) Write-Host "  ✓  $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "  ⚠  $msg" -ForegroundColor Yellow }
function Write-Dim  { param($msg) Write-Host "  $msg" -ForegroundColor DarkGray }
function Write-Fail {
  param($msg)
  Write-Host "`nError: $msg`n" -ForegroundColor Red
  exit 1
}

# =============================================================================
# Execution policy check
# =============================================================================
$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -eq 'Restricted') {
  Write-Fail ("Script execution is disabled for your user.`n`n" +
    "  Fix it by running this in PowerShell, then try again:`n" +
    "    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned")
}

# =============================================================================
# Welcome
# =============================================================================
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  OpenClaw Safe-Box — Installer" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Installing to: $InstallDir" -ForegroundColor White
Write-Dim "Set `$env:OPENCLAW_INSTALL_DIR to change this."

# =============================================================================
# 1. Check Docker
# =============================================================================
Write-Step "Checking Docker"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  Write-Fail ("Docker is not installed.`n`n" +
    "  Please install Docker Desktop from https://www.docker.com/products/docker-desktop`n" +
    "  then re-run this installer.")
}
Write-Ok "Docker CLI found"

$dockerInfo = docker info 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Fail ("Docker is not running.`n`n" +
    "  Please open Docker Desktop from your Start menu or system tray,`n" +
    "  wait for it to finish starting, then re-run this installer.")
}
Write-Ok "Docker daemon is running"

$composeCheck = docker compose version 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Fail "Docker Compose v2 is not available. Please update Docker Desktop."
}
Write-Ok "Docker Compose v2 found"

# =============================================================================
# 2. Download Safe-Box files
# =============================================================================
Write-Step "Downloading OpenClaw Safe-Box"

$gitAvailable = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
$gitDir = Join-Path $InstallDir ".git"

if (Test-Path $gitDir) {
  # Existing git repo — pull latest
  Write-Dim "Existing installation found — updating to latest version..."
  try {
    git -C $InstallDir pull --ff-only 2>&1 | Out-Null
    Write-Ok "Updated to latest version"
  } catch {
    Write-Warn "Could not auto-update (local changes present). Continuing with existing files."
  }

} elseif ($gitAvailable) {
  # Fresh git clone
  Write-Dim "Cloning repository..."
  git clone --depth 1 $RepoUrl $InstallDir 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Write-Fail "git clone failed. Check your internet connection and try again."
  }
  Write-Ok "Downloaded via git"

} else {
  # No git — zip download via Invoke-WebRequest
  Write-Warn "git not found — downloading zip instead"

  if (Test-Path $InstallDir) {
    Write-Warn "Directory already exists at $InstallDir. Using existing files."
  } else {
    Write-Dim "Downloading zip..."
    $TmpZip = Join-Path $env:TEMP "openclaw-safebox-$(Get-Random).zip"
    $TmpDir = Join-Path $env:TEMP "openclaw-safebox-$(Get-Random)"

    try {
      # Use TLS 1.2+ (required by GitHub)
      [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
      Invoke-WebRequest -Uri $ZipUrl -OutFile $TmpZip -UseBasicParsing
    } catch {
      Write-Fail ("Download failed: $($_.Exception.Message)`n`n" +
        "  Check your internet connection and try again.")
    }

    Write-Dim "Extracting..."
    try {
      Expand-Archive -Path $TmpZip -DestinationPath $TmpDir -Force
    } catch {
      Write-Fail "Could not extract the downloaded zip file."
    }

    # GitHub zips extract to a subfolder like openclaw-safebox-main\
    $extracted = Get-ChildItem $TmpDir | Select-Object -First 1
    Move-Item -Path $extracted.FullName -Destination $InstallDir

    Remove-Item $TmpZip -Force -ErrorAction SilentlyContinue
    Remove-Item $TmpDir -Force -Recurse -ErrorAction SilentlyContinue
    Write-Ok "Downloaded and extracted"
  }
}

# =============================================================================
# 3. Hand off to setup.ps1
# =============================================================================
Write-Step "Starting setup"
Write-Host ""
Write-Host "  Files are ready at: $InstallDir" -ForegroundColor White
Write-Dim "Launching setup.ps1..."
Write-Host ""

$setupScript = Join-Path $InstallDir "setup.ps1"
if (-not (Test-Path $setupScript)) {
  Write-Fail "setup.ps1 not found in $InstallDir. The download may be incomplete — try re-running the installer."
}

& $setupScript
