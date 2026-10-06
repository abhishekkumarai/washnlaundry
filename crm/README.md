# washnlaundry CRM

Laundry / dry-cleaning shop CRM. Flutter Web frontend, Django REST backend, deployed on Cloudflare.

| Path | |
|---|---|
| `washnlaundrycrm/` | Flutter Web app → Cloudflare Pages |
| `backend/` | Django + DRF API (Render + Neon Postgres) |
| `cloudflare/api-proxy/`, `cloudflare/rag-engine/` | Cloudflare Workers |
| `scripts/deploy_cloudflare_pages.js` | Pages uploader |

Deploy the CRM:

```bash
cd washnlaundrycrm
flutter build web --release --dart-define=API_BASE_URL=https://laundrybill-backend.onrender.com/api
CLOUDFLARE_API_TOKEN=... node ../scripts/deploy_cloudflare_pages.js
```

Deploy a Worker: `cd cloudflare/<worker> && npx wrangler deploy`.

See `CLAUDE.md` for architecture and conventions.
