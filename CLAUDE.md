@AGENTS.md

# CRM
The Flutter + Django CRM lives in `crm/` (merged from the old washnlaundrycrm repo). See `crm/CLAUDE.md`.

# Customer site
`customer.washnlaundry.com` serves the **same Flutter build as the CRM** (Cloudflare Pages project
`washnlaundrycrm`, custom domains `app.` and `customer.`). Customers sign in with Google or
email + password and the backend role puts them on the customer-only `/my/*` screens; staff and
the owner get the CRM. Demo Mode is hidden on the `customer.*` host. See `crm/CLAUDE.md` ("Roles and
auth"). The old Next.js portal (`customer-web/`, Worker `washnlaundry-customer`) was removed on
2026-10-07. The marketing site's "Log in" links point at `customer.washnlaundry.com/?fresh=1` (same build, role decides the view).
Needs `GOOGLE_CLIENT_ID` (Render + repo var) for Google sign-in, and `https://customer.washnlaundry.com`
among the OAuth client's authorized JavaScript origins.

# Marketing site deployment (Cloudflare Worker)
The marketing website lives at the repository root (`src/app/page.tsx`) and is deployed to Cloudflare Worker `washnlaundry-web` via `@opennextjs/cloudflare`.

**IMPORTANT: Must be built from Linux/WSL (NOT directly on Windows host)**
Building `@opennextjs/cloudflare` on native Windows leads to broken worker bundles (`dynamic require of middleware-manifest.json`).

Deployment steps using WSL:
```bash
# 1. In WSL (Ubuntu), prepare a clean Linux workspace or run from native Linux filesystem:
mkdir -p /tmp/washnlaundry && cd /tmp/washnlaundry
git clone /mnt/c/Users/abhi3/Documents/work/sipu/washnlaundry .
pnpm install

# 2. Deploy to Cloudflare:
export CLOUDFLARE_API_TOKEN="<token>"
pnpm cf:deploy

# 3. Clean up temporary build folder:
cd ~ && rm -rf /tmp/washnlaundry
```

