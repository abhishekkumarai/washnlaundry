# CLAUDE.md — LaundryBill CRM clone

Working clone of `app.laundrybill.com` (a laundry / dry-cleaning shop CRM + POS).

**Stack is Flutter Web + Django REST Framework. Nothing else.**

---

## Layout

| Path | What it is |
|---|---|
| `washnlaundrycrm/` | Flutter Web SPA — the entire frontend |
| `backend/` | Django + DRF + SQLite — the entire backend |
| `docker-compose.yml` | Runs both (frontend `:8080` via nginx, backend `:8000` via Django) |
| `LIVE_AUDIT.md` | **Screen-by-screen spec of the real app**, captured 2026-07-30. Read this before building any screen. |
| `screenshots/` | Reference captures of the real app + audit shots of ours |
| `app_index.js`, `app_ui.js`, `index_fetched.html` | Downloaded bundles from the real app. **Reference only** — read them to learn routes/labels/behaviour. Never paste their code into ours. Gitignored: third-party minified source, re-downloadable, not ours to redistribute. |

The abandoned parallel Next.js implementation (`app/`, `components/`, `lib/`, `prisma/`,
`node_modules/` and their `package.json` / `next.config.js` / `tailwind.config.js` /
`postcss.config.js` / `tsconfig.json`) was **deleted** on 2026-08-10, along with the
one-off Chrome-screenshot/audit scripts that used to sit at the repo root. The tree is
now Flutter + Django only. The audit scripts are recoverable from git history at
`741b895~1`; the Next.js files were never tracked, so they are gone from the repo.

---

## Running it

```bash
docker compose up --build          # frontend :8080, backend :8000
```

That is genuinely the whole command — `washnlaundrycrm/Dockerfile` is multi-stage and
compiles the Flutter bundle inside the image, so no local Flutter SDK is involved and a
stale `build/web` can't be shipped by accident. The build stage is pinned to
`ghcr.io/cirruslabs/flutter:3.44.0`; bump that tag when you upgrade Flutter locally.

The trade-off is speed: the first build pulls a multi-GB SDK image and compiles from
scratch. **For frontend work, use `flutter run -d chrome` below instead** — hot reload,
seconds not minutes. Reach for Docker to verify the real artefact, not to iterate.

**On a genuinely fresh clone, that command alone gives you an empty shop.**
`backend/Dockerfile`'s `CMD` only runs `python manage.py migrate --noinput` before
starting the server — it never seeds. What makes "the whole command" true in practice is
that `docker-compose.yml` bind-mounts `./backend:/app`, so the container's SQLite file
*is* `backend/db.sqlite3` on the host; once you've run `python seed_db.py` locally once
(see below), every subsequent `docker compose up` — with or without `--build` — reuses
that already-seeded file. `backend/db.sqlite3` is gitignored, so a fresh clone has none
of that history. Seed it once, either way:

```bash
docker compose exec backend python seed_db.py   # container already running
# or, before ever starting Docker:
cd backend && python seed_db.py
```

Re-running `seed_db.py` is always safe to reach for again later — it wipes and reseeds
every table, so a container you've been poking at in a broken state can be reset the same
way.

Local dev without Docker:

```bash
cd backend && pip install -r requirements.txt
python manage.py migrate && python seed_db.py && python manage.py runserver 8000

cd washnlaundrycrm && flutter run -d chrome
```

`python seed_db.py` **wipes every table** and reseeds. It is the only source of demo data.

---

## Deployment (production)

Split host: **backend on Render, frontend on Vercel.** GitHub repo is
`abhishekkumarai/washnlaundrycrm` (renamed from `laundrybill_crm` on 2026-09-24; Render
and both Vercel projects were re-pointed and GitHub redirects the old URL).

