# Multi-store isolation design: each shop with its own URL, customers and workflows

## Context

Washnlaundry CRM (Django backend + Flutter web, `crm/`) already has a tenant model: `Shop`, `ShopMembership`, a `TenantModel` base with a `TenantManager`, and `TenantMiddleware`. Two audits of the code show it is only partly isolated. This document sets the target design and the order of work for making every shop independent: its own URL, its own customers, its own workflows, its own integrations.

Design principle: **the shop is resolved once, from something the user cannot forge, and every layer below (ORM, DB, files, jobs, integrations) enforces it independently.**

## What the audits found (basis for the design)

Already good:
- `TenantManager` filters `shop=<current>`; `.save()` fills `shop`. Auto-generated DRF related fields go through it, so most cross-shop ID references return 404.
- Per-shop uniques exist for `Customer(shop, phone)`, `Order(shop, order_number)`, `GarmentCategory(shop, name)`, `ShopMembership(user, shop)`.
- Role is only granted by an active membership or staff row for the requested shop (`auth.py:286-373`).

Gaps (file refs are from the audits):
1. **URL never selects the shop.** Flutter reads the shop from saved browser storage (`active_tenant_id`, `main.dart:64-77`), not from the host or path. Server-side host resolution (`middleware.py:97-109`) breaks behind Cloudflare/Render. `custom_domain` is never looked up.
2. **Customers are not shop-bound.** `/api/customer/*` is tenantless; `customer_for_email` picks the oldest matching row across shops; sign-up returns 503 once 2+ shops exist (`customer_views.py:179-195`); phone dedup is global.
3. **Real leaks:**
   - `Meta*` serializers expose a writable `shop` (cross-shop write).
   - `.unscoped()` is a no-op under an active tenant, so the cross-shop checks at `views.py:332, 333, 999` never see other shops.
   - `bulk_create` in customer import (`views.py:498`) and catalogue import (`services_import_export.py:542`) writes `shop=NULL` rows.
   - `MetaSettings` is not a `TenantModel`; `get_settings()` returns any shop's row (`views.py:1945`) or the platform's `META_*` env tokens.
   - `NeonizeService` is a process-wide singleton: one WhatsApp device for all shops.
   - Leads, lead email and RAG use one global shop/credential (`LEAD_SHOP_SLUG`, `LEAD_EMAIL_TO`, `RESEND_API_KEY`).
4. **Order numbers are racy.** Lock released before the insert; `max(order_number)` reissues deleted numbers (`models.py:231-253, 434-443`).
5. **Workflow is hardcoded.** `OrderStatus` is a 7-value enum with 7 `*_at` columns on `Order`; `ExpenseCategory`, `PaymentMethod` and `PricingUnit` are enums; `Shop.tax_rate` is stored but never used; no notification templates.
6. **DB backstop is not working.** RLS covers 9 tables, has an `IS NULL` allow branch, is not forced for the owner role, misses newer tables, and `shop_id` is still nullable everywhere. Tests run on SQLite so RLS is untested.

## Target design

### Layer 1: Shop identity from the URL

- **URL scheme (recommended): subdomain per shop**, `<slug>.washnlaundry.com`, with `app.` staying as the owner/multi-shop console. Custom domains map through `Shop.custom_domain`. If wildcard infra is too heavy at first, ship path form `app.washnlaundry.com/s/<slug>` using the same resolver (the resolver takes a slug either way).
- **One resolver, one rule:** shop = f(host or path slug). Remove the "saved browser tenant wins" behaviour: when the URL names a shop, it overrides saved storage; storage is only used on the neutral `app.` host.
- **Client:** Flutter reads `Uri.base` at boot (before login redirect), derives the slug, and sends it as `X-Tenant-ID`. This works regardless of proxies.
- **Server:** the Cloudflare Worker sets a trusted header (`X-Shop-Host`, from the original `Host`) and Django honours it only when the request carries the Worker's shared secret. Middleware resolves in this order: trusted host header, then `custom_domain`, then subdomain, then `X-Tenant-ID`, then `?shop=`. If the URL-derived shop and `X-Tenant-ID` disagree, **reject (400)**, never pick one silently.
- **Remove silent fallbacks:** delete `fallback_shop()` and the "first membership" guess for tenant-scoped paths. No resolvable shop = 400.
- **Unknown/suspended shop host:** 404 page; do not leak whether a slug exists to unauthenticated users beyond the public store page.
- Keep `RESERVED_SHOP_SLUGS` and `EXCLUDED_SUBDOMAINS` as one shared constant.
- Browser storage is per origin, so sessions on `a.` and `b.` are naturally separate. Owners of several shops use `app.` to switch and are sent to the shop's own host.

