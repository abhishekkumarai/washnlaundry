@AGENTS.md

# CRM
The Flutter + Django CRM lives in `crm/` (merged from the old washnlaundrycrm repo). See `crm/CLAUDE.md`.

# Customer site
`customer.washnlaundry.com` serves the **same Flutter build as the CRM** (Cloudflare Pages project
`washnlaundrycrm`, custom domains `app.` and `customer.`). Customers sign in with Google or
email + password and the backend role puts them on the customer-only `/my/*` screens; staff and
the owner get the CRM. Demo Mode is hidden on the `customer.*` host. See `crm/CLAUDE.md` ("Roles and
auth"). The old Next.js portal (`customer-web/`, Worker `washnlaundry-customer`) was removed on
2026-10-07. The marketing site's "Log in" links point at app.washnlaundry.com (same build, role decides the view).
Needs `GOOGLE_CLIENT_ID` (Render + repo var) for Google sign-in, and `https://customer.washnlaundry.com`
among the OAuth client's authorized JavaScript origins.
