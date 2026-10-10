export interface Env {
  BACKUP_DB: D1Database;
  BACKUP_SOURCE_URL?: string;
  API_ROOT_URL?: string;
  BACKUP_AUTH_TOKEN?: string;
  RETENTION_DAYS?: string;
}

export interface BackupResult {
  success: boolean;
  backupId?: number;
  backupDate: string;
  sizeBytes?: number;
  sectionCount?: number;
  prunedCount?: number;
  timestamp: string;
  triggerSource: string;
  error?: string;
}

export default {
  /**
   * Cloudflare Worker Scheduled Cron Trigger Handler
   * Triggers daily as configured in wrangler.jsonc ('0 2 * * *' = 02:00 AM UTC)
   */
  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext): Promise<void> {
    console.log(`[Cron Trigger] Initiating daily D1 database backup at ${new Date(event.scheduledTime).toISOString()}`);
    ctx.waitUntil(performBackup(env, 'cron'));
  },

  /**
   * Cloudflare Worker HTTP Fetch Handler
   * Provides health checks, manual triggering, and querying backup logs.
   */
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    // 1. Health check
    if (url.pathname === '/' || url.pathname === '/health') {
      return new Response(
        JSON.stringify({
          status: 'healthy',
          service: 'washnlaundry-daily-d1-backup',
          storage: 'Cloudflare D1 (5GB Free tier, Zero payment lock)',
          cronSchedule: '0 2 * * * (daily 02:00 UTC)',
          hasDatabaseBinding: Boolean(env.BACKUP_DB),
          timestamp: new Date().toISOString(),
        }, null, 2),
        {
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    // 2. Manual on-demand backup trigger
    if (url.pathname === '/trigger' || url.pathname === '/backup') {
      if (env.BACKUP_AUTH_TOKEN) {
        const authHeader = request.headers.get('Authorization');
        if (authHeader !== `Bearer ${env.BACKUP_AUTH_TOKEN}`) {
          return new Response(JSON.stringify({ error: 'Unauthorized' }), {
            status: 401,
            headers: { 'Content-Type': 'application/json' },
          });
        }
      }

      const result = await performBackup(env, 'manual-http');
      return new Response(JSON.stringify(result, null, 2), {
        status: result.success ? 200 : 500,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // 3. List recent backups in D1
    if (url.pathname === '/list') {
      if (env.BACKUP_AUTH_TOKEN) {
        const authHeader = request.headers.get('Authorization');
        if (authHeader !== `Bearer ${env.BACKUP_AUTH_TOKEN}`) {
          return new Response(JSON.stringify({ error: 'Unauthorized' }), {
            status: 401,
            headers: { 'Content-Type': 'application/json' },
          });
        }
      }

      try {
        const query = await env.BACKUP_DB.prepare(
          `SELECT id, backup_date, created_at, trigger_source, section_count, payload_size 
           FROM backups 
           ORDER BY id DESC 
           LIMIT 30`
        ).all();

        return new Response(
          JSON.stringify({ count: query.results.length, backups: query.results }, null, 2),
          { headers: { 'Content-Type': 'application/json' } }
        );
      } catch (err: any) {
        return new Response(
          JSON.stringify({ error: err.message }),
          { status: 500, headers: { 'Content-Type': 'application/json' } }
        );
      }
    }

    // 4. Download / inspect a specific backup by ID
    if (url.pathname.startsWith('/backup/')) {
      if (env.BACKUP_AUTH_TOKEN) {
        const authHeader = request.headers.get('Authorization');
        if (authHeader !== `Bearer ${env.BACKUP_AUTH_TOKEN}`) {
          return new Response(JSON.stringify({ error: 'Unauthorized' }), {
            status: 401,
            headers: { 'Content-Type': 'application/json' },
          });
        }
      }

      const id = url.pathname.replace('/backup/', '').trim();
      try {
        const row = await env.BACKUP_DB.prepare(
          `SELECT id, backup_date, created_at, trigger_source, section_count, payload_size, backup_data 
           FROM backups 
           WHERE id = ?`
        ).bind(id).first();

        if (!row) {
          return new Response(JSON.stringify({ error: 'Backup not found' }), {
            status: 404,
            headers: { 'Content-Type': 'application/json' },
          });
        }

        return new Response(String(row.backup_data), {
          headers: {
            'Content-Type': 'application/json',
            'Content-Disposition': `attachment; filename="backup_${row.backup_date}_id${row.id}.json"`,
          },
        });
      } catch (err: any) {
        return new Response(JSON.stringify({ error: err.message }), {
          status: 500,
          headers: { 'Content-Type': 'application/json' },
        });
      }
    }

    return new Response(
      JSON.stringify({
        error: 'Not Found',
        availableEndpoints: ['/health', '/trigger', '/list', '/backup/:id'],
      }),
      { status: 404, headers: { 'Content-Type': 'application/json' } }
    );
  },
};

/**
 * Backup Pipeline:
 * 1. Queries backend backup source
 * 2. Stores the snapshot record inside Cloudflare D1
 * 3. Prunes backups that exceed the configured retention days
 */
export async function performBackup(env: Env, triggerSource: string = 'cron'): Promise<BackupResult> {
  const now = new Date();
  const backupDate = now.toISOString().slice(0, 10); // YYYY-MM-DD
  const timestamp = now.toISOString();

  try {
    if (!env.BACKUP_DB) {
      throw new Error('BACKUP_DB D1 binding is not configured.');
    }

    if (!env.BACKUP_SOURCE_URL) {
      throw new Error('BACKUP_SOURCE_URL environment variable is not defined.');
    }

    console.log(`[Backup] Fetching backup from ${env.BACKUP_SOURCE_URL}...`);

    const reqHeaders: Record<string, string> = {
      'User-Agent': 'Cloudflare-Worker-Daily-D1-Backup/1.0',
      'Accept': 'application/json',
    };

    if (env.BACKUP_AUTH_TOKEN) {
      reqHeaders['Authorization'] = `Bearer ${env.BACKUP_AUTH_TOKEN}`;
    }

    let rawJson: string;
    let sectionCount = 0;

    // Try primary export endpoint
    const primaryResp = await fetch(env.BACKUP_SOURCE_URL, {
      method: 'GET',
      headers: reqHeaders,
    });

    if (primaryResp.ok) {
      rawJson = await primaryResp.text();
    } else {
      // Fallback: Aggregate core entities directly from live API resources
      console.log(`[Backup Fallback] /api/backup/export/ returned ${primaryResp.status}. Aggregating core resources directly...`);
      const apiRoot = env.API_ROOT_URL || 'https://washnlaundry-backend.onrender.com/api/';
      const endpoints = ['orders', 'customers', 'staff', 'expenses', 'credits', 'categories', 'items'];
      const snapshot: Record<string, any> = {
        timestamp: now.toISOString(),
        backupType: 'aggregated-api-snapshot',
        sections: {},
      };

      for (const endpoint of endpoints) {
        try {
          const res = await fetch(`${apiRoot}${endpoint}/`, {
            method: 'GET',
            headers: reqHeaders,
          });
          if (res.ok) {
            snapshot.sections[endpoint] = await res.json();
          } else {
            snapshot.sections[endpoint] = { error: `HTTP ${res.status}` };
          }
        } catch (fetchErr: any) {
          snapshot.sections[endpoint] = { error: fetchErr.message };
        }
      }

      rawJson = JSON.stringify(snapshot);
    }

    const payloadSize = new TextEncoder().encode(rawJson).length;

    try {
      const parsed = JSON.parse(rawJson);
      if (parsed && typeof parsed.sections === 'object') {
        sectionCount = Object.keys(parsed.sections).length;
      }
    } catch {
      // not critical if parsing section count fails
    }

    console.log(`[Backup] Storing ${payloadSize} bytes to Cloudflare D1 database...`);

    // Insert snapshot into D1
    const insertResult = await env.BACKUP_DB.prepare(
      `INSERT INTO backups (backup_date, created_at, trigger_source, section_count, payload_size, backup_data)
       VALUES (?, ?, ?, ?, ?, ?)`
    ).bind(
      backupDate,
      timestamp,
      triggerSource,
      sectionCount,
      payloadSize,
      rawJson
    ).run();

    console.log(`[Backup Success] Stored daily backup to D1 (ID: ${insertResult.meta.last_row_id})`);

    // Prune backups exceeding retention days
    const retentionDays = parseInt(env.RETENTION_DAYS || '30', 10);
    const prunedCount = await pruneOldBackups(env.BACKUP_DB, retentionDays);

    return {
      success: true,
      backupId: insertResult.meta.last_row_id,
      backupDate,
      sizeBytes: payloadSize,
      sectionCount,
      prunedCount,
      timestamp,
      triggerSource,
    };
  } catch (err: any) {
    const errorMsg = err?.message || String(err);
    console.error(`[Backup Error] Failed: ${errorMsg}`);
    return {
      success: false,
      backupDate,
      timestamp,
      triggerSource,
      error: errorMsg,
    };
  }
}

/**
 * Prunes backups older than retentionDays from D1.
 */
export async function pruneOldBackups(db: D1Database, retentionDays: number): Promise<number> {
  if (retentionDays <= 0) return 0;

  try {
    const cutoffDate = new Date(Date.now() - retentionDays * 24 * 60 * 60 * 1000).toISOString();
    const result = await db.prepare(
      `DELETE FROM backups WHERE created_at < ?`
    ).bind(cutoffDate).run();

    const changes = result.meta.changes || 0;
    if (changes > 0) {
      console.log(`[Prune] Pruned ${changes} old backups from D1 older than ${cutoffDate}`);
    }
    return changes;
  } catch (err: any) {
    console.warn(`[Prune Warning] Failed to prune old backups: ${err.message}`);
    return 0;
  }
}
