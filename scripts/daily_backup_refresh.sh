#!/usr/bin/env bash
# Daily Database Backup and Refresh Automation (Bash / Linux / macOS / Cron)
# Usage:
#   ./scripts/daily_backup_refresh.sh backup
#   ./scripts/daily_backup_refresh.sh refresh
#   ./scripts/daily_backup_refresh.sh all

set -euo pipefail

MODE="${1:-all}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="${SCRIPT_DIR}/../crm/backend"

echo "======================================================"
echo "WashNLaundry CRM - Database Automation Workflow (${MODE})"
echo "======================================================"

cd "${BACKEND_DIR}"

if [ "${MODE}" = "backup" ] || [ "${MODE}" = "all" ]; then
    echo "[1/2] Initiating database backup..."
    python manage.py backup_local_db --retention-days 7
    echo "Backup completed successfully."
fi

if [ "${MODE}" = "refresh" ] || [ "${MODE}" = "all" ]; then
    echo "[2/2] Initiating local database refresh from latest backup..."
    python manage.py refresh_local_db
    echo "Refresh completed successfully."
fi

echo "Daily database automation finished."