**Backend — Render, automatic.** Service `laundrybill-backend`
(`srv-da4j29bl550s738309ng`, free plan, root dir `backend/`) at
`https://laundrybill-backend.onrender.com`, auto-deploys on every push to `main`.
Build: `pip install -r requirements.txt && python manage.py collectstatic --noinput`.
Start: `python manage.py migrate --noinput && gunicorn laundry_backend.wsgi:application
--bind 0.0.0.0:$PORT` — so new migrations apply on deploy with no manual step. Settings
are env-driven (`SECRET_KEY`, `DEBUG`, `ALLOWED_HOSTS`, `CORS_*`; commit `6e71cdb`).
Inspect with the `render` CLI (`render services list -o json`, `render deploys list`).
- **Production database is Neon Postgres** (`washnlaundry-db`, region `pdx1` next to
  Render's Oregon; provisioned 2026-09-24 via the Vercel Marketplace in team
  "abhishekzgithub's projects", connected to the `washnlaundry-crm` project). Render's
  env var **`DJANGO_DATABASE_URL`** holds its pooled URL; `settings.py` uses it via
  `dj-database-url` when set, and falls back to SQLite when unset (local dev, Docker,
  tests). It is deliberately *not* `DATABASE_URL` — see the machine-wide
  `DATABASE_URL` gotcha in `~/CLAUDE.md`, which would otherwise hijack local runs.
  Before this, Render had no persistent disk, so SQLite reset to empty on every
  deploy/restart. Data now survives restarts (verified).
- **Re-seeding production** is a manual, destructive choice (`seed_db.py` wipes every
  table): pull the URL with `vercel env pull` from a dir linked to `washnlaundry-crm`,
  then run `DJANGO_DATABASE_URL=<DATABASE_URL_UNPOOLED> python seed_db.py` from
  `backend/`. Never set it in a shell you'll keep using — every command there hits prod.
- Free tier sleeps when idle; the first request after a nap can take well over 15 s.
  That reads like a hung backend — it isn't. Retry with a long timeout.
- `laundrypro-api` / `laundrypro-db` in the same Render account are an unrelated
  project, not this one.

**Frontend — Vercel.** Vercel has no Flutter SDK, so a Git-triggered build
produces an empty deployment that 404s — the real site comes from uploading a
locally built bundle, with the Render API URL baked in:

```bash
cd washnlaundrycrm
flutter build web --release --dart-define=API_BASE_URL=https://laundrybill-backend.onrender.com/api
node ../scripts/deploy_vercel.js   # deploys build/web to washnlaundry-crm
```

### Branches: `main` = Vercel + Render, `cloudflare` = Cloudflare (decided 2026-10-06)

The two hosting stacks are kept on separate branches so a push for one never ships the other.
Feature branches never deploy.

| Branch | Deploys | Triggered by |
|---|---|---|
| `main` | Django backend → Render (auto, runs migrations); Flutter CRM → **Vercel** `washnlaundry-crm` | push to `main` (Render) + pre-push hook (Vercel) |
| `cloudflare` | Flutter CRM → Cloudflare Pages `washnlaundrycrm.pages.dev`; Workers `washnlaundry-rag` (chat, lead capture, 15-min cron) and `washnlaundry-api-proxy` | pre-push hook on that branch (Pages); `npx wrangler deploy` in `cloudflare/<worker>/` (Workers) |

Neutral backend code (e.g. the website-chat `Lead` model, `/api/leads/`, Resend email) lives on
`main` because Render only deploys `main`; the Worker, cron, Pages deploy and chat UI live on
`cloudflare`. `cloudflare/` on `main` is the older Worker source and is not deployed from here.
The marketing site (`washnlaundry-marketing`) is a separate repo, `abhishekkumarai/washnlaundry`.

