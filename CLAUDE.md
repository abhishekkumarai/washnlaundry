@AGENTS.md

# CRM
The Flutter + Django CRM lives in `crm/` (merged from the old washnlaundrycrm repo). See `crm/CLAUDE.md`.

# Customer portal
`customer-web/` is a separate Next 16 + OpenNext Worker (`washnlaundry-customer`) served at
`customer.washnlaundry.com` (custom domain in its `wrangler.jsonc`). Customers sign in with
Google (ID token verified by Django, `crm/backend/api/customer_views.py`, matched by email;
first sign-in creates a Customer). The marketing site's "Log in" links go straight to customer.washnlaundry.com (the old
`/login` handoff page was removed). The portal's `/api/portal/*` route is an allow-listed proxy to
Render; never widen it, the rest of the backend API is unauthenticated.
Needs `GOOGLE_CLIENT_ID` on Render, repo var `GOOGLE_CLIENT_ID` for both site builds, and both
`https://washnlaundry.com` and `https://customer.washnlaundry.com` as authorized JS origins.
