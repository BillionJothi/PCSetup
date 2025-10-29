param($settings, $logFile)

. "$PSScriptRoot\utils.ps1"

$packages = Get-Content $settings.folders.packages | ConvertFrom-Json

foreach ($pkg in $packages) {
    $name = $pkg.name
    $source = $pkg.source

    Write-Log "📦 Checking installation for $name ($source)" $logFile

    switch ($source) {
        "winget" {
            if (Check-Command "winget") {
                $installed = winget list | Select-String -Pattern $name
                if ($installed) {
                    Write-Host "$name already installed. Reinstall? (y/n)"
                    if ((Read-Host) -eq "y") { winget install --id $pkg.id }
                } else {
                    Write-Host "Install $name? (y/n)"
                    if ((Read-Host) -eq "y") { winget install --id $pkg.id }
                }
            } else {
                Write-Log "❌ winget not available." $logFile
            }
        }
        "scoop" {
            if (Check-Command "scoop") {
                if (scoop list $name -ErrorAction SilentlyContinue) {
                    Write-Host "$name already installed. Reinstall? (y/n)"
                    if ((Read-Host) -eq "y") { scoop install $name -g }
                } else {
                    Write-Host "Install $name? (y/n)"
                    if ((Read-Host) -eq "y") { scoop install $name -g }
                }
            } else {
                Write-Log "❌ scoop not available." $logFile
            }
        }
        "choco" {
            if (Check-Command "choco") {
                if (choco list --local-only | Select-String -Pattern $name) {
                    Write-Host "$name already installed. Reinstall? (y/n)"
                    if ((Read-Host) -eq "y") { choco install $name -y }
                } else {
                    Write-Host "Install $name? (y/n)"
                    if ((Read-Host) -eq "y") { choco install $name -y }
                }
            } else {
                Write-Log "❌ Chocolatey not available." $logFile
            }
        }
    }
}