The **pre-push hook** (`.githooks/pre-push`, active via `core.hooksPath`) differs per branch
(`node scripts/setup_hooks.js` copies the current branch's copy into `.git/hooks`). On `main` it is
path-aware and only acts on pushes to `main`: `backend/**` changed → Django tests only;
`washnlaundrycrm/**` or `scripts/deploy_vercel.js` changed → Flutter tests + build + Vercel deploy;
anything else → nothing. A first push / undiffable base runs everything; any failing step aborts
the push. `PREPUSH_DRY_RUN=1` prints what would run. On `cloudflare` the same logic deploys to
Cloudflare Pages instead.

Target project is **`washnlaundry-crm`** in team "abhishekzgithub's projects"
(`team_3q6DiOqHmHEU2kSpyXvL3xzg`); there is also an unused, empty `washnlaundrycrm`
project there. SPA routing comes from `washnlaundrycrm/vercel.json`'s catch-all rewrite
(no `cleanUrls` — it broke deep links). The local `.vercel/project.json` files point at a
different team the CLI can't reach; don't trust them, link explicitly.
**www.washnlaundry.com is not this app** — it is a separate Next.js site in another
Vercel team; pointing it here needs that team's access or a TXT re-verification at the
Namecheap DNS.

---

## Backend

Django 5 / DRF / SQLite, app label `api`. Everything is a plain `ModelViewSet` on a `DefaultRouter` — no auth, no permissions, no pagination, no filtering.

Models (`backend/api/models.py`): `Shop`, `Customer`, `GarmentCategory`, `GarmentItem`, `Order`, `OrderItem`, `Expense`, `Credit`, `CreditCategory`, `Staff`, `Attendance`, `SalaryPayment`.

`Credit` is money coming *into* the shop outside an order (advances, delivery fees, owner top-ups) — the mirror of `Expense`. Unlike `ExpenseCategory` (fixed `TextChoices`), its categories are a **shop-managed table**, `CreditCategory`, edited from Settings → Credit categories and seeded by migration `0018` with `DEFAULT_CREDIT_CATEGORIES`. `Credit.category` is a `PROTECT` FK, so a category in use can only be turned off (`is_active=False`: hidden from new credits, kept on old ones), never deleted. The API still reads and writes the category **by name** (`SlugRelatedField`), so a rename shows on every existing credit.

`SalaryPayment` is a payout against one staff member's wages for one month. Wages *earned* are never stored — they are derived from `Attendance` times `Staff.daily_wage`, with `Attendance.DAY_VALUE` deciding what each state is worth (`HALF_DAY` is 0.5; `LEAVE` is unpaid). It is deliberately **not** unique on `(staff, month)`: a month can be paid in instalments, which is what makes `PARTIAL` a real state.

| Endpoint | |
|---|---|
| `/api/shops/` `/api/customers/` `/api/categories/` `/api/items/` `/api/orders/` `/api/expenses/` `/api/staff/` `/api/attendance/` | full CRUD |
| `/api/dashboard/stats/` | aggregates: order counts by status, revenue, dues, expenses, net profit |
| `/api/attendance/bulk/` | POST a whole day's register; **upserts**, because `Attendance` is unique on (staff, date) and Save Register must be pressable twice |
| `/api/credits/` | full CRUD; `category` is the category's name |
| `/api/credit-categories/` | full CRUD, each row with a read-only `credit_count`; DELETE of a category in use returns 400 ("turn it off instead") |
| `/api/salary-payments/` | full CRUD, filterable by `?month=YYYY-MM` and `?staff=` |
| `/api/payroll/?month=YYYY-MM` | the Payroll screen in one call: days worked and wages derived from the register, paid/pending from `SalaryPayment`, plus the four KPI totals |

`Customer.id` and `Order.id` are UUIDs. `GarmentItem` carries a **column per service type** (`dry_clean_price`, `wash_iron_price`, `wash_fold_price`, `steam_press_price`, `iron_price`), and the seed sets the irrelevant ones to `0` rather than null — so "price is 0" means "service not offered for this garment", not "free".

Settings are dev-only and must not ship as-is: `DEBUG = True`, hardcoded `SECRET_KEY`, `ALLOWED_HOSTS = ['*']`, `CORS_ALLOW_ALL_ORIGINS = True`.

---

## Frontend

Flutter Web, Material 3, `provider` for state, `fl_chart` for charts, `google_fonts` (IBM Plex Sans). Brand colour `#1A4FD6`, surface `#F8FAFC`.

**There is now a real router** (`go_router`, `lib/router.dart`). `AppProvider.currentNavIndex`/`setNavIndex` still exist and are still what every screen and the sidebar read for "which section is active" — routing is layered on top as a hybrid, not a replacement: each `GoRoute`'s builder defers a `setNavIndex` call (via a post-frame callback — calling it synchronously from `builder:` throws, since that runs during the build phase) and returns the screen. This kept the change from touching `SidebarNavigation`'s read path or any of the ~20 widget tests that pump a screen directly with no router ancestor.

- URLs, deep links, and browser back/forward all work — confirmed by signing into the real app.laundrybill.com and comparing behaviour directly (see `wip.md`'s "go_router migration" section for what was checked).
- `/orders/:id` is a real per-record route (`router.dart`), matching the real app's Firestore-doc-ID URLs. It `watch`es `AppProvider` rather than `read`ing it, so a deep link hit before `loadDataFromBackend()` resolves shows a spinner that turns into the real order once the data arrives, rather than a false "not found". `OrdersScreen` no longer swaps its own body for `OrderDetailScreen` — `orders_screen.dart:39`'s old pattern is gone.
- Section navigation goes through `context.goSection(n)` (`lib/utils/navigation.dart`), a thin wrapper that looks `n` up in `AppProvider.routePaths` and calls `context.go(path)` — every former `setNavIndex(n)` call site was a same-shape one-line swap to this.
- `/settings` (index 13) is routed and enabled as of 2026-09-24. Of its vertical tab list only **Business profile** and **Credit categories** (`lib/widgets/credit_categories_panel.dart`) are built; the other tabs show "Not available yet". `?tab=<slug>` opens a specific tab — Credits' Add dialog links to `/settings?tab=credit-categories`. Below `contentWideBreakpoint` the 240px tab column becomes a chip row.
- Sidebar indices are still load-bearing magic numbers, now doubling as the vocabulary `AppProvider.routePaths` maps to URL paths — and must be unique: Credits was once given 14, Help's index, which lit both up. Credits is 15. Index 10 (`Apps`) and 12 (`Subscription`) are still flagged `disabled: true` and render a "Soon" chip; re-enabling one still means flipping `disabled` back to `false` in `sidebar_navigation.dart`, but now also means adding a route for it in `router.dart` rather than a `case` in `main.dart`.

Adding a screen now means: write it, add a `navItems` entry with a new index, add its path to `AppProvider.routePaths`, add a `GoRoute` in `router.dart`.

### Authentication

`/login` (`lib/screens/login_screen.dart`), via `AuthProvider`, matches the real app's route — and, like the rest of this section describes, **UI-only**: it gates which screen the router shows, exactly as the backend's own doc comment says the API stays ("no auth, no permissions"). Wiring a real, server-verified session is a separate, larger change than this covers.

**The auth gate is always on** — `router.dart`'s `redirect` sends any signed-out visit to `/login` regardless of whether Google Sign-In is configured; there is no zero-config bypass. Two independent ways to satisfy it:

- **Google Sign-In** (`google_sign_in` ^7), when `GOOGLE_CLIENT_ID` is set — see below.
- **Demo Mode** (`AuthProvider.signInAsDemo`), always available. The login page's layout matches the real one (Email/Password fields, Sign In/Create Account tabs, "Forgot password?"), but this clone's Django backend has no User/password model to check credentials against, so both tabs' primary button — and the separate "Try Demo Mode" button shown when Google isn't configured — call `signInAsDemo` rather than actually authenticating anything typed into the form. "Forgot password?" and "Sign in with mobile number instead" are rendered for layout parity only: the former shows a "not available in this demo" toast, the latter is greyed out and inert (no tap handler at all).

Either path persists the same way (`SharedPreferences`, checked by `AuthProvider._init()` on every reload) and both end via the same `AuthProvider.signOut()`, so `docker compose up` / `flutter run` **always** land on `/login` first now — Demo Mode is the fast way through it, not a fallback bypass.

Google Sign-In needs `--dart-define=GOOGLE_CLIENT_ID=your-id.apps.googleusercontent.com` — a **Web application** OAuth Client ID from Google Cloud Console, with `http://localhost:<port>` (whatever `--web-port` you run with) and, for the Docker path, `http://localhost:8080` as Authorized JavaScript origins. Leave Authorized redirect URIs empty — Google Identity Services signs in via its own rendered button and a JS callback, not a server redirect. For the Docker path, `docker-compose.yml` reads `GOOGLE_CLIENT_ID` from a `.env` file (`.env.example` documents this; `.env` itself is gitignored) and passes it as a build arg — `docker compose up --build` with no `.env` builds with it empty, same as omitting the dart-define for `flutter run`. **With no `GOOGLE_CLIENT_ID`, the login page simply omits the Google button and the "OR" divider** and Demo Mode is the only path in — the gate itself does not change.

The GIS SDK only allows signing in through UI it renders itself — a programmatic `authenticate()` call throws on web. `lib/utils/google_signin_button.dart` conditionally exports a web implementation (`google_sign_in_web`'s `renderButton`) or a plain button wired to `AuthProvider.authenticate()` everywhere else, picked via `if (dart.library.js_interop)` — the same conditional-import shape this file already calls for around `dart:io`, mirrored for a web-only dependency instead of a non-web-only one. `google_sign_in_web` fails to *compile* (not just run) off web, including on the plain-VM target `flutter test` uses, which is why this is a real conditional export and not a `kIsWeb` runtime check.

### Data flow — read this before touching a screen

`ApiService` (`lib/services/api_service.dart`) exposes exactly four calls: `fetchDashboardStats`, `fetchOrders`, `fetchGarmentItems`, `createOrder`. Base URL is `String.fromEnvironment('API_BASE_URL')` defaulting to a relative **`/api`** — same-origin, which is what lets one bundle work in Docker, in a deploy, and locally. `nginx.conf` proxies `/api/` to `http://backend:8000/api/`. Split-host deploys override it at build time with `flutter build web --dart-define=API_BASE_URL=...`.

So only **orders** and **garment items** are real. Everything else is a hardcoded Dart literal inside the widget, despite the Django model and endpoint already existing:

| Screen | State |
|---|---|
| Orders, Order detail, New Order | wired to API |
| Customers, Customer detail | wired to API |
| Services | wired to API |
| Staff | wired to API |
| Expenses | wired to API |
| Attendance | wired to API |
| Payroll | wired to API |
| Reports | wired to API |

Every screen now reads from the backend. `loadDataFromBackend` fetches the whole shop in one `Future.wait`; the three range-scoped screens (a day of Attendance, a month of Payroll, a date range of Reports) load on demand instead, and keep their own `*Loading` / `*Error` flags so a failed single-day fetch reports inline rather than blanking a roster that loaded fine.

Wiring these to their existing endpoints is mostly mechanical and is the main outstanding backend-integration work.

`ApiService` swallows every failure — `catch (e) { print(...) }` then returns `{}` / `[]`. `AppProvider` then only overwrites its list *if the result is non-empty*, so a backend outage silently shows stale or empty data with no error state. The real app shows an explicit "Error loading dashboard / Retry" panel; ours cannot.

---

## The app we're cloning

Real app is React + Firebase (Firestore project `laundryos`). We reimplement its **behaviour**, not its code.

### Real route table

Extracted from `app_index.js`. This is the authoritative feature surface.

**Shop owner** (what we're building): `dashboard`, `scan`, `new-order`, `orders`, `orders/:orderId`, `customers`, `customers/:customerId`, `inventory`, `manage-staff`, `attendance`, `payroll`, `expenses`, `reports`, `apps`, `settings`, `shop-settings`, `delivery-settings`, `shops`, `shops/new`, `settings/subscription`, `settings/payment-history`, `settings/public-page`, `settings/offers`, `help`, `/subscription`

**Public / unauthenticated:** `/login`, `/track`, `/track/:trackingId`, `/track/:shopId/:publicId`, `/receipt/:orderId`, `/order/:shopSlug`, `/:shopSlug`

**Other portals, none of which we have started:**
- `/staff/*` — login, signup, orders/new, orders, orders/:id, customers, expenses, scan, profile
- `/agent/*` (pickup & delivery) — login, signup, orders/new, pickups, pickups/:id, deliveries, deliveries/:id, scan, profile
- `/plant/*` — login, dashboard, inbound, processing, ready, orders/:id, scan, completed
- `/super-admin/*` — login, plans, shops, shops/:id, map, subscriptions, payments, scan, settings, items-list, notifications, support, feedback
- `/team`, `/team/login`, `/team/signup`

### Real sidebar vs ours — verified

The live owner sidebar has **8** items: Dashboard, New Order, Orders, Customers, Services, Apps, Subscription, Settings.

Ours has **14**, promoting Staff / Attendance / Payroll / Expenses / Reports / Scan to top level.

**There are no plan tiers.** An earlier note here claimed `/manage-staff`, `/attendance`, `/payroll`, `/expenses`, `/reports`, `/scan`, `/settings/public-page` and `/settings/offers` redirect to `/dashboard` as *paid-plan features*, and told you to choose between a "Free surface" and a "Business surface". That was wrong: the tiers those routes were attributed to no longer exist, so there is no Free/paid split to target and the sidebar difference is not a gating question.

What still needs checking against the live app: whether the owner sidebar really is 8 items today, and whether those eight routes are simply the ones with a nav entry while the rest stay reachable by URL. Do that before treating the 14-item shape as a divergence at all.

### Statuses

Order: `Pending`, `Processing`, `Ironing`, `Ready`, `Out for Delivery`, `Delivered`, `Cancelled`.
Payment: `Paid`, `Partial`, `Unpaid`.
Orders list filters by 11 tabs incl. derived ones (`Overdue`, `Scheduled`, `Unpaid`, `Partial`).

**Known inconsistency:** `Order.STATUS_CHOICES` only defines `PENDING/WASHING/READY/DELIVERED/CANCELLED`, but `seed_db.py` writes `OUT_FOR_DELIVERY` and `OVERDUE`, and `AppProvider` filters on `PROCESSING`, `RECEIVED`, `OUT_FOR_DELIVERY`, `OVERDUE`. Three different vocabularies. Pick one — the real app's list above — and normalise model, seed and provider together. Note `Ironing` is a real status we don't model at all.

Pricing units in the real app: `/pc`, `/kg` (Regular Cloths ₹85/kg), `/sq.ft` (Carpet ₹15), `/set` (Sofa Cleaning ₹200). **We only model per-piece.**

Order numbers are shop-prefixed and sequential — `#WA3P-00001`, derived from the shop name `washing`. We use a flat `LB-2001`.

`GarmentItem` also needs `unit`, `turnaround_days` ("1d" on every card) and `is_active` ("Show Inactive" filter). And the real model is **one row per item with one price**, not our five price columns (`dry_clean_price`, `wash_iron_price`, …) on a single row — the same garment appears separately under each category at a different price, which is why the real catalogue has 79 items to our 35.

`Order` is missing: delivery charge (₹50 line on the receipt), expected/scheduled date, assigned agent, source channel ("Created by Mobile App"), and per-status timestamps to render the timeline. `OrderItem` is missing a per-item status.

Time slots carry a **capacity** (max orders/day) and a **buffer** (minutes before slot cutoff). We model neither.

---

## Reference-capture workflow

To inspect the live app, drive Chrome via the claude-in-chrome tools. Notes from doing this:

- **The app allows one active session per account.** Signing in anywhere else — another tab, the phone app — terminates this one with *"You were signed out because your account was signed in on another device."* Close every other session first, or the crawl will drop mid-run.
- **A route you can't reach redirects to `/dashboard` with no message.** Always check the URL you landed on, not just the page content, or you'll record the dashboard as if it were `/reports`. This is also how the "paid-plan gating" claim above got into these notes — a redirect was read as a plan tier. Confirm *why* a route bounced before writing down a reason.
- **Auth restore is slow** (~20–30 s). The app renders `/login` first, then swaps to `/dashboard` once `onAuthStateChanged` fires. Screenshotting too early gives a false "logged out" reading. Wait, then re-check.
- Watch the console for `[Auth] onAuthStateChanged fired, user: <uid>` — that's the ground truth for session state.
- The **Poper Blocker** extension (`bkkbcggnhapdmkeljlodobbkopceiche`) injects into the page and throws `AbortError: The user aborted a request` repeatedly, which breaks the app's profile fetch and produces `Failed to load profile. Please try again.` followed by a forced sign-out. Disable it for this domain before any capture session.
- `--remote-debugging-port` is **not** an option: Chrome ≥136 refuses to open the debug port when `--user-data-dir` is the default profile. Chrome here is 150. A debug port requires a separate profile dir, which won't carry the login.
- Only a human can sign in. Do not attempt it.

---

## Future steps — one codebase, three form factors

The target is **the same Flutter app running as an Android app, as web, and in a tablet
layout**, each adapting to its form factor rather than being a separate build.

### Where it stands

`android/`, `web/` and `windows/` are scaffolded (no `ios/`). Only web has ever been
built or run.

**Tablet-width responsive layout is done** (session of 2026-08-26). Every screen that
carries the nav rail now wraps its `Scaffold` in `AppShell` / `AppDrawer`
(`lib/widgets/app_shell.dart`) instead of the old inline
`Row(children: [SidebarNavigation(), Expanded(body)])`:

| Width | Nav |
|---|---|
| ≥ `expandedMinWidth` (1080) | 240px labeled rail, honours the collapse toggle |
| `railMinWidth` (700) – 1080 | 72px icon rail, toggle ignored |
| < `railMinWidth` (700) | Rail is dropped entirely; a 44px hamburger bar opens `AppDrawer`, which hosts `SidebarNavigation(inDrawer: true)` — full labeled list, no collapse toggle, closes itself on tap |

Below `SidebarNavigation.contentWideBreakpoint` (760, shared by every screen — Orders,
Customers, Staff, Attendance, Payroll, Expenses, Reports, Services, New Order, Order
Detail, Customer Detail), wide tables fall back to a card/list layout, primary header
actions (New Order, Add) collapse to icon-only buttons, and secondary actions fold into
an overflow menu. `SidebarNavigation.contentStackBreakpoint` (900) is the second,
looser threshold a few screens (Reports, Customer Detail) use to collapse two
side-by-side panels into one column without a full card rebuild. Both constants live on
`SidebarNavigation` next to `expandedMinWidth`/`railMinWidth` precisely so no screen
needs its own private copy — a first pass had each screen declare its own
`_wideBreakpoint = 760`, which this session's cleanup centralized. The dashboard's own
`_wideBreakpoint = 990` (pre-existing, in `dashboard_screen.dart`) is a separate,
unrelated threshold and was deliberately left alone.

Every layout change has a widget test driving `tester.view.physicalSize` at the
target width — `app_shell_test.dart` (new) covers the rail/drawer swap itself; each
screen's own test file covers its phone-width behaviour.

Not yet done: a genuinely graduated tablet-only layout (e.g. a 2-column dashboard grid
between phone and desktop) — today every screen is binary (wide/narrow), not
three-tier. `services_screen.dart`'s and `new_order_screen.dart`'s item grids do have a
graduated column count (1/2/3/4 at 380/620/900), but that's a per-grid column function,
not the same "content breakpoint" concept, and was left as-is.

### What each target needs

**Android.** Two things block it, in order:

1. **`ApiService.baseUrl` defaults to a relative `/api`.** That is correct on web, where
   nginx proxies same-origin, and meaningless in an APK — there is no origin. Android
   builds need an absolute base URL via `--dart-define=API_BASE_URL=...`, and the
   emulator reaches a host machine at `10.0.2.2`, not `localhost`. (There is now a
   `kDebugMode`-gated dev convenience for `flutter run` reaching a local `manage.py
   runserver` — see `ApiService.baseUrl`'s doc comment — but that's debug-only and
   doesn't extend to a release APK.)
2. ~~Phone widths are below every breakpoint the app was designed for~~ — no longer
   true now that `AppShell` gives widths below `railMinWidth` a drawer instead of a
   squeezed rail (see "Where it stands" above). What's left for Android specifically:
   the drawer's hamburger-bar shell hasn't been checked against a *phone-shaped* window
   (only tested down to narrow desktop/tablet widths so far), and `SidebarNavigation`'s
   own internal 60px "narrow rail" branch (`narrowRailWidth`, gated on the same
   `railMinWidth` `AppShell` already switches on) is now dead in production — `AppShell`
   never renders `SidebarNavigation` non-drawer below that width, so that branch only
   still fires in tests that pump `SidebarNavigation` directly. Worth deleting once
   confirmed nothing else depends on it.

The router is no longer a blocker here — `go_router` (see the Frontend section) gives the
Android system back button a real Navigator to pop, which the old `switch`-on-`currentNavIndex`
shell didn't.

Also unhandled on mobile: `Scan` currently assumes a desktop webcam, and the receipt flow
assumes browser printing.

**Web.** Already the working target — keep it that way. The Docker path builds and serves
it, and `flutter run -d chrome` is the fast loop.

### Constraints to respect

- **One codebase, no per-platform forks.** Branch on layout width, not on
  `Platform.isAndroid`, except where a capability genuinely differs (camera, printing).
- `dart:io` is unavailable on web. Anything platform-specific needs a conditional import
  or it breaks the web build that currently works.
- The Docker/nginx setup is web-only by nature. An Android build is a separate
  `flutter build apk` and does not belong in `docker-compose.yml`.
- Every layout change needs a widget test at the target width. `widget_test.dart` already
  demonstrates the pattern — it drives `tester.view.physicalSize` to assert rail
  behaviour at 1400 / 900 / 600 px.

---

## Conventions

- Indian context throughout: ₹, phone `+91`, GSTIN on the shop, `Asia/Kolkata`, Bengaluru addresses in seed data.
- Seeded shop is `washing`, owner `AK` — matches the live account the screenshots come from.
- Money is `FloatField` / Dart `double` end to end. Fine for a demo, wrong for money; if this ever takes real payments, move to integer paise.
- Flutter widgets are large single files with inline literals and no test coverage beyond the default `widget_test.dart`. Match the surrounding style when editing rather than introducing a new architecture mid-file.

---

## Jira tracking

Work on this project is tracked in Jira project **KAN** ("washnlaundry", site
`emailabhishek2.atlassian.net`) via the `atlassian` MCP server (added
2026-08-29; `claude mcp add --transport sse atlassian
https://mcp.atlassian.com/v1/sse` — re-authenticate with
`mcp__atlassian__authenticate` if its tools ever stop showing up after a
restart). Four standing epics hold the outstanding-work backlog:

| Epic | Covers |
|---|---|
| KAN-4 | Android / multi-form-factor |
| KAN-5 | Routing / dead screens |
| KAN-6 | Real-app parity gaps (vs. app.laundrybill.com) |
| KAN-7 | Smaller known gaps |

**Whenever you complete a unit of real work in this repo** — a bug fix, a
feature, a refactor with user-visible effect, not a read-only investigation
or a question answered — do the following before considering the task
finished:

1. Check whether an existing KAN issue already describes it (search
   `getVisibleJiraProjects`/`searchJiraIssuesUsingJql`, or recall from this
   session) — if so, comment/transition that issue instead of creating a
   duplicate.
2. Otherwise create a Jira **Subtask** under the epic (or under a Task
   already sitting under the right epic, if one exists) via
   `createJiraIssue`, using `parent` to link it. Pick the epic by subject
   matter (Android work → KAN-4, etc.); if the work doesn't fit any of the
   four, say so and ask rather than forcing a bad fit.
3. Give the subtask a summary that names the actual change (not "fix bug")
   and a description with enough context (file/screen touched, why) that
   someone reading only Jira understands what happened, mirroring the level
   of detail this file and `wip.md` already keep.
4. If the change closes out something the subtask/epic describes, transition
   it to **In Review** (`transitionJiraIssue`) — never straight to Done, even
   when verification looks solid. Then explicitly ask the user to confirm
   before moving it to Done; don't auto-close on your own say-so.

This is a standing instruction, not a mechanical hook — deciding *which*
epic and *what* the subtask should say needs judgment a shell hook doesn't
have. Follow it without being asked again each session.

**Mechanical backstop:** `.claude/settings.local.json` (gitignored, personal)
has a `Stop` hook that hashes `git status --porcelain` + `git diff HEAD` and
compares it against `.claude/.jira-sync-marker` (also gitignored). If they
differ — meaning the working tree changed since the marker was last written —
it prints a `systemMessage` reminder; it does not block. After handling Jira
per the steps above (or after a change that genuinely doesn't warrant a KAN
issue — e.g. editing this file), refresh the marker so the reminder goes
quiet again:

```bash
printf '%s' "$(git status --porcelain)$(git diff HEAD)" | sha256sum | cut -d' ' -f1 > .claude/.jira-sync-marker
```

The hook only tracks tracked-file diffs plus the untracked-file list — a
brand-new file's content changing across turns without being added/removed
won't retrigger it. It's a nudge, not a guarantee; the instruction above is
what actually does the linking.
