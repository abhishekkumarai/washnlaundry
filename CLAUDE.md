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

Local dev without Docker:

```bash
cd backend && pip install -r requirements.txt
python manage.py migrate && python seed_db.py && python manage.py runserver 8000

cd washnlaundrycrm && flutter run -d chrome
```

`python seed_db.py` **wipes every table** and reseeds. It is the only source of demo data.

---

## Backend

Django 5 / DRF / SQLite, app label `api`. Everything is a plain `ModelViewSet` on a `DefaultRouter` — no auth, no permissions, no pagination, no filtering.

Models (`backend/api/models.py`): `Shop`, `Customer`, `GarmentCategory`, `GarmentItem`, `Order`, `OrderItem`, `Expense`, `Staff`, `Attendance`.

| Endpoint | |
|---|---|
| `/api/shops/` `/api/customers/` `/api/categories/` `/api/items/` `/api/orders/` `/api/expenses/` `/api/staff/` `/api/attendance/` | full CRUD |
| `/api/dashboard/stats/` | aggregates: order counts by status, revenue, dues, expenses, net profit |

`Customer.id` and `Order.id` are UUIDs. `GarmentItem` carries a **column per service type** (`dry_clean_price`, `wash_iron_price`, `wash_fold_price`, `steam_press_price`, `iron_price`), and the seed sets the irrelevant ones to `0` rather than null — so "price is 0" means "service not offered for this garment", not "free".

Settings are dev-only and must not ship as-is: `DEBUG = True`, hardcoded `SECRET_KEY`, `ALLOWED_HOSTS = ['*']`, `CORS_ALLOW_ALL_ORIGINS = True`.

---

## Frontend

Flutter Web, Material 3, `provider` for state, `fl_chart` for charts, `google_fonts` (IBM Plex Sans). Brand colour `#1A4FD6`, surface `#F8FAFC`.

**There is no router.** `main.dart` switches on `AppProvider.currentNavIndex` in a `switch` statement, and `SidebarNavigation` sets that index. Consequences you will hit:

- No URLs, no deep links, no browser back button, no `/orders/:id` route.
- `OrderDetailScreen` is reached by `OrdersScreen` swapping its own body (`orders_screen.dart:39`), not by navigation.
- `SettingsScreen` (408 lines) exists but **is not wired into `main.dart` at all** — it is dead code today.
- Sidebar indices are load-bearing magic numbers. Index 10 (`Apps`), 12 (`Subscription`), 13 (`Settings`) are flagged `disabled: true` and render a "Soon" chip. Apps and Subscription have no screen at all; Settings has one, deliberately left unrouted — re-enabling it means flipping `disabled` back to `false` in `sidebar_navigation.dart` and restoring `case 13` plus its import in `main.dart`.

Adding a screen means: write it, add a `navItems` entry with a new index, add a `case` in `main.dart`. Moving to `go_router` would fix all of the above and is the single highest-value refactor available.

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
| Attendance | `_staff` literal |
| Payroll | `_staffPayroll` literal |
| Reports | derived from the Attendance / Payroll literals |

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

Ours has **14**, promoting Staff / Attendance / Payroll / Expenses / Reports / Scan to top level. Verified on the live Free-plan account: `/manage-staff`, `/attendance`, `/payroll`, `/expenses`, `/reports`, `/scan`, `/settings/public-page` and `/settings/offers` all **silently redirect to `/dashboard`** — they are paid-plan features. This is the biggest structural divergence in the clone.

Decide deliberately whether the clone targets the *Free* surface (8 items) or the *Business* surface (everything). Right now it's neither.

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
- **Gated routes redirect to `/dashboard` with no message.** Always check the URL you landed on, not just the page content, or you'll record the dashboard as if it were `/reports`.
- **Auth restore is slow** (~20–30 s). The app renders `/login` first, then swaps to `/dashboard` once `onAuthStateChanged` fires. Screenshotting too early gives a false "logged out" reading. Wait, then re-check.
- Watch the console for `[Auth] onAuthStateChanged fired, user: <uid>` — that's the ground truth for session state.
- The **Poper Blocker** extension (`bkkbcggnhapdmkeljlodobbkopceiche`) injects into the page and throws `AbortError: The user aborted a request` repeatedly, which breaks the app's profile fetch and produces `Failed to load profile. Please try again.` followed by a forced sign-out. Disable it for this domain before any capture session.
- `--remote-debugging-port` is **not** an option: Chrome ≥136 refuses to open the debug port when `--user-data-dir` is the default profile. Chrome here is 150. A debug port requires a separate profile dir, which won't carry the login.
- Only a human can sign in. Do not attempt it.

---

## Future steps — one codebase, three form factors

The target is **the same Flutter app running as an Android app, as web, and in a tablet
layout**, each adapting to its form factor rather than being a separate build. Nothing
here is done yet; this is the direction, not a description of the code.

### Where it stands

`android/`, `web/` and `windows/` are scaffolded (no `ios/`). Only web has ever been
built or run. The one genuinely responsive piece is `SidebarNavigation`, which switches
on `MediaQuery.sizeOf(context).width`:

| Width | Rail |
|---|---|
| ≥ `expandedMinWidth` (1080) | 240px, label + icon, honours the collapse toggle |
| 700–1080 | 72px icon rail, toggle ignored |
| < `railMinWidth` (700) | 60px icon rail, tighter padding |

Navigation is never hidden, so there is no width at which the app becomes unusable. But
that is the *only* widget doing this — outside `dashboard_screen.dart`, no screen uses
`MediaQuery` or `LayoutBuilder` at all. Everything else is a fixed desktop layout that
merely gets narrower.

### What each target needs

**Tablet (~600–1080 logical px).** Cheapest of the three and the right first move,
because it forces the layout work the other two also need. The rail already collapses;
the content does not. Wide tables (Orders, Customers, Staff, Attendance, Payroll) need a
card/list fallback below a breakpoint, and the dashboard's multi-column panel grid needs
to reflow to one column. Pick the breakpoints once, put them next to
`expandedMinWidth` / `railMinWidth`, and reuse them everywhere rather than scattering
magic numbers.

**Android.** Three things block it, in order:

1. **`ApiService.baseUrl` defaults to a relative `/api`.** That is correct on web, where
   nginx proxies same-origin, and meaningless in an APK — there is no origin. Android
   builds need an absolute base URL via `--dart-define=API_BASE_URL=...`, and the
   emulator reaches a host machine at `10.0.2.2`, not `localhost`.
2. **There is no router.** `main.dart` switches on `AppProvider.currentNavIndex`, so the
   Android system back button has nothing to pop and will exit the app from any screen.
   This is the point at which the `go_router` migration stops being optional — see the
   Frontend section.
3. **Phone widths are below every breakpoint the app was designed for.** A 60px icon rail
   is wrong on a phone; that wants a bottom navigation bar or a drawer, which is a
   different navigation shell, not a narrower one.

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
