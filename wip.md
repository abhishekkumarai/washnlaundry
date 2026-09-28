# WIP — Cloudflare migration (KAN-109), status as of 2026-09-29 (evening update)

Epic: **KAN-109 — End-to-End Migration to Cloudflare**. This file supersedes the
previous WIP notes below it, which covered an already-shipped, unrelated batch
of work (Staff/Payroll/Expenses/Credits, all merged and in Jira review already).

Jira status as of this update: KAN-109 (parent) To Do, KAN-110 Backlog,
KAN-111 **Done**, KAN-112 In Progress (both task-4 clients now built, see
below — ready to move to In Review), KAN-113 In Review, KAN-114 To Do.
KAN-109 itself hasn't been rolled up to reflect that 3 of its 4 children are
done or in review — worth doing next time Jira is touched for this epic.

## Done and verified

**KAN-111 — Next.js marketing site → Cloudflare Workers** — **Done**
- Live at https://washnlaundry-marketing.abhishekkumarai.workers.dev
  (`*.workers.dev` — deliberately not `washnlaundry.com`, no dependency on
  KAN-114)
- Pushed to origin today (`28f8fea`, `2322395`, `c634a33` on the sibling
  `washnlaundry/` repo's `main`) — previously local-only, pending go-ahead;
  go-ahead given and pushed this session.
- Orphaned `/services`, `/book`, `/track` routes removed; Next.js upgraded to
  16.3.6 (from 15.5.26, that downgrade turned out unnecessary — see prior
  entry below for the full Windows/WSL build story).

**KAN-110 — Flutter CRM → Cloudflare Pages** — moved to Jira **Backlog**
- Live at https://washnlaundrycrm.pages.dev (project `washnlaundrycrm`)
- `washnlaundrycrm/_headers`, `washnlaundrycrm/_redirects`, `scripts/deploy_cloudflare_pages.js`
- **Production pre-push hook switched from Vercel to Cloudflare Pages today**
  (`.githooks/pre-push`, `scripts/setup_hooks.js`, and the installed
  `.git/hooks/pre-push` all updated in commit `4707956`). Previously flagged
  as "a deliberate production-cutover decision, not done implicitly" — the
  go-ahead was given this session. Every future `git push` to `main` now
  builds and deploys to `washnlaundrycrm.pages.dev` instead of Vercel.
  Requires `CLOUDFLARE_API_TOKEN` in the environment — already set as a
  persistent Windows user/machine env var, confirmed working across two live
  pushes today (`7df98ba8...` manual deploy, then `82de02f8...` via the hook).
- Still open: `app.washnlaundry.com` custom domain not attached — needs
  KAN-114's zone first.

**KAN-112 — RAG chat engine** — In Progress (backend, Flutter client, and
WhatsApp bridge all done this session — ready to move to In Review)
- Worker `washnlaundry-rag`, live at https://washnlaundry-rag.abhishekkumarai.workers.dev
- `cloudflare/rag-engine/` — KV (`washnlaundry-knowledge-base`) + Vectorize (`washnlaundry-kb`)
  instead of R2 (see Blocked, below)
- Verified end-to-end against live backend: retrieval with citations, and
  tool-calling (`lookup_order`, `lookup_customer_dues`) confirmed against
  real customer/order data (Rohan Verma, ₹350 due, orders WASH-00002/00015)
- **Flutter Web chat UI — built and live today** (commit `65bdff8`):
  - `RagChatLauncher` (`lib/widgets/rag_chat_panel.dart`) — a floating chat
    button + panel, mounted once in `AppShell` so it shows on every
    authenticated screen for free (same pattern as `AppDrawer`).
  - `ApiService.streamRagChat()` — SSE client tolerant of both Workers AI
    streaming shapes (`{"response": "..."}` and the OpenAI-style
    `{"choices":[{"delta":{"content":"..."}}]}`).
  - The Worker's `RAG_API_KEY` never reaches the public web bundle: Django
    proxies `POST /api/rag/chat/` (`backend/api/services/rag_service.py`,
    `StreamingHttpResponse` passthrough) and attaches the key server-side —
    same shape as the existing `WhatsAppService` bridge proxy. Wired into
    `docker-compose.yml` and `.env.example` for local dev.
  - `RAG_API_KEY` was **rotated** this session (the original value wasn't
    saved anywhere retrievable — `wrangler secret list` only returns names,
    never values). New key set on the Worker (`wrangler secret put`) and on
    Render (`laundrybill-backend` env vars) manually, since writing secrets
    via CLI is blocked for the assistant by the auto-mode classifier and the
    Render CLI (v2.24.0) has no env-var management command at all. Verified
    working end-to-end against both the Worker directly and through the
    Render proxy.
  - All 228 Django tests and the full Flutter test suite pass with these
    changes.
- **WhatsApp bridge auto-reply — built today** (`whatsapp-bridge/`):
  - `src/autoReply.js` — pure, unit-tested functions: `extractText` (reads
    `conversation`/`extendedTextMessage`, unwraps one level of
    `ephemeralMessage` for disappearing-message chats), `shouldAutoReply`
    (excludes our own outbound messages, `@g.us` groups, and
    `status@broadcast`), `extractSseToken`/`collectSseText` (same two-shape
    SSE tolerance as the Flutter client, but collects the full reply before
    sending — WhatsApp has no streaming-message concept), and
    `handleIncomingMessage`, the orchestrator wired into the socket.
  - `src/socket.js` — added a `messages.upsert` listener (filtered to
    `type === 'notify'` only, so Baileys' history-backfill on reconnect
    can't trigger a reply to a days-old message) behind a settable
    `setIncomingMessageHandler` hook, keeping the module pure transport —
    no RAG/HTTP concerns leak into it.
  - `src/index.js` — wires the handler to the Django RAG proxy
    (`BACKEND_URL`, defaulting to `http://backend:8000` in Docker) and
    `sendTextMessage`.
  - **Deliberately opt-in and off by default**: `AUTO_REPLY_ENABLED`
    (`WHATSAPP_AUTO_REPLY` in `.env`/`docker-compose.yml`) must be set to
    `true` before any real customer gets an AI reply on the live,
    already-linked WhatsApp session. This was flagged going in as a genuine
    production behavior change, not a contained addition like the Flutter
    piece — the default keeps that decision explicit and separate from
    shipping the code.
  - 15/15 new + existing `whatsapp-bridge` tests pass
    (`node --test test/*.test.js`).
  - **Not yet flipped on** — `WHATSAPP_AUTO_REPLY` stays `false` until it's
    deliberately turned on, same reasoning as above.

**KAN-113 — Edge reverse proxy** — In Review (unchanged)
- Worker `washnlaundry-api-proxy`, live at https://washnlaundry-api-proxy.abhishekkumarai.workers.dev
- `cloudflare/api-proxy/` — proxies `/api/*` to the Render backend
- Verified against live data (`/api/dashboard/stats/` returns real numbers through the proxy)

## Pending

- **KAN-112 — turn on `WHATSAPP_AUTO_REPLY`** — code is done and tested but
  the feature is off by default (see above). Flipping it on is a deliberate,
  separate decision — real customers start getting AI replies the moment
  it's set to `true`. Verify the RAG backend's answers on a few real
  questions first (rates, policies, order lookups) before enabling on the
  live session.
- **KAN-110** — `app.washnlaundry.com` custom domain not attached (needs
  KAN-114's zone first). Pre-push → Cloudflare cutover is done (see above).
- **KAN-113** — Worker isn't attached to a route on the real domain yet, only
  reachable via `*.workers.dev`. WAF / Bot Fight Mode / Rate Limiting / Turnstile
  (all zone-level) not configured — needs the zone.
- **KAN-111** — real `washnlaundry.com` domain not attached (Cloudflare Pages
  custom domain vs. Worker vs. route still an open choice) — gated on KAN-114,
  same as KAN-110/113.
- **KAN-114 — DNS cutover** — not started at all. Blocks the "real domain"
  half of KAN-110/111/113 above. Genuinely the riskiest step (live business
  email via MX records) — needs to be walked through live, with the TTL
  reduction and rollback CNAME the ticket itself specifies, not automated.
- **Jira hygiene** — KAN-109 (parent epic) status hasn't been rolled up to
  reflect KAN-111 Done / KAN-110 Backlog / KAN-112 in progress with real
  client work landed. Worth a pass next time this epic is touched.

## Blocked

- **R2** (originally specified for KAN-112's knowledge base) is blocked: the
  Cloudflare account has no payment method on file, and R2 requires one-time
  dashboard enablement even on the free tier. Routed around it by using
  Workers KV instead — this is a permanent design decision, not a stopgap,
  since KV works fine for the small policy/rate-card text involved.
- **KAN-114 zone creation** — adding the `washnlaundry.com` zone to Cloudflare
  was flagged by the permission classifier as a DNS/domain change and needs
  explicit sign-off before it's created (it's reversible — doesn't touch live
  DNS until nameservers are repointed at Namecheap — but still gated).
- **Secret-store writes** (new today) — the assistant's auto-mode classifier
  blocks writing secrets directly (e.g. `wrangler secret put` was denied for
  the `RAG_API_KEY` rotation above). Worked around by generating the value
  locally and having the user apply it manually on the Worker and on Render;
  this will recur for any future secret rotation unless the user does it
  themselves or grants a specific permission rule.
