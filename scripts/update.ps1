param($settings, $logFile)

. "$PSScriptRoot\utils.ps1"

$summary = @{}

Write-Host "Available sources: winget, scoop, choco, windows"
$input = Read-Host "Enter which sources to process (comma-separated or 'all')"
$sources = if ($input -eq "all") { @("winget", "scoop", "choco", "windows") } else { $input -split "," }

foreach ($src in $sources) {
    $src = $src.Trim().ToLower()

    switch ($src) {
        "winget" {
            if (Check-Command "winget") {
                Write-Log "⬆️ Updating via winget..." $logFile
                winget upgrade --all --accept-source-agreements --accept-package-agreements
                $summary["winget"] = "Done"
            } else {
                Write-Log "❌ Winget not found." $logFile
                $summary["winget"] = "Skipped"
            }
        }
        "scoop" {
            if (Check-Command "scoop") {
                Write-Log "⬆️ Updating via scoop..." $logFile
                scoop update * | Out-Null
                $summary["scoop"] = "Done"
            } else {
                $summary["scoop"] = "Skipped"
            }
        }
        "choco" {
            if (Check-Command "choco") {
                Write-Log "⬆️ Updating via Chocolatey..." $logFile
                choco upgrade all -y | Out-Null
                $summary["choco"] = "Done"
            } else {
                $summary["choco"] = "Skipped"
            }
        }
        "windows" {
            Write-Log "🪟 Checking Windows Updates..." $logFile
            try {
                if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
                    Install-Module -Name PSWindowsUpdate -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
                }
                Import-Module PSWindowsUpdate
                Get-WindowsUpdate -AcceptAll -Install -IgnoreReboot
                $summary["windows"] = "Done"
            } catch {
                Write-Log "❌ Windows Update failed: $_" $logFile
                $summary["windows"] = "Failed"
            }
        }
        default {
            Write-Host "⚠️ Unknown source '$src'"
        }
    }
}

Write-Log "✅ Completed update process for selected sources." $logFile
Show-Summary $summary $logFile
