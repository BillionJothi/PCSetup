<#
.SYNOPSIS
  Main entry script for PC setup automation.
#>

$ErrorActionPreference = "Stop"

# Import utilities
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptRoot\utils.ps1"

# Load settings
$settings = Load-Settings "..\configs\settings.json"

# Create folders if not exist
Ensure-Folders $settings

# Backup current packages.json
Backup-JSON $settings.folders.packages $settings

# Prompt user for action
Write-Host "Choose an action: (I)nstall, (U)pdate, (C)leanup, or (Q)uit"
$choice = Read-Host "Enter your choice"

switch ($choice.ToLower()) {
    "i" {
        $logFile = Start-Log "install" $settings
        Write-Log "=== Starting install process ===" $logFile
        & "$scriptRoot\install.ps1" $settings $logFile
    }
    "u" {
        $logFile = Start-Log "update" $settings
        Write-Log "=== Starting update process ===" $logFile
        & "$scriptRoot\update.ps1" $settings $logFile
    }
    "c" {
        $logFile = Start-Log "cleanup" $settings
        Write-Log "=== Starting cleanup process ===" $logFile
        & "$scriptRoot\cleanup.ps1" $settings $logFile
    }
    "q" {
        Write-Host "Goodbye!"
        exit
    }
    Default {
        Write-Host "❌ Invalid option. Please choose I, U, or C."
    }
}

Write-Log "✅ Completed selected process." $logFile
Show-Summary $global:summary $logFile
