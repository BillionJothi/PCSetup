# utils.ps1

function Load-Settings {
    $settingsPath = "$PSScriptRoot\..\configs\settings.json"
    if (-not (Test-Path $settingsPath)) { throw "settings.json not found at $settingsPath" }
    return Get-Content $settingsPath | ConvertFrom-Json
}

function Backup-JSON {
    param ($file, $settings)
    $backupDir = Resolve-Path (Join-Path $PSScriptRoot $settings.folders.backups)
    if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir | Out-Null }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFile = Join-Path $backupDir ("packages_" + $env:COMPUTERNAME + "_$timestamp.json")
    Copy-Item $file $backupFile -Force
    Write-Host "🧾 Backup saved: $backupFile"
}

function Start-Log {
    param ($mode, $settings)
    $logDir = Resolve-Path (Join-Path $PSScriptRoot $settings.folders.logs)
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $logFile = Join-Path $logDir ("$env:COMPUTERNAME-$mode-$timestamp.log")
    "[$(Get-Date)] === $mode session started ===" | Out-File $logFile -Encoding UTF8
    return $logFile
}

function Write-Log {
    param ($msg, $file)
    "[$(Get-Date -Format 'HH:mm:ss')] $msg" | Tee-Object -FilePath $file -Append
}

function Check-Command {
    param ($cmd)
    return (Get-Command $cmd -ErrorAction SilentlyContinue) -ne $null
}

function Request-Restart {
    param ($logFile)
    Write-Log "🔁 Restart is required. Prompting user..." $logFile
    $restart = Read-Host "Restart now? (Y/N)"
    if ($restart -match '^[Yy]') { Restart-Computer -Force }
    else { Write-Log "Restart skipped by user." $logFile }
}

function Show-Summary {
    param ($summary, $logFile, $settings)
    Write-Host "`n=== Summary ==="
    foreach ($item in $summary.Keys) {
        Write-Host ("{0}: {1}" -f $item, $summary[$item])
    }
    Write-Log "Summary complete." $logFile

    if ($settings.notifications.showToast -and (Check-Command "New-BurntToastNotification")) {
        $title = "SetupAutomation Summary"
        $msg = ($summary.Keys | ForEach-Object { "$_ → $($summary[$_])" }) -join "`n"
        New-BurntToastNotification -Text $title, $msg
    }
}

function Cleanup-OldFiles {
    param ($settings, $logFile)
    Write-Log "🧹 Running cleanup process..." $logFile
    $now = Get-Date

    $folders = @(
        @{ Path = (Join-Path $PSScriptRoot $settings.folders.logs);  Max = $settings.retention.maxLogFiles;  Days = $settings.retention.logDays },
        @{ Path = (Join-Path $PSScriptRoot $settings.folders.backups); Max = $settings.retention.maxBackupFiles; Days = $settings.retention.backupDays }
    )

    foreach ($f in $folders) {
        if (Test-Path $f.Path) {
            $files = Get-ChildItem $f.Path -File | Sort-Object LastWriteTime -Descending
            $oldFiles = @($files | Where-Object { ($now - $_.LastWriteTime).Days -gt $f.Days }) +
                        @($files | Select-Object -Skip $f.Max)

            foreach ($file in $oldFiles) {
                Write-Log "🗑 Deleting old file: $($file.FullName)" $logFile
                Remove-Item $file.FullName -Force
            }
        }
    }
    Write-Log "Cleanup completed." $logFile
}
