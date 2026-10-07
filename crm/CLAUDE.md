# CLAUDE.md — LaundryBill CRM clone

Working clone of `app.laundrybill.com` (a laundry / dry-cleaning shop CRM + POS).

**Stack is Flutter Web + Django REST Framework, deployed on Cloudflare.**

---

## Layout

| Path | What it is |
|---|---|
| `washnlaundrycrm/` | Flutter Web SPA — the entire frontend (web is the only target) |
| `backend/` | Django + DRF — the API origin (Render + Neon Postgres in prod, SQLite locally) |
| `cloudflare/api-proxy/` | Worker `washnlaundry-crm-api`: edge reverse proxy `/api/*` → Django |
| `cloudflare/rag-engine/` | Worker `washnlaundry-crm-rag`: chat, lead capture, 15-min cron |
| `scripts/deploy_cloudflare_pages.js` | Uploads `washnlaundrycrm/build/web` to Cloudflare Pages |
| `logo/` | Brand logo, shared with the separate marketing repo |

Screen-by-screen reference captures, the real app's bundles, design previews, Docker, Vercel,
and the Android/Windows scaffolds were removed on 2026-10-06 when the repo went
Cloudflare-only. They are recoverable from git history (parent of the cleanup commit on
`cleanup/cloudflare-only`).

---

## Running locally

```bash
cd backend && pip install -r requirements.txt
python manage.py migrate && python seed_db.py && python manage.py runserver 8000

cd washnlaundrycrm && flutter run -d chrome
```

`python seed_db.py` **wipes every table** and reseeds; it is the only source of demo data.
`DJANGO_DATABASE_URL` selects Postgres; unset means SQLite (it is deliberately not
`DATABASE_URL`, which is set machine-wide — see `~/CLAUDE.md`).

---

## Deployment — Cloudflare

| Target | Source | Ships via |
|---|---|---|
| CRM `app.washnlaundry.com` / `washnlaundrycrm.pages.dev` (Pages) | `washnlaundrycrm/` | build + `node scripts/deploy_cloudflare_pages.js` |
| Worker `washnlaundry-crm-rag` | `cloudflare/rag-engine/` | `npx wrangler deploy` there |
| Worker `washnlaundry-crm-api` | `cloudflare/api-proxy/` | `npx wrangler deploy` there |
| Django backend `washnlaundry-backend.onrender.com` | `crm/backend/` | Render auto-deploys on push to `main` (runs migrations) |
| Marketing `www.washnlaundry.com` | **separate repo** `abhishekkumarai/washnlaundry` | `pnpm cf:deploy` there |

```bash
cd washnlaundrycrm
flutter build web --release --dart-define=API_BASE_URL=https://washnlaundry-backend.onrender.com/api
node ../scripts/deploy_cloudflare_pages.js   # needs CLOUDFLARE_API_TOKEN
```

- A push never updates the frontend; there is no pre-push hook anymore. Deploy explicitly.
- `API_BASE_URL` is baked in at build time. Forget it and the bundle calls a relative `/api`
  on Pages, which 404s — every screen loads empty.
- Google Sign-In: also pass `--dart-define=GOOGLE_CLIENT_ID=...` (a Web OAuth client with the
  Pages/app origins as Authorized JavaScript origins). Without it only Demo Mode shows.
- Render settings are env-driven (`SECRET_KEY`, `DEBUG`, `ALLOWED_HOSTS`, `CORS_*`,
  `DJANGO_DATABASE_URL`) but default to insecure dev values. Free tier sleeps: the first
  request can take 15+ s — retry with a long timeout.
- Re-seeding production is destructive (`seed_db.py` wipes every table); point
  `DJANGO_DATABASE_URL` at the unpooled Neon URL for that one command only.
- DNS for `washnlaundry.com` is on Cloudflare: `app` is a proxied CNAME to
  `washnlaundrycrm.pages.dev`; apex and `www` are Worker custom domains on
  `washnlaundry-web`. MX and SPF records are untouched.

---

## Backend

Django 5 / DRF / SQLite, app label `api`. Everything is a plain `ModelViewSet` on a `DefaultRouter` — no pagination, no filtering. Auth is Google ID-token based (see **Roles and auth** below); it is **off until `API_AUTH_ENFORCED=True`**, so by default the API is still open.

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

Settings read `SECRET_KEY`, `DEBUG`, `ALLOWED_HOSTS`, `CORS_ALLOW_ALL_ORIGINS` and `CORS_ALLOWED_ORIGINS` from the environment, but **default to the insecure dev values** (`DEBUG=True`, a hardcoded key, `*` hosts, all origins). Production must set them explicitly — see Deployment.

---

## Frontend

