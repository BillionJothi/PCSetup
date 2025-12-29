# ==============================================
# install.ps1 - App Installation with Elevation Handling and Per-PC Packages
# ==============================================

. "$PSScriptRoot\utils.ps1"

$logFile = Start-Log "install"
Write-Log "=== Starting installation ===" $logFile

# Load global packages
$globalPackages = @()
if (Test-Path $Settings.folders.packages) {
    $globalPackages = Get-Content $Settings.folders.packages | ConvertFrom-Json
}

# Detect PC name
$pcName = $env:COMPUTERNAME
$pcJsonPath = Join-Path (Split-Path $Settings.folders.packages -Parent) "packages_$pcName.json"

# Load per-PC packages
$pcPackages = @()
if (Test-Path $pcJsonPath) {
    $pcPackages = Get-Content $pcJsonPath | ConvertFrom-Json
    Write-Log "✅ Loaded per-PC packages for $pcName" $logFile
} else {
    Write-Log "⚠️ No per-PC packages found for $pcName" $logFile
}

# Merge packages
$packages = @{
    "packages" = @($globalPackages.packages + $pcPackages.packages)
}

# List of packages requiring elevation
$requiresElevation = @("amd-software-adrenalin-edition")

# Install each package
foreach ($pkg in $packages.packages) {
    try {
        switch ($pkg.ManagerName.ToLower()) {

            "winget" {
                if (Check-Command "winget") {
                    Write-Log "📦 Installing $($pkg.Name) via Winget..." $logFile
                    winget install --id $pkg.Id -e --accept-source-agreements --accept-package-agreements
                } else {
                    Write-Log "⚠️ Winget not installed. Skipping $($pkg.Name)." $logFile
                }
            }

            "choco" {
                if (Check-Command "choco") {

                    if ($requiresElevation -contains $pkg.Id.ToLower()) {
                        Write-Log "⚡ $($pkg.Name) requires elevation. Launching elevated..." $logFile
                        Start-Process "choco" -ArgumentList "install $($pkg.Id) -y --confirm" -Verb RunAs -Wait
                    } else {
                        Write-Log "📦 Installing $($pkg.Name) via Chocolatey..." $logFile
                        choco install $($pkg.Id) -y --confirm
                    }

                } else {
                    Write-Log "⚠️ Chocolatey not installed. Skipping $($pkg.Name)." $logFile
                }
            }

            "scoop" {
                if (Check-Command "scoop") {
                    Write-Log "📦 Installing $($pkg.Name) via Scoop..." $logFile
                    scoop install $pkg.Id
                } else {
                    Write-Log "⚠️ Scoop not installed. Skipping $($pkg.Name)." $logFile
                }
            }

            default {
                Write-Log "⚠️ Unknown package manager '$($pkg.ManagerName)' for $($pkg.Name). Skipping." $logFile
            }
        }

    } catch {
        Write-Log "❌ Error installing $($pkg.Name): $($_.Exception.Message)" $logFile
    }
}

Write-Log "✅ Installation complete." $logFile
Show-Summary @{ "winget" = "Done"; "choco" = "Done"; "scoop" = "Done" } $logFile
