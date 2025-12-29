# ==============================================
# update.ps1 - System & App Updates (with per-PC support)
# ==============================================

. "$PSScriptRoot\utils.ps1"

$logFile = Start-Log "update"
Write-Log "=== Starting update process ===" $logFile

# Load main packages.json
if (-not (Test-Path $Settings.folders.packages)) {
    Write-Log "❌ Main package file not found: $($Settings.folders.packages)" $logFile
    exit
}

$packages = Get-Content $Settings.folders.packages | ConvertFrom-Json

# Detect PC name and load per-PC JSON
$pcName = $env:COMPUTERNAME
$perPCFile = Join-Path (Split-Path $Settings.folders.packages -Parent) "packages_${pcName}.json"

if (Test-Path $perPCFile) {
    Write-Log "🔹 Found per-PC package file: $perPCFile" $logFile
    $perPCPackages = Get-Content $perPCFile | ConvertFrom-Json

    # Merge winget packages
    if ($perPCPackages.winget) {
        foreach ($id in $perPCPackages.winget) {
            $packages.packages += [PSCustomObject]@{
                Id = $id
                Name = $id
                Version = "latest"
                Source = "winget"
                ManagerName = "Winget"
            }
        }
    }

    # Merge choco packages if any
    if ($perPCPackages.choco) {
        foreach ($id in $perPCPackages.choco) {
            $packages.packages += [PSCustomObject]@{
                Id = $id
                Name = $id
                Version = "latest"
                Source = "choco"
                ManagerName = "Chocolatey"
            }
        }
    }

    # Merge scoop packages if any
    if ($perPCPackages.scoop) {
        foreach ($id in $perPCPackages.scoop) {
            $packages.packages += [PSCustomObject]@{
                Id = $id
                Name = $id
                Version = "latest"
                Source = "scoop"
                ManagerName = "Scoop"
            }
        }
    }
}

# Remove duplicates by Id
$packagesToUpdate = $packages.packages | Sort-Object Id -Unique

# Choose sources
$sources = @("winget", "scoop", "choco", "windows")
Write-Host "Available sources: $($sources -join ', ')"
$choice = Read-Host "Enter which sources to process (comma-separated or 'all')"

if ($choice -eq "all") {
    $selected = $sources
} else {
    $selected = $choice -split "," | ForEach-Object { $_.Trim().ToLower() }
}

$summary = @{}

# Process each source
foreach ($src in $selected) {
    switch ($src) {
        "winget" {
            if (Check-Command "winget") {
                Write-Log "🔄 Updating Winget packages..." $logFile
                foreach ($pkg in $packagesToUpdate | Where-Object { $_.ManagerName -eq "Winget" }) {
                    Write-Log "⏳ Updating $($pkg.Name) via winget..." $logFile
                    try {
                        winget upgrade --id $pkg.Id -e --accept-source-agreements --accept-package-agreements
                    } catch {
                        Write-Log "❌ Error updating $($pkg.Name): $($_.Exception.Message)" $logFile
                    }
                }
                $summary["winget"] = "Completed"
            } else { $summary["winget"] = "Not Installed" }
        }

        "scoop" {
            if (Check-Command "scoop") {
                Write-Log "🔄 Updating Scoop packages..." $logFile
                foreach ($pkg in $packagesToUpdate | Where-Object { $_.ManagerName -eq "Scoop" }) {
                    Write-Log "⏳ Updating $($pkg.Name) via scoop..." $logFile
                    try {
                        scoop update $pkg.Id | Out-Null
                    } catch {
                        Write-Log "❌ Error updating $($pkg.Name): $($_.Exception.Message)" $logFile
                    }
                }
                $summary["scoop"] = "Completed"
            } else { $summary["scoop"] = "Not Installed" }
        }

        "choco" {
            if (Check-Command "choco") {
                Write-Log "🔄 Updating Chocolatey packages..." $logFile
                foreach ($pkg in $packagesToUpdate | Where-Object { $_.ManagerName -eq "Chocolatey" }) {
                    Write-Log "⏳ Updating $($pkg.Name) via choco..." $logFile
                    try {
                        choco upgrade $pkg.Id -y | Out-Null
                    } catch {
                        Write-Log "❌ Error updating $($pkg.Name): $($_.Exception.Message)" $logFile
                    }
                }
                $summary["choco"] = "Completed"
            } else { $summary["choco"] = "Not Installed" }
        }

        "windows" {
            Write-Log "🪟 Checking Windows Updates..." $logFile
            try {
                if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
                    Write-Log "Installing PSWindowsUpdate module..." $logFile
                    Install-PackageProvider -Name NuGet -Force -Confirm:$false | Out-Null
                    Install-Module -Name PSWindowsUpdate -Force -Confirm:$false -Scope CurrentUser
                }
                Import-Module PSWindowsUpdate
                Get-WindowsUpdate -AcceptAll -Install -AutoReboot
                $summary["windows"] = "Completed"
            } catch {
                Write-Log "❌ Windows Update failed: $($_.Exception.Message)" $logFile
                $summary["windows"] = "Failed"
            }
        }
    }
}

Show-Summary $summary $logFile
