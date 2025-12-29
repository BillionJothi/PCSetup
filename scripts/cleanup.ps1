# ==============================================
# cleanup.ps1 - Manual Cleanup Script
# ==============================================

. "$PSScriptRoot\utils.ps1"
Run-RetentionCleanup
Show-Toast "Cleanup completed for logs and backups."