Flutter Web, Material 3, `provider` for state, `fl_chart` for charts, `google_fonts` (IBM Plex Sans). Brand colour `#1A4FD6`, surface `#F8FAFC`.

**There is now a real router** (`go_router`, `lib/router.dart`). `AppProvider.currentNavIndex`/`setNavIndex` still exist and are still what every screen and the sidebar read for "which section is active" — routing is layered on top as a hybrid, not a replacement: each `GoRoute`'s builder defers a `setNavIndex` call (via a post-frame callback — calling it synchronously from `builder:` throws, since that runs during the build phase) and returns the screen. This kept the change from touching `SidebarNavigation`'s read path or any of the ~20 widget tests that pump a screen directly with no router ancestor.

- URLs, deep links, and browser back/forward all work — confirmed by signing into the real app.laundrybill.com and comparing behaviour directly.
- `/orders/:id` is a real per-record route (`router.dart`), matching the real app's Firestore-doc-ID URLs. It `watch`es `AppProvider` rather than `read`ing it, so a deep link hit before `loadDataFromBackend()` resolves shows a spinner that turns into the real order once the data arrives, rather than a false "not found". `OrdersScreen` no longer swaps its own body for `OrderDetailScreen` — `orders_screen.dart:39`'s old pattern is gone.
- Section navigation goes through `context.goSection(n)` (`lib/utils/navigation.dart`), a thin wrapper that looks `n` up in `AppProvider.routePaths` and calls `context.go(path)` — every former `setNavIndex(n)` call site was a same-shape one-line swap to this.
- `/settings` (index 13) is routed and enabled as of 2026-09-24. Of its vertical tab list only **Business profile** and **Credit categories** (`lib/widgets/credit_categories_panel.dart`) are built; the other tabs show "Not available yet". `?tab=<slug>` opens a specific tab — Credits' Add dialog links to `/settings?tab=credit-categories`. Below `contentWideBreakpoint` the 240px tab column becomes a chip row.
- Sidebar indices are still load-bearing magic numbers, now doubling as the vocabulary `AppProvider.routePaths` maps to URL paths — and must be unique: Credits was once given 14, Help's index, which lit both up. Credits is 15. Index 10 (`Apps`) and 12 (`Subscription`) are still flagged `disabled: true` and render a "Soon" chip; re-enabling one still means flipping `disabled` back to `false` in `sidebar_navigation.dart`, but now also means adding a route for it in `router.dart` rather than a `case` in `main.dart`.

Adding a screen now means: write it, add a `navItems` entry with a new index, add its path to `AppProvider.routePaths`, add a `GoRoute` in `router.dart`.

### Roles and auth (added 2026-10-07)

One Google login for everyone; the backend (`backend/api/auth.py`) verifies the ID token (`Authorization: Bearer`) against `GOOGLE_CLIENT_ID` and `GET /api/me/` returns the role:

| Role | Who | Gets |
|---|---|---|
| `owner` | email in `STAFF_EMAILS` env, or an ACTIVE `Staff` row with that email, `has_app_login`, and role Owner/Manager | everything |
| `staff` | any other ACTIVE `Staff` row with email + `has_app_login` | orders, new order, customers, scan; read-only catalogue/shop. Not payroll, reports, expenses, credits, staff, attendance, dashboard stats |
| `customer` | a `Customer` whose email matches | `/my/*` only: own orders, rate card, pickup form (`/api/customer/*`) |
| `unlinked` | valid Google account, no record | `/my/start` to sign up |

- `API_AUTH_ENFORCED` (default False) turns enforcement on in `IsStaff`/`IsOwner`/`IsOwnerOrStaffReadOnly`. Ship the Flutter app first, then flip it on Render. Set `STAFF_EMAILS` before flipping or nobody can get in.
- A customer typing a phone number the store already has creates an `EmailLinkRequest` (no OTP, so no auto-link); the owner approves in Django admin or `POST /api/link-requests/<id>/approve/`.
- Flutter: `AuthProvider.role` drives `router.dart`'s `authRedirect`; `ApiService.tokenProvider` attaches the token and refreshes once on 401. Staff form has a "Sign-in email" field (it sets `has_app_login`). Demo Mode is always `owner` and only works while enforcement is off.
- The same Flutter build is meant to serve customer.washnlaundry.com (role decides the view); the old Next.js `customer-web/` is kept until that cutover is verified.

### Email + password sign-in (added 2026-10-07)

Alongside Google, the login screen's Email/Password and Sign In / Create Account tabs are real (`backend/api/password_auth.py`, `lib/screens/auth_link_screens.dart`).

