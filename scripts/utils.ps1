# ==============================================
# utils.ps1 - Common Utility Functions
# ==============================================

function Load-Settings {
    param([string]$SettingsPath)

    if (-not (Test-Path $SettingsPath)) {
        throw "Settings file not found at $SettingsPath"
    }

    try {
        $json = Get-Content -Path $SettingsPath -Raw | ConvertFrom-Json
        return $json
    } catch {
        throw "Failed to parse settings.json: $($_.Exception.Message)"
    }
}

# --- Determine Script Directory ---
$scriptDir = Split-Path -Parent $PSCommandPath
if (-not $scriptDir) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}

# --- Load Settings ---
$settingsPath = Join-Path $scriptDir "..\configs\settings.json"
$global:Settings = Load-Settings $settingsPath

# --- Folder Setup ---
$global:LogsDir = Join-Path $scriptDir $Settings.folders.logs
$global:BackupsDir = Join-Path $scriptDir $Settings.folders.backups
New-Item -ItemType Directory -Force -Path $LogsDir, $BackupsDir | Out-Null

# --- Logging Functions ---
function Start-Log {
    param([string]$mode)

    $pc = $env:COMPUTERNAME
    $timestamp = (Get-Date -Format "yyyyMMdd_HHmmss")
    $logFile = Join-Path $LogsDir "${pc}_${mode}_${timestamp}.log"

    Write-Host "🧾 Logging to: $logFile"
    New-Item -ItemType File -Force -Path $logFile | Out-Null
    return $logFile
}

function Write-Log {
    param(
        [string]$Message,
        [string]$LogFile
    )
    $timestamp = Get-Date -Format "HH:mm:ss"
    $line = "[$timestamp] $Message"
    Add-Content -Path $LogFile -Value $line
    Write-Host $line
}

# --- Toast Notification ---
function Show-Toast {
    param([string]$Message)
    if ($Settings.notifications.showToast) {
        try {
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.MessageBox]::Show($Message, "Setup Notification")
        } catch {
            Write-Host "⚠️ Toast failed: $($_.Exception.Message)"
        }
    }
}

# --- Backup JSON File ---
function Backup-JSON {
    param([string]$FilePath)
    if (Test-Path $FilePath) {
        $fileName = Split-Path $FilePath -LeafBase
        $pc = $env:COMPUTERNAME
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $dest = Join-Path $BackupsDir "${fileName}_${pc}_${timestamp}.json"
        Copy-Item $FilePath $dest -Force
        Write-Host "🧾 Backup saved: $dest"
    }
}

# --- Check if Command Exists ---
function Check-Command {
    param([string]$Command)
    return (Get-Command $Command -ErrorAction SilentlyContinue) -ne $null
}

# --- Show Summary ---
function Show-Summary {
    param([hashtable]$Summary, [string]$LogFile)
    Write-Host "`n=== Summary ==="
    foreach ($item in $Summary.Keys) {
        Write-Host "$($item): $($Summary[$item])"
    }
    Write-Log "Summary complete." $LogFile
}

# --- Cleanup Old Files Based on Retention Settings ---
function Cleanup-OldFiles {
    param([string]$Folder, [int]$Days, [int]$MaxFiles)
    $files = Get-ChildItem -Path $Folder -File | Sort-Object LastWriteTime -Descending
    $cutoff = (Get-Date).AddDays(-$Days)
    foreach ($file in $files) {
        if ($file.LastWriteTime -lt $cutoff -or $files.Count -gt $MaxFiles) {
            Remove-Item $file.FullName -Force -ErrorAction SilentlyContinue
        }
    }
}

# --- Run Cleanup Based on Settings ---
function Run-RetentionCleanup {
    Write-Host "🧹 Running cleanup process..."
    Cleanup-OldFiles $LogsDir $Settings.retention.logDays $Settings.retention.maxLogFiles
    Cleanup-OldFiles $BackupsDir $Settings.retention.backupDays $Settings.retention.maxBackupFiles
    Write-Host "Cleanup completed."
}
