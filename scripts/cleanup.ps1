<#
.SYNOPSIS
    Performs cleanup of logs, backups, temporary files, and package caches.

.DESCRIPTION
    Reads settings from configs\settings.json for retention and cleanup behavior.
    Compatible with setup.ps1, update.ps1, and utils.ps1.

.NOTES
    Author: You + ChatGPT Automation Framework
    Version: 1.1
#>

# -----------------------------
# Load Utilities & Config
# -----------------------------
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module "$ScriptDir\utils.ps1" -Force

$configFile = "$ScriptDir\..\configs\settings.json"
if (-not (Test-Path $configFile)) {
    Write-Host "⚠️ settings.json not found. Using default cleanup settings."
    $settings = @{
        folders = @{
            logs = "$ScriptDir\..\logs"
            backups = "$ScriptDir\..\backups"
        }
        retention = @{
            logDays = 14
            backupDays = 30
            maxLogFiles = 10
            maxBackupFiles = 10
        }
        cleanup = @{
            clearTempFiles = $true
            clearPackageCaches = $true
        }
    }
} else {
    $settings = Get-Content $configFile | ConvertFrom-Json
}

$logDir = Resolve-Path (Join-Path $ScriptDir $settings.folders.logs)
$backupDir = Resolve-Path (Join-Path $ScriptDir $settings.folders.backups)

# -----------------------------
# Start Logging
# -----------------------------
$logFile = Start-Log "cleanup"
Write-Log "🧹 Starting cleanup process..." $logFile

# -----------------------------
# Helper: Remove Old Files by Age or Count
# -----------------------------
function Cleanup-OldFiles {
    param(
        [string]$folder,
        [string]$pattern,
        [int]$maxCount,
        [int]$maxDays,
        [string]$type
    )

    if (Test-Path $folder) {
        $files = Get-ChildItem -Path $folder -Filter $pattern | Sort-Object LastWriteTime -Descending

        # Remove old files exceeding count
        $toRemove = @()
        if ($files.Count -gt $maxCount) {
            $toRemove += $files | Select-Object -Skip $maxCount
        }

        # Remove files older than retention days
        $threshold = (Get-Date).AddDays(-$maxDays)
        $toRemove += $files | Where-Object { $_.LastWriteTime -lt $threshold }

        foreach ($f in ($toRemove | Select-Object -Unique)) {
            try {
                Remove-Item $f.FullName -Force
                Write-Log "🗑️ Removed old $type file: $($f.Name)" $logFile
            } catch {
                Write-Log "⚠️ Failed to remove $type file: $($f.Name) - $_" $logFile
            }
        }
    }
}

# -----------------------------
# 1️⃣ Clean Logs & Backups
# -----------------------------
Cleanup-OldFiles $logDir "*.log" $settings.retention.maxLogFiles $settings.retention.logDays "log"
Cleanup-OldFiles $backupDir "*.json" $settings.retention.maxBackupFiles $settings.retention.backupDays "backup"

# -----------------------------
# 2️⃣ Clear Temporary Files
# -----------------------------
if ($settings.cleanup.clearTempFiles) {
    Write-Log "🧽 Clearing Windows temporary directories..." $logFile
    try {
        $tempPaths = @("$env:TEMP", "$env:WINDIR\Temp")
        foreach ($t in $tempPaths) {
            if (Test-Path $t) {
                Get-ChildItem -Path $t -Recurse -ErrorAction SilentlyContinue |
                Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            }
        }
        Write-Log "✅ Temp files cleared." $logFile
    } catch {
        Write-Log "⚠️ Failed to clear temp files: $_" $logFile
    }
}

# -----------------------------
# 3️⃣ Clear Package Caches
# -----------------------------
if ($settings.cleanup.clearPackageCaches) {
    Write-Log "🗃️ Clearing package manager caches..." $logFile

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        try {
            winget cache --reset | Out-Null
            Write-Log "✅ Winget cache cleared." $logFile
        } catch { Write-Log "⚠️ Winget cache clear failed: $_" $logFile }
    }

    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        try {
            scoop cache rm * | Out-Null
            Write-Log "✅ Scoop cache cleared." $logFile
        } catch { Write-Log "⚠️ Scoop cache clear failed: $_" $logFile }
    }

    if (Get-Command choco -ErrorAction SilentlyContinue) {
        try {
            choco clean --yes | Out-Null
            Write-Log "✅ Chocolatey cache cleared." $logFile
        } catch { Write-Log "⚠️ Chocolatey cache clear failed: $_" $logFile }
    }
}

# -----------------------------
# 4️⃣ Finish
# -----------------------------
Write-Log "🧾 Cleanup completed successfully." $logFile
Write-Host "✅ Cleanup finished! Log saved to $logFile"
