# GEMINI.md — WashNLaundry Architecture & Operational Guide

This document captures project architecture, critical deployment notes, background services, and operational commands for Gemini Agent sessions.

---

## 1. Daily Database & CRM Backup Automation (Cloudflare D1 Worker)

A fully automated, zero-cost backup system that periodically archives CRM and database snapshots to Cloudflare's serverless SQLite database (**Cloudflare D1**).

### Deployment & Infrastructure

- **Worker Directory**: `cloudflare-backup-worker/`
- **Worker Name**: `washnlaundry-daily-d1-backup`
- **Worker URL**: `https://washnlaundry-daily-d1-backup.abhishekkumarai.workers.dev`
- **Schedule**: Cron trigger `0 2 * * *` (Runs daily at 02:00 AM UTC)
- **Database**: Cloudflare D1 `washnlaundry-backups-db`
- **Database ID**: `ed9a8fb7-5120-42bf-8449-dec0340395a0`
- **Cost**: **$0.00** (5 GB Free tier storage on Cloudflare D1 with zero payment gateway / credit card requirements)
- **Retention**: Automatically prunes historical backups older than 30 days (`RETENTION_DAYS = 30`).

### Endpoints

| Endpoint | Method | Purpose |
|---|---|---|
| `/health` | `GET` | Health check, D1 database binding verification, and cron status |
| `/list` | `GET` | Lists recent backups with ID, timestamp, section count, and payload size |
| `/trigger` | `GET` | Triggers an immediate backup snapshot on-demand |
| `/backup/:id` | `GET` | Downloads the raw JSON backup snapshot for a given backup ID |

### Manual Operations & Verification

```bash
# Health check
curl -A "Mozilla/5.0" "https://washnlaundry-daily-d1-backup.abhishekkumarai.workers.dev/health"

# List backups
curl -A "Mozilla/5.0" "https://washnlaundry-daily-d1-backup.abhishekkumarai.workers.dev/list"

# Trigger an immediate manual backup
curl -A "Mozilla/5.0" "https://washnlaundry-daily-d1-backup.abhishekkumarai.workers.dev/trigger"

# Download a specific backup snapshot (e.g. backup #1)
curl -A "Mozilla/5.0" -O "https://washnlaundry-daily-d1-backup.abhishekkumarai.workers.dev/backup/1"
```

### Local Django Backup Command

The backend also includes local backup management commands:
```bash
# Create local timestamped backup (SQLite or PostgreSQL dump)
cd crm/backend
python manage.py backup_local_db --retention-days 7

# Restore from latest or specified backup
python manage.py refresh_local_db
```

---

## 2. Marketing Website (`washnlaundry-web`)

- **Root Location**: `src/app/`
- **Framework**: Next.js 16 (App Router) + Tailwind CSS v4 + React 19
- **Deployment Target**: Cloudflare Worker `washnlaundry-web` via `@opennextjs/cloudflare`
- **Deployment Platform Warning**:
  - Must be built from Linux / WSL (`/mnt/c/...` or native Linux filesystem). Native Windows builds cause worker bundle errors (`dynamic require of middleware-manifest.json`).

---

## 3. CRM & Customer Portal (`washnlaundrycrm`)

- **Root Location**: `crm/washnlaundrycrm/`
- **Frontend Stack**: Flutter Web SPA
- **Backend Stack**: Django REST Framework (`crm/backend/`) deployed on Render (`washnlaundry-backend.onrender.com`) with Neon PostgreSQL in production.
- **Hosted Hosts**:
  - `app.washnlaundry.com` (CRM for staff / shop owner)
  - `customer.washnlaundry.com` (Customer self-service portal, same build governed by user role)
- **Edge Proxies / Workers**:
  - `washnlaundry-crm-api` (`crm/cloudflare/api-proxy/`): Reverse proxy to Django API.
  - `washnlaundry-crm-rag` (`crm/cloudflare/rag-engine/`): AI Assistant, lead capture, 15-min cron.
