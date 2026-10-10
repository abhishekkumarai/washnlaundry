# Cloudflare D1 Daily Backup Worker

Fully automated, zero-cost daily backup solution powered by **Cloudflare Worker**, **Cloudflare Cron Triggers**, and **Cloudflare D1 SQL Database** (5 GB Free tier, no credit card required).

---

## Live Deployment Status

- **Worker URL**: `https://washnlaundry-daily-d1-backup.abhishekkumarai.workers.dev`
- **Cron Trigger**: `0 2 * * *` (Runs automatically every day at 02:00 AM UTC)
- **Database**: `washnlaundry-backups-db` (D1 ID: `ed9a8fb7-5120-42bf-8449-dec0340395a0`)
- **Cost**: **$0.00** (Free tier 5GB storage, 5M reads/day, 100k writes/day)

---

## Live Endpoints

| Endpoint | Method | Description |
| :--- | :--- | :--- |
| `/health` | `GET` | Health check, D1 binding status, and cron schedule |
| `/list` | `GET` | Lists recent backups with ID, date, section count, and payload size |
| `/trigger` | `GET` | Manually triggers an on-demand backup snapshot |
| `/backup/:id` | `GET` | Downloads the full JSON backup payload for a given backup ID |

---

## How It Works

1. **Daily Cron**: At `02:00 UTC`, Cloudflare triggers the Worker's `scheduled()` handler.
2. **Snapshot Ingestion**: The Worker queries your backend (`orders`, `customers`, `staff`, `expenses`, `credits`, `categories`, `items`).
3. **Storage in D1**: Creates an indexed backup record in SQLite table `backups` with metadata and full JSON payload.
4. **Auto-Pruning Retention**: Automatically deletes snapshots older than `RETENTION_DAYS` (default 30 days) to keep storage clean.

---

## Testing / Manual Run

```bash
# Health check
curl -A "Mozilla/5.0" "https://washnlaundry-daily-d1-backup.abhishekkumarai.workers.dev/health"

# List backups
curl -A "Mozilla/5.0" "https://washnlaundry-daily-d1-backup.abhishekkumarai.workers.dev/list"

# Trigger a manual snapshot
curl -A "Mozilla/5.0" "https://washnlaundry-daily-d1-backup.abhishekkumarai.workers.dev/trigger"

# Download backup #1
curl -A "Mozilla/5.0" -O "https://washnlaundry-daily-d1-backup.abhishekkumarai.workers.dev/backup/1"
```
