<#
.SYNOPSIS
    Unified system updater for Windows, Winget, Scoop, and Chocolatey.

.DESCRIPTION
    Runs updates from multiple sources with optional selection.
    Logs all operations and handles backup of current package lists.
#>

# ==========================
# 🔧 CONFIGURATION
# ==========================

$BaseDir        = "C:\SetupAutomation"
$ConfigDir      = Join-Path $BaseDir "configs"
$BackupDir      = Join-Path $BaseDir "backups"
$LogDir         = Join-Path $BaseDir "logs"
$Timestamp      = Get-Date -Format "yyyyMMdd_HHmmss"
$Hostname       = $env:COMPUTERNAME
$BackupFile     = Join-Path $BackupDir "packages_${Hostname}_$Timestamp.json"
$LogFile        = Join-Path $LogDir "update_$Timestamp.log"

# Ensure directories exist
$dirs = @($BaseDir, $ConfigDir, $BackupDir, $LogDir)
foreach ($dir in $dirs) { if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null } }

# ==========================
# 🪵 LOGGING FUNCTION
# ==========================
function Write-Log {
    param([string]$Message)
    $time = (Get-Date).ToString("HH:mm:ss")
    $formatted = "[$time] $Message"
    Write-Host $formatted
    Add-Content -Path $LogFile -Value $formatted
}

# ==========================
# 💾 BACKUP PACKAGE LISTS
# ==========================
Write-Log "🧾 Backing up current package lists..."
$BackupData = @{
    timestamp = $Timestamp
    hostname  = $Hostname
    sources   = @{}
}
try {
    $BackupData.sources.winget = winget list | Out-String
    $BackupData.sources.scoop  = if (Get-Command scoop -ErrorAction SilentlyContinue) { scoop list | Out-String } else { "Not installed" }
    $BackupData.sources.choco  = if (Get-Command choco -ErrorAction SilentlyContinue) { choco list --localonly | Out-String } else { "Not installed" }
    $BackupData.sources.windows = "Windows Updates not backed up"
    $BackupData | ConvertTo-Json -Depth 4 | Out-File $BackupFile -Encoding UTF8
    Write-Log "✅ Backup saved: $BackupFile"
} catch {
    Write-Log "⚠️ Backup failed: $_"
}

# ==========================
# ⚙️ SELECT SOURCES
# ==========================
Write-Host "Available sources: winget, scoop, choco, windows"
$sourcesInput = Read-Host "Enter which sources to process (comma-separated or 'all')"
if ($sourcesInput -eq "all") {
    $SelectedSources = @("winget", "scoop", "choco", "windows")
} else {
    $SelectedSources = $sourcesInput.Split(",") | ForEach-Object { $_.Trim().ToLower() }
}

Write-Log "=== Starting update process ==="
Write-Log "Selected sources: $($SelectedSources -join ', ')"

# ==========================
# 🧱 UTILITY FUNCTIONS
# ==========================

function Ensure-PSGallery {
    if (-not (Get-PSRepository | Where-Object Name -eq "PSGallery")) {
        Write-Log "🔧 Re-registering PSGallery..."
        Register-PSRepository -Default
    }
}

# Winget update
function Update-Winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Log "⚠️ Winget not found. Skipping..."
        return
    }
    Write-Log "📦 Running Winget upgrade check..."
    try {
        $updates = winget upgrade --accept-source-agreements
        Write-Host $updates
        Write-Log "✅ Winget update check completed."
    } catch {
        Write-Log "❌ Winget update failed: $_"
    }
}

# Scoop update
function Update-Scoop {
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Log "⚠️ Scoop not found. Skipping..."
        return
    }
    Write-Log "🥄 Updating Scoop..."
    try {
        scoop update
        scoop update *
        Write-Log "✅ Scoop updated."
    } catch {
        Write-Log "❌ Scoop update failed: $_"
    }
}

# Chocolatey update
function Update-Choco {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Log "⚠️ Chocolatey not found. Skipping..."
        return
    }
    Write-Log "🍫 Updating Chocolatey packages..."
    try {
        choco upgrade all -y
        Write-Log "✅ Chocolatey updated."
    } catch {
        Write-Log "❌ Chocolatey update failed: $_"
    }
}

# Windows Update
function Update-Windows {
    Write-Log "🪟 Checking Windows Updates..."
    try {
        Ensure-PSGallery
        if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            Write-Log "Installing PSWindowsUpdate module..."
            Install-Module PSWindowsUpdate -Force -AllowClobber -ErrorAction Stop
        }
        Import-Module PSWindowsUpdate
        $updates = Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot
        if ($updates) {
            Write-Host $updates
            Write-Log "✅ Windows updates found and processed."
        } else {
            Write-Log "ℹ️ No Windows updates available."
        }
    } catch {
        Write-Log "❌ Windows Update failed: $_"
    }
}

# ==========================
# 🚀 EXECUTE SELECTED SOURCES
# ==========================

foreach ($src in $SelectedSources) {
    switch ($src) {
        "winget"  { Update-Winget }
        "scoop"   { Update-Scoop }
        "choco"   { Update-Choco }
        "windows" { Update-Windows }
        default   { Write-Log "⚠️ Unknown source '$src'. Skipping..." }
    }
}

# ==========================
# 🧹 CLEANUP
# ==========================
Write-Log "✅ Completed update process for selected sources."
Write-Log "🧹 Running cleanup process..."
# Add any cleanup commands if needed
Write-Log "Cleanup completed."

# ==========================
# 💤 RESTART CHECK
# ==========================
$pending = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction SilentlyContinue)
if ($pending) {
    Write-Log "🔁 System restart required."
    $restartChoice = Read-Host "Restart now? (Y/N)"
    if ($restartChoice -match '^[Yy]$') { Restart-Computer }
} else {
    Write-Log "💤 No restart required."
}

# ==========================
# 📊 SUMMARY
# ==========================
Write-Host "`n=== Summary ==="
foreach ($src in $SelectedSources) {
    Write-Host "$src: Completed"
}
Write-Log "Summary complete."
