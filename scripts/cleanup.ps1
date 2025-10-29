param($settings, $logFile)

. "$PSScriptRoot\utils.ps1"

Write-Log "🧹 Starting cleanup..." $logFile

if ($settings.cleanup.clearTempFiles) {
    Write-Log "🧽 Clearing temp files..." $logFile
    Get-ChildItem $env:TEMP -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
}

if ($settings.cleanup.clearPackageCaches) {
    Write-Log "🧼 Clearing package caches..." $logFile
    $paths = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalCache",
        "$env:LOCALAPPDATA\scoop\cache",
        "C:\ProgramData\chocolatey\lib-bad"
    )
    foreach ($p in $paths) {
        if (Test-Path $p) {
            Get-ChildItem $p -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        }
    }
}

Write-Log "✅ Cleanup completed." $logFile