### Layer 2: Auth and membership (people vs shop)

- **One global `User` (identity), per-shop `ShopMembership` (access).** Add role CUSTOMER to the membership as the *only* way a person belongs to a shop. Customers get a membership row bound to their `Customer` row (add `ShopMembership.customer` OneToOne/FK, nullable).
- **Tokens carry a shop.** Signed session tokens (`app.<signed>`) include `shop_id`; Google sign-in exchanges into the same token. A token minted for shop A is rejected on shop B's host. Owners switching shops re-mint via `/api/auth/switch-shop/` rather than just changing a header.
- **Customer endpoints become tenant-scoped.** Remove `/api/customer/` from `TENANTLESS_PREFIXES`. `customer_for_email`, rate card and `register_customer` all resolve from the request's shop. Sign-up creates `Customer` with the request shop explicitly (no `fallback_shop`, no 503). Phone dedup is `(shop, phone)`.
- **Same email in two shops = two independent accounts' memberships under one login.** This is the recommended identity model: one login, per-shop data. (Alternative: separate accounts per shop; costs duplicate sign-ups and complicates Google sign-in, since Google identity is one per person.)
- **Staff invites:** replace manual credential creation with an invite token (`ShopInvite`: shop, email, role, expiry, single-use). Accepting creates the membership for that shop only.
- **Origin allowlists:** `CORS`, `APP_ORIGINS`, the Worker `frame-ancestors` and email link origins move from fixed lists to a function "is this origin a known shop host" (cached lookup of subdomain/custom domain). Google OAuth origins still need manual adds per custom domain; for subdomains use a single `auth.washnlaundry.com` redirect hub, so the OAuth client needs only one origin.

### Layer 3: Data isolation (defence in depth)

1. **ORM:** `TenantManager` stays the default manager. Fix the escape hatch: `.unscoped()` must really bypass, or be replaced by `all_objects`. Add a lint/test that fails on any new `all_objects`, `unscoped()` or `bulk_create` outside an allowlist.
2. **Make `shop` NOT NULL** on every tenant table after `check_tenant_integrity` reports zero; convert `MetaSettings` to `TenantModel`.
3. **Composite FKs / same-shop checks:** child rows (`OrderItem.order`, `Order.customer`, `GarmentItem.category`, `Attendance.staff`) get a DB constraint or `clean()` that child.shop == parent.shop, so a bug cannot link across shops.
4. **Bulk paths:** a `bulk_create_for_shop(Model, rows, shop)` helper that sets `shop` and is the only allowed bulk path; fix customer import and catalogue import.
5. **Serializers:** every tenant serializer inherits `TenantModelSerializer` (read-only `shop`). Fix the four `Meta*` serializers. Add a test that walks all `TenantModel` serializers and asserts `shop` is read-only.
6. **Postgres RLS as the real backstop:**
   - A dedicated non-owner runtime role (`app_runtime`), plus `FORCE ROW LEVEL SECURITY`.
   - One restrictive policy per table: `shop_id = current_setting('app.current_tenant')::int`, **no `IS NULL` allow branch**; deny if unset.
   - Cover *all* tenant tables via a migration helper that every new `TenantModel` migration must call (test enumerates tables and asserts a policy exists).
   - Use `SET LOCAL` inside `ATOMIC_REQUESTS` (or a per-request transaction) so a pooled connection can never hold a stale tenant.
   - Cross-shop jobs (purge commands, lead retry) use a separate privileged role, explicitly.
   - Run the isolation tests against Postgres in CI, not only SQLite.
7. **Order numbers:** one transaction around "lock sequence row, increment `last_number`, insert order"; `last_number` is the source of truth, never `max()`. `get_or_create` the sequence at shop creation.
8. **Files:** storage keys already embed `shop.id`. Move to per-shop key prefix with prefix-scoped signed URLs; bind the file token to `(media_id, shop_id)`. Optionally one R2 bucket (or token) per shop for stricter isolation later.
9. **Caches/rate limits:** prefix every cache key with shop id; configure a shared cache backend (not LocMem) if running several processes.

### Layer 4: Per-shop workflows and configuration

Make everything that varies by shop **data owned by the shop**, seeded from defaults at shop creation (the existing `populate_default_services_for_shop` is the pattern):

