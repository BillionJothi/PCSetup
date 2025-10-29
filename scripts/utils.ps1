function Load-Settings($path) {
    if (-not (Test-Path $path)) {
        throw "Settings file not found at $path"
    }
    return Get-Content $path | ConvertFrom-Json
}

function Ensure-Folders($settings) {
    $settings.folders.PSObject.Properties | ForEach-Object {
        $folderPath = (Resolve-Path -Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) $_.Value -ErrorAction SilentlyContinue)) -ErrorAction SilentlyContinue
        if (-not (Test-Path $folderPath)) {
            New-Item -ItemType Directory -Force -Path $folderPath | Out-Null
        }
    }
}

function Backup-JSON($packagePath, $settings) {
    if (Test-Path $packagePath) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $computerName = $env:COMPUTERNAME
        $backupName = "packages_${computerName}_$timestamp.json"
        $backupFile = Join-Path (Resolve-Path $settings.folders.backups) $backupName
        Copy-Item $packagePath $backupFile
        Write-Host "🧾 Backup saved: $backupFile"
        Rotate-Backups $settings
    }
}

function Start-Log($mode, $settings) {
    $logDir = Resolve-Path $settings.folders.logs
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $logFile = Join-Path $logDir "$($env:COMPUTERNAME)_${mode}_$timestamp.log"
    New-Item -Path $logFile -ItemType File -Force | Out-Null
    return $logFile
}

function Write-Log($message, $logFile) {
    $timestamp = Get-Date -Format "HH:mm:ss"
    $entry = "[$timestamp] $message"
    Add-Content -Path $logFile -Value $entry
    Write-Host $entry
}

function Rotate-Backups($settings) {
    $backupDir = Resolve-Path $settings.folders.backups
    $max = $settings.retention.maxBackupFiles
    $files = Get-ChildItem $backupDir | Sort-Object LastWriteTime -Descending
    if ($files.Count -gt $max) {
        $files | Select-Object -Skip $max | Remove-Item -Force
    }
}

function Check-Command($cmd) {
    return (Get-Command $cmd -ErrorAction SilentlyContinue) -ne $null
}

function Show-Summary($summary, $logFile) {
    Write-Host "`n=== Summary ==="
    foreach ($item in $summary.Keys) {
        Write-Host "$item: $($summary[$item])"
    }
    Write-Log "Summary complete." $logFile
}

function Request-Restart($logFile) {
    Write-Host "⚠️ System restart required."
    $answer = Read-Host "Restart now? (y/n)"
    if ($answer -eq "y") {
        Write-Log "Restarting system..." $logFile
        Restart-Computer -Force
    } else {
        Write-Log "User chose not to restart." $logFile
    }
}