- Accounts are Django `User` rows (username = lower-cased email). They stay **inactive until the emailed `/verify?token=` link is clicked**: roles are matched by email, so an unverified signup must never get one. `forgot-password` emails a `/reset?token=` link (Django's `PasswordResetTokenGenerator`, 1 h, single use); a reset also verifies the email and signs out old sessions.
- Session = `Authorization: Bearer app.<signed>` (30 days, `django.core.signing`, tied to the password hash); Google ID tokens still work. Both resolve to the same roles in `auth.py`.
- Login/signup/forgot are rate limited (failures only for login). Wrong password and unknown email return the same 401.
- **Needs `SECRET_KEY` set in the environment** (`PASSWORD_AUTH_ENABLED` is off on the public default key: tokens would be forgeable), `RESEND_API_KEY`, and, for mail to reach anyone but the Resend account owner, a verified sending domain + `AUTH_EMAIL_FROM`. Emailed links go back to the site the request came from if it is in `APP_ORIGINS` (default `https://app.washnlaundry.com,https://customer.washnlaundry.com`; `http://localhost:<port>` also accepted while `DEBUG`), otherwise to `APP_BASE_URL` (default: `http://localhost:5055` when `DEBUG`, else the first `APP_ORIGINS` entry). Set `APP_ORIGINS` / `APP_BASE_URL` per environment (Render: the two prod URLs; local: nothing needed).
- Demo Mode stays available in every build (a build can hide it with `--dart-define=ALLOW_DEMO=false`).

### Authentication (login screen)

`/login` (`lib/screens/login_screen.dart`), via `AuthProvider`, matches the real app's route. The screen itself is unchanged; Google sign-in now also yields a server-verified role (see above). Demo Mode remains a client-side-only bypass and is kept on purpose.

**The auth gate is always on** — `router.dart`'s `redirect` sends any signed-out visit to `/login` regardless of whether Google Sign-In is configured; there is no zero-config bypass. Two independent ways to satisfy it:

- **Google Sign-In** (`google_sign_in` ^7), when `GOOGLE_CLIENT_ID` is set — see below.
- **Demo Mode** (`AuthProvider.signInAsDemo`), always available. The login page's layout matches the real one (Email/Password fields, Sign In/Create Account tabs, "Forgot password?"), but this clone's Django backend has no User/password model to check credentials against, so both tabs' primary button — and the separate "Try Demo Mode" button shown when Google isn't configured — call `signInAsDemo` rather than actually authenticating anything typed into the form. "Forgot password?" and "Sign in with mobile number instead" are rendered for layout parity only: the former shows a "not available in this demo" toast, the latter is greyed out and inert (no tap handler at all).

Either path persists the same way (`SharedPreferences`, checked by `AuthProvider._init()` on every reload) and both end via the same `AuthProvider.signOut()`, so `flutter run` **always** land on `/login` first now — Demo Mode is the fast way through it, not a fallback bypass.

Google Sign-In needs `--dart-define=GOOGLE_CLIENT_ID=your-id.apps.googleusercontent.com` — a **Web application** OAuth Client ID from Google Cloud Console, with `http://localhost:<port>` (whatever `--web-port` you run with) and the deployed app origin as Authorized JavaScript origins. Leave Authorized redirect URIs empty — Google Identity Services signs in via its own rendered button and a JS callback, not a server redirect. **With no `GOOGLE_CLIENT_ID`, the login page simply omits the Google button and the "OR" divider** and Demo Mode is the only path in — the gate itself does not change.

The GIS SDK only allows signing in through UI it renders itself — a programmatic `authenticate()` call throws on web. `lib/utils/google_signin_button.dart` conditionally exports a web implementation (`google_sign_in_web`'s `renderButton`) or a plain button wired to `AuthProvider.authenticate()` everywhere else, picked via `if (dart.library.js_interop)` — the same conditional-import shape this file already calls for around `dart:io`, mirrored for a web-only dependency instead of a non-web-only one. `google_sign_in_web` fails to *compile* (not just run) off web, including on the plain-VM target `flutter test` uses, which is why this is a real conditional export and not a `kIsWeb` runtime check.

### Data flow — read this before touching a screen

`ApiService` (`lib/services/api_service.dart`) exposes exactly four calls: `fetchDashboardStats`, `fetchOrders`, `fetchGarmentItems`, `createOrder`. Base URL is `String.fromEnvironment('API_BASE_URL')` defaulting to a relative **`/api`** — same-origin, which is what lets one bundle work locally against a dev server. The Cloudflare deploy overrides it at build time with `flutter build web --dart-define=API_BASE_URL=...` (the Render URL).

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

Extracted from the real app's JS bundle. This is the authoritative feature surface.

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

## Conventions

- Indian context throughout: ₹, phone `+91`, GSTIN on the shop, `Asia/Kolkata`, Bengaluru addresses in seed data.
- Seeded shop is `washing`, owner `AK` —.
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
   of detail this file already keeps.
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