| Concern | Today | Target |
|---|---|---|
| Order stages | `OrderStatus` enum, 7 `*_at` columns | `WorkflowStage(shop, key, label, position, is_terminal, is_cancel, notify_customer)`; `Order.status` becomes a key string; transitions stored in `OrderStatusEvent(order, stage, at, by)` (extend `OrderAuditLog`); allowed transitions in `WorkflowTransition` (optional) |
| Services & pricing | per-shop already | keep; add unique `(shop, category, name)` |
| Expense / payment categories | enums | per-shop tables like `CreditCategory` |
| Tax | unused `Shop.tax_rate` | `TaxRate(shop, name, rate, inclusive)` applied at order compute |
| Notifications | hardcoded email text | `NotificationTemplate(shop, event, channel, body)` |
| Branding | none | `Shop` logo, colours, tagline, public page toggle |
| Time slots / service areas | per-shop | keep |

- `/api/meta/` returns the *shop's* stages and categories; Flutter stops filtering on literals.
- Reports/dashboards group by stage key and read stage flags (`is_terminal`) instead of hardcoded status lists.
- Migration: seed one `WorkflowStage` set per existing shop from the current enum; backfill `OrderStatusEvent` from the existing `*_at` columns; then drop the columns in a later release.

### Layer 5: Per-shop integrations (no shared credentials)

- **WhatsApp (Neonize):** one session/DB file and one client per `shop.id`; `send_message(shop, ...)` must use that shop's client. Archiving a shop disconnects only its session.
- **Meta/Facebook:** `MetaSettings` becomes tenant-scoped; `get_settings(shop)` takes a required shop; remove the `META_*` env fallback for tenant requests. Webhooks route by the page/account id stored on the shop's settings.
- **Email:** per-shop sender identity (verified domain or reply-to), per-shop recipients for lead alerts; keep the platform Resend key but never mix recipients.
- **Leads / public endpoints:** `/api/leads/public/` and RAG take the shop from host/path (public store page), not from `LEAD_SHOP_SLUG`. RAG gets a per-shop knowledge scope.

## Rollout order

1. **Stop the leaks (small, safe, ship first):** read-only `shop` on `Meta*`; real `.unscoped()`; set `shop` before both `bulk_create`s; atomic order numbers.
2. **Resolver:** Flutter reads URL; Worker trusted header; reject disagreement; delete `fallback_shop`; shop-host allowlist for CORS/APP_ORIGINS.
3. **Customers per shop:** tenant-scoped `/api/customer/*`, membership-bound customers, sign-up fix, shop-bound tokens.
4. **DB hardening:** NOT NULL, same-shop constraints, RLS rebuilt (non-owner role, forced, all tables, `SET LOCAL`), Postgres in CI.
5. **Integrations per shop:** Neonize, Meta, email, leads.
6. **Workflow engine:** `WorkflowStage` and events, per-shop categories/tax/templates, branding.
7. **Wildcard/custom domains and invites** (infra + onboarding).

Steps 1-3 deliver "each shop has its own URL and its own customers". Step 6 is the largest and can be a separate release.

## Critical files

- Backend: `crm/backend/api/{models,tenancy,middleware,auth,password_auth,customer_views,role_views,views,serializers,services_import_export,media_views,storage}.py`, `services/{meta_social_service,neonize_service,email_service}.py`, `settings.py`, `migrations/0028_*`.
- Frontend: `crm/washnlaundrycrm/lib/{main.dart,providers/app_provider.dart,providers/auth_provider.dart,services/api_service.dart,utils/fresh_login_web.dart,screens/login_screen.dart}`.
- Infra: `crm/cloudflare/api-proxy/src/index.ts`, `scripts/deploy_cloudflare_pages.js`.

## Verification

- **Isolation test suite on Postgres:** two shops; for every tenant endpoint assert (a) list excludes the other shop, (b) detail by the other shop's id is 404, (c) create/update with the other shop's FK ids is rejected, (d) `shop` in the payload is ignored. Generated from the router so new endpoints are covered automatically.
- **RLS test:** raw SQL under the runtime role with the tenant unset returns zero rows; with shop A set, shop B rows are invisible even via ORM `all_objects`.
- **Auth tests:** a token for shop A is rejected on shop B's host; a customer of A gets 403/404 on B; same email in A and B resolves to separate customers.
- **Concurrency test:** 20 parallel order creates in one shop give distinct, gapless numbers.
- **Import tests:** imported rows have the right `shop`; a re-import into shop B never touches shop A.
- **Manual:** open `a.` and `b.` hosts (or `/s/a`, `/s/b`) in separate browsers, sign up as a customer on each, create an order and move it through a custom workflow in A only; confirm B is unaffected.
- `scripts/check_tenant_integrity` reports zero NULL `shop` rows before the NOT NULL migration.
