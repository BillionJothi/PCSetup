# ==============================================
# install.ps1 - App Installation (with per-PC support)
# ==============================================

. "$PSScriptRoot\utils.ps1"

# Start logging
$logFile = Start-Log "install"
Write-Log "=== Starting installation ===" $logFile

# Load main packages.json
if (-not (Test-Path $Settings.folders.packages)) {
    Write-Log "❌ Main package file not found: $($Settings.folders.packages)" $logFile
    exit
}

$packages = Get-Content $Settings.folders.packages | ConvertFrom-Json

# Detect PC name
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
$packagesToInstall = $packages.packages | Sort-Object Id -Unique

# Install packages
foreach ($pkg in $packagesToInstall) {
    try {
        switch ($pkg.ManagerName) {
            "Winget" {
                if (Check-Command "winget") {
                    Write-Log "📦 Installing $($pkg.Name) via winget..." $logFile
                    winget install --id $pkg.Id -e --accept-source-agreements --accept-package-agreements
                } else {
                    Write-Log "⚠️ Winget not found, skipping $($pkg.Name)" $logFile
                }
            }
            "Chocolatey" {
                if (Check-Command "choco") {
                    Write-Log "📦 Installing $($pkg.Name) via choco..." $logFile
                    choco install $pkg.Id -y
                } else {
                    Write-Log "⚠️ Chocolatey not found, skipping $($pkg.Name)" $logFile
                }
            }
            "Scoop" {
                if (Check-Command "scoop") {
                    Write-Log "📦 Installing $($pkg.Name) via scoop..." $logFile
                    scoop install $pkg.Id
                } else {
                    Write-Log "⚠️ Scoop not found, skipping $($pkg.Name)" $logFile
                }
            }
            default {
                Write-Log "⚠️ Unknown manager $($pkg.ManagerName) for $($pkg.Name), skipping..." $logFile
            }
        }
    } catch {
        Write-Log "❌ Error installing $($pkg.Name): $($_.Exception.Message)" $logFile
    }
}

Write-Log "✅ Installation complete." $logFile
Show-Summary @{ "winget" = "Done"; "choco" = "Done"; "scoop" = "Done" } $logFile
