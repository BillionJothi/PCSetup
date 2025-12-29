# ==============================================
# windows-features.ps1 - Enable Windows Features
# ==============================================

. "$PSScriptRoot\utils.ps1"

# Start logging
$logFile = Start-Log "windows-features"
Write-Log "=== Starting Windows features process ===" $logFile

# Load features JSON (common + per-PC)
$commonFeaturesFile = Join-Path $PSScriptRoot "..\configs\windows-features.json"
$pcName = $env:COMPUTERNAME
$pcFeaturesFile = Join-Path $PSScriptRoot "..\configs\windows-features_$pcName.json"

$features = @()

if (Test-Path $commonFeaturesFile) {
    $features += Get-Content $commonFeaturesFile | ConvertFrom-Json
} else {
    Write-Log "⚠️ Common Windows features file not found: $commonFeaturesFile" $logFile
}

if (Test-Path $pcFeaturesFile) {
    $features += Get-Content $pcFeaturesFile | ConvertFrom-Json
} else {
    Write-Log "ℹ️ No per-PC features file found for $pcName: $pcFeaturesFile" $logFile
}

# Process each feature
foreach ($feature in $features) {
    $name = $feature.Name
    $desc = if ($feature.Description) { $feature.Description } else { $name }

    try {
        Write-Log "⚙️ Enabling $desc via PowerShell..." $logFile

        # Attempt with PowerShell first
        Enable-WindowsOptionalFeature -Online -FeatureName $name -All -NoRestart -ErrorAction Stop
        Write-Log "✅ $desc enabled successfully (PowerShell)." $logFile

    } catch {
        Write-Log "⚠️ PowerShell failed for $desc. Falling back to DISM..." $logFile

        # Use DISM as fallback
        $dismArgs = "/Online /Enable-Feature /FeatureName:$name /All /NoRestart"
        $proc = Start-Process DISM.exe -ArgumentList $dismArgs -Wait -PassThru -NoNewWindow

        if ($proc.ExitCode -eq 0) {
            Write-Log "✅ $desc enabled successfully (DISM)." $logFile
        } else {
            Write-Log "❌ DISM failed enabling $desc. Exit code: $($proc.ExitCode)" $logFile
        }
    }
}

Write-Log "✅ Completed Windows features process." $logFile
Show-Summary @{ "windows-features" = "Done" } $logFile
