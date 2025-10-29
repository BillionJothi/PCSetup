# setup.ps1
$ErrorActionPreference = "Stop"

. "$PSScriptRoot\utils.ps1"

$settings = Load-Settings
$packageFile = Resolve-Path (Join-Path $PSScriptRoot $settings.folders.packages)

Backup-JSON $packageFile $settings

$mode = Read-Host "Choose action: (I)nstall or (U)pdate"
$mode = if ($mode -match '^[Uu]') { "update" } else { "install" }

$logFile = Start-Log $mode $settings
Write-Log "=== Starting $mode process ===" $logFile

$availableSources = @("winget", "scoop", "choco", "windows")
Write-Host "Available sources: $($availableSources -join ', ')"
$choice = Read-Host "Enter which sources to process (comma-separated or 'all')"
$sources = if ($choice -eq "all") { $availableSources } else { $choice -split "," | ForEach-Object { $_.Trim() } }

$pkgData = Get-Content $packageFile | ConvertFrom-Json
$summary = @{}
$pending = $false

foreach ($src in $sources) {
    switch ($src.ToLower()) {
        "winget" {
            if ((Check-Command "winget") -and $pkgData.winget) {
                Write-Log "⬆️ Processing Winget..." $logFile
                if ($mode -eq "update") { winget upgrade --all --accept-source-agreements --accept-package-agreements | Tee-Object -FilePath $logFile -Append }
                else { foreach ($app in $pkgData.winget) { winget install --id $app --accept-source-agreements --accept-package-agreements | Tee-Object -FilePath $logFile -Append } }
                $summary["winget"] = "Done"
            } else { $summary["winget"] = "Skipped" }
        }
        "scoop" {
            if ((Check-Command "scoop") -and $pkgData.scoop) {
                Write-Log "🪣 Processing Scoop..." $logFile
                scoop update | Tee-Object -FilePath $logFile -Append
                if ($mode -eq "install") { foreach ($app in $pkgData.scoop) { scoop install $app | Tee-Object -FilePath $logFile -Append } }
                $summary["scoop"] = "Done"
            } else { $summary["scoop"] = "Skipped" }
        }
        "choco" {
            if ((Check-Command "choco") -and $pkgData.choco) {
                Write-Log "🍫 Processing Chocolatey..." $logFile
                if ($mode -eq "update") { choco upgrade all -y | Tee-Object -FilePath $logFile -Append }
                else { foreach ($app in $pkgData.choco) { choco install $app -y | Tee-Object -FilePath $logFile -Append } }
                $summary["choco"] = "Done"
            } else { $summary["choco"] = "Skipped" }
        }
        "windows" {
            try {
                Write-Log "🪟 Checking Windows Updates..." $logFile
                if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
                    Write-Log "Installing PSWindowsUpdate module..." $logFile
                    Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser -ErrorAction Stop
                }
                Import-Module PSWindowsUpdate
                if ($mode -eq "update") {
                    Get-WindowsUpdate -AcceptAll -Install -AutoReboot | Tee-Object -FilePath $logFile -Append
                    $pending = $true
                }
                $summary["windows"] = "Done"
            } catch {
                Write-Log "❌ Windows Update failed: $_" $logFile
                $summary["windows"] = "Failed"
            }
        }
        default {
            Write-Log "⚠️ Unknown source: $src" $logFile
        }
    }
}

Write-Log "✅ Completed $mode process for selected sources." $logFile
Cleanup-OldFiles $settings $logFile

if ($pending) { Request-Restart $logFile } else { Write-Log "💤 No restart required." $logFile }

Show-Summary $summary $logFile $settings
