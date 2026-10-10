-- Cloudflare D1 Daily Backups Schema
CREATE TABLE IF NOT EXISTS backups (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    backup_date TEXT NOT NULL,
    created_at TEXT NOT NULL,
    trigger_source TEXT NOT NULL,
    section_count INTEGER DEFAULT 0,
    payload_size INTEGER NOT NULL,
    backup_data TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_backups_date ON backups(backup_date);
CREATE INDEX IF NOT EXISTS idx_backups_created_at ON backups(created_at);
