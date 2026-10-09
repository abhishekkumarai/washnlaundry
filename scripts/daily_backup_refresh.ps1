# Daily Database Backup and Refresh Automation (PowerShell)
# Usage:
#   .\scripts\daily_backup_refresh.ps1 -Mode backup
#   .\scripts\daily_backup_refresh.ps1 -Mode refresh
#   .\scripts\daily_backup_refresh.ps1 -Mode all

param (
    [ValidateSet("backup", "refresh", "all")]
    [string]$Mode = "all"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$BackendDir = Join-Path $ProjectRoot "crm\backend"

Write-Host "======================================================"
Write-Host "WashNLaundry CRM - Database Automation Workflow ($Mode)"
Write-Host "======================================================"

Push-Location $BackendDir

try {
    if ($Mode -eq "backup" -or $Mode -eq "all") {
        Write-Host "[1/2] Initiating database backup..." -ForegroundColor Cyan
        python manage.py backup_local_db --retention-days 7
        if ($LASTEXITCODE -ne 0) {
            throw "Database backup failed with exit code $LASTEXITCODE"
        }
        Write-Host "Backup completed successfully." -ForegroundColor Green
    }

    if ($Mode -eq "refresh" -or $Mode -eq "all") {
        Write-Host "[2/2] Initiating local database refresh from latest backup..." -ForegroundColor Cyan
        python manage.py refresh_local_db
        if ($LASTEXITCODE -ne 0) {
            throw "Database refresh failed with exit code $LASTEXITCODE"
        }
        Write-Host "Refresh completed successfully." -ForegroundColor Green
    }
}
finally {
    Pop-Location
}

Write-Host "Daily database automation finished." -ForegroundColor Green
