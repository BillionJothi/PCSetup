# ==============================================
# setup.ps1 - Entry Script
# ==============================================

# Import Utilities
. "$PSScriptRoot\utils.ps1"

# Backup package list
Backup-JSON (Join-Path $PSScriptRoot "..\configs\packages.json")

# Choose mode
$mode = Read-Host "Choose action: (I)nstall or (U)pdate"
switch ($mode.ToUpper()) {
    "I" {
        & "$PSScriptRoot\install.ps1"
    }
    "U" {
        & "$PSScriptRoot\update.ps1"
    }
    default {
        Write-Host "❌ Invalid option. Exiting."
    }
}

# Run cleanup
Run-RetentionCleanup
