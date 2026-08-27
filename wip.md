# WIP — session of 2026-08-12

Working notes on the LaundryBill CRM clone. The previous session's notes
(2026-08-11) are in git history at `f03a16c`.

---

## What this session closed out

An audit of every remaining hardcoded value in `lib/`. The finding that shaped
the session: **`AppProvider` and `ApiService` are clean** — no seed lists, no
fallback fixtures — and every *screen* is wired. What was left is narrower and
worse than a screen holding a mock list:

> the dashboard widgets fetch real data and then throw it away in favour of an
> invented answer.

`/api/dashboard/stats/` has always returned `revenue_series`, `orders_today`,
`revenue_today`, `ready_for_pickup`, `overdue`, `customers_total`,
`customers_new_today`, `orders_today_change`, `revenue_today_change` and
`pipeline`. `loadDataFromBackend` has always fetched them. The widgets read
almost none of it. **Nothing in this session needed a backend change.**

---

## The three that were not cosmetic

### The revenue chart was entirely fabricated

`revenue_chart_card.dart` generated its bars as

```dart
final val = index == 13 ? maxRevenue : (index % 3 == 0 ? 40.0 : 0.0);
```

— a made-up ₹40/₹0 sawtooth — and labelled the x-axis days 16–29 regardless of
the date. The tooltip repeated the offset (`'Day ${group.x + 16}'`).

It now plots `revenue_series`. The axis follows each point's real `day`, the
tooltip shows the point's real date and amount (the rod height is floored at 4
for empty days, so reading the amount back off the bar would have lied), the
headline is the window total rather than one day's figure, and `maxY` is the
series peak. An empty series renders a message instead of a chart of zeros.

### The KPI cards labelled "today" were all-time totals

`ordersToday` was `_orders.length`. `revenueToday` was the sum of `totalAmount`
over **every order ever**, which also made it disagree with the Revenue
Analytics panel directly below it on the same screen. `customersToday` was the
count of distinct phone numbers across all orders, under a card titled
"Customers".

All five now read `_stats`, with the local derivation kept **only** as a
pre-fetch fallback (and for tests that seed orders without stats).
`customersToday` is renamed `customersTotal` to match what it counts.

`'+1 new today'` was a literal — it always said +1. Both `'— vs yesterday'`
subtexts were placeholders. They now use `customers_new_today` and the two
`*_change` values, rendered through the existing `formatPercent`, which keeps
the dashboard's rule that **`—` and `0%` mean different things**.

### Scan opened the wrong customer's receipt

```dart
orElse: () => provider.orders.isNotEmpty ? provider.orders.first : provider.orders.first,
```

A mistyped order number silently opened someone else's bill. The `orElse` was
also a tautology that threw on an empty list. A miss now reports a miss.

Two other lies on that screen: the "Open scanner" button ignored the camera and
opened `orders.first`'s receipt — it is now **disabled**, following the
precedent `reports_screen.dart` set with Print/Export — and the input hint
advertised `LB-1001`, a format the backend has never issued. It now builds the
example from the shop's own `order_prefix`.

---

## Identity: the literals that matched the seed

`'AK'`, `'washing'` and `'Admin'` were hardcoded in the sidebar (on *every*
screen), the top header and New Order. They happen to match the seeded shop,
which is exactly why nobody noticed they were literals. All now read
`owner_name` / `name` from `provider.shop`, via a shared `initialsFor` helper
in `panel_card.dart` so the three call sites cannot drift.

The widget test seeds a **multi-word** owner deliberately: with `owner_name:
'AK'` the derived initials are also `'AK'`, so the assertion would pass even if
the value were still hardcoded.

### The "Pro · Active" badge is deleted, not wired

It was the last surviving fragment of the plan-tier removal. `Shop.plan` went
in migration `0008`; **there are no tiers**, so the badge measured nothing.
Removed rather than given a data source.

`TopHeader` also hardcoded the title `'Dashboard'` — on Expenses and Payroll
too. It now takes the title as a required parameter.

### Receipts printed a fallback shop

`ReceiptDialog` already accepted `shop` and degraded gracefully, but **three of
its four call sites omitted it**, so those receipts printed `'LaundryBill'`
with no address or phone. The parameter is now `required` (still nullable — the
shop may not have loaded). Making it required immediately caught both stale
call sites and two test call sites, which is the point.

---

## Two things worth carrying forward

### A backend inconsistency this surfaced, deliberately not fixed

`dashboard_stats` computes `revenue_today` from **`paid_amount`** (collected)
but `revenue_series` from **`total_amount`** (billed). So the chart's last bar
will not equal the "Revenue today" card, and no amount of frontend work
reconciles that. Changing either alters API semantics, so it is recorded rather
than decided. Pick one basis for both.

### Suites at the end of the session

**Django 160 green** (was 149), **Flutter 231 green** (was 202), `flutter
analyze` error- and warning-free — 38 remaining issues, all `info`-level lint.

### The test toolchain runs out of memory, and it looks like a code bug

A killed `flutter test` left orphaned `dart.exe` processes behind; the next run
died with `zone.cc: 96: error: Out of memory` and a multi-hundred-line JIT
register dump that reads like a crash in the widget under test. It is not —
`taskkill //F //IM dart.exe` and a rerun passed cleanly. Also: **`flutter test`
piped into `tail` produces no output at all until the pipeline ends**, which
looks identical to a hang. Redirect to a file instead.

---

## Second pass: the rest of the audit

The out-of-scope tiers below were then done too, along with the two items that
had been left for a decision.

### The revenue basis, decided

`dashboard_stats` computed `revenue_today` from **`paid_amount`** but
`revenue_series` from **`total_amount`**, so the chart's last bar could never
equal the KPI card beside it. The series now sums `paid_amount`: the dashboard
speaks one language, **collected**. Pinned by a test that bills 1000 and
collects 700 and asserts the last bar reads 700.

### Attendance no longer invents a paid day

`_save` sent `_pending[id] ?? saved[id] ?? 'PRESENT'` for the whole roster, so
pressing Save Register without marking anyone recorded every staff member as
**present and paid**. That directly contradicted the care taken everywhere else
on that screen, where an unmarked person renders as "not marked" *because*
defaulting them would invent a day. Only explicitly marked staff are sent now,
and an untouched register reports "Nothing to save" instead of silently filling
itself in.

### Vocabularies are served, not mirrored

New `GET /api/meta/` returns `{value, label}` lists for order/payment/delivery
statuses, sources, pricing units, payment methods, expense categories and
attendance states. `PaymentMethod` and `ExpenseCategory` are now real
`TextChoices` — `payment_method` had been a free-text CharField with **no
choices at all** while the client carried three divergent lists (New Order
offered three methods, Expenses and Payroll four in different orders). New
Order now offers Bank Transfer, which it had been silently missing.

The provider keeps the four model-declared methods as a fallback so a failed
`/meta/` fetch cannot empty every dropdown.

### Shop settings replace client constants

`Shop` gained `express_multiplier`, `default_daily_wage`, `default_staff_role`,
`currency_symbol` and `locale`; `GarmentItem` gained `image_url`
(migration `0009`). The 1.5x express surcharge, the 600/'Washer' new-hire
defaults and the twelve Unsplash URLs keyed by item *name* were all Dart
constants — meaning no shop could charge, pay or photograph anything else, and
renaming an item lost its picture.

Images now come off the catalogue row, with the icon treatment as the fallback
rather than the only option. 17 of the 79 seeded items carry one; the rest
render the icon, which is what a real shop sees before it uploads its own.

### Currency

`lib/utils/money.dart` holds the symbol and locale, and `AppProvider` is its
single writer whenever the shop loads. Deliberately a static rather than
something threaded through `BuildContext`: the symbol appeared inside ~46
`'₹${...}'` interpolations in helper methods with no context to hand. `Money.reset()`
exists because the statics outlive a provider and would otherwise leak between
tests.

### The seed was lying about time — the biggest find of the pass

`Order.created_at` and `Customer.created_at` are `auto_now_add`, so **every
seeded order and customer landed on today** no matter what its timeline said.
Every dashboard and report query filters on `created_at`. Consequences:

- "Orders today" was always the entire seed (15), which is *also* why the
  KPI-versus-order-list bug was invisible by inspection.
- The 14-day revenue chart was a single bar.
- "+N new today" was every customer the shop had ever had.

Orders are now spread evenly across the 14-day window (a queryset `update()` is
the only way past `auto_now_add`) and customers are backdated nine days apart.
The dashboard now reads **2 orders today against a 15-order list** — the
divergence is finally visible in a browser, not just in a test.

### Verified in Chrome, at last

The end-to-end pass that had been outstanding for three sessions is done, built
with `--dart-define=API_BASE_URL=http://127.0.0.1:8000/api` and served from
`build/web`. Confirmed against live seeded data: Orders today 2 (not 15);
₹308 collected with green ▲100% and red ▼24.9% deltas; "+2 new today"; the
revenue chart showing twelve varying bars on an axis reading **30, 31, 1 … 12**
— crossing the July→August boundary, which is the clearest possible proof the
old hardcoded "days 16–29" axis is gone; the sidebar reading `washing` / `AK`
from `/api/shops/`; no plan badge anywhere; catalogue photos on the Services
grid; and all four payment methods on New Order.

One browser-driving note: **the mouse wheel does not scroll the Flutter
canvas** through the automation tools. `left_click_drag` does, because
`AppScrollBehavior` puts the mouse in `dragDevices`.

---

## Open items

### Carried over, still not addressed

- **No router.** `main.dart` still switches on `AppProvider.currentNavIndex`.
  Still the single highest-value refactor, and still what blocks Android.
- **Order number prefix.** Ours derives `WASH-` from the shop name; the live
  app shows `WA3P-00002` from the same name `washing`. Different derivation.
- **Sidebar shape.** Live had 8 items at capture, ours has 14. Still an open
  question, not a known divergence — re-capture before treating it as one.
- **Settings, Apps and Subscription stay disabled.** `SettingsScreen` is still
  unrouted dead code.

### Left from this session's audit

The hardcoded-value work is finished; what remains from the audit is not about
hardcoded data:

- **`SettingsScreen` tabs 1–7 render nothing.** Tax & currency, Bank details,
  Operations and Preferences are advertised in the sub-nav and inert — while
  `Shop` now carries *everything they would need*: `tax_rate`, `pan`, the four
  bank fields, `upi_id`, the two buffer fields, and this session's operating
  rules and currency. The data exists; only the form is missing. And the screen
  is still unrouted, so building it means re-enabling index 13 first.
  Relatedly, **`tax_rate` is never applied to an order total anywhere.**
- **Fake success toasts.** `order_detail_screen.dart` reports "WhatsApp receipt
  sent", "Sent to the printer" and "Status shared on WhatsApp" for operations
  that never happen. The sign-out snackbar has no auth layer behind it. These
  are the last remaining places the app claims something it did not do.
- **Unconsumed endpoints.** Customers can be created but never edited or
  deleted; expenses are append-only in the UI; `GET /salary-payments/` and its
  filters are never called, so payment *history* is never shown;
  `ApiService.fetchOrder` has zero callers.
- **The item card's image box collapses in New Order.** Pre-existing layout:
  the `Expanded` holding the art gets almost no height in the product grid, so
  neither the photo nor the icon is really visible there. Services renders both
  correctly. Worth a look when the grid is next touched.
- **A couple of seeded Unsplash URLs are dead** and fall through to the icon —
  harmless, and it does demonstrate the fallback works, but the demo would look
  better with live ones.

Our Attendance, Payroll, Expenses and Reports screens also remain **invention,
not clones** — nobody has captured them from the live app yet. That is now the
highest-value outstanding work, and the routes are reachable.

---

## Session of 2026-08-19 — verification pass

Asked to confirm the app still works and still lines up with
app.laundrybill.com. Full pass: `python manage.py test` (160/160), `flutter
test` (231/231 going in), `flutter analyze` (clean, the same 38 info-level
lints), then a live click-through of a fresh seed against `LIVE_AUDIT.md`.

**The captured screens hold up well.** Dashboard, Orders, Order detail,
Customers, Services and New Order all match the spec closely — including
things `LIVE_AUDIT.md` had listed as *missing* (Store Health, Revenue
Analytics' collection progress, Needs attention, Order channels, Staff
attendance), which turn out to already be built. Scan's documented fixes hold:
camera is honestly disabled, a miss reports "No order found" rather than
opening a stranger's receipt.

**Two real bugs found and fixed**, both in things `LIVE_AUDIT.md` never
covers because it's a spec of the *real* app, not a lint pass on ours:

- `expenses_screen.dart` carried its own `_methodLabel` helper that
  title-cased the raw payment-method value, turning `UPI` into `Upi`. The
  correct acronym-safe version already existed twice over — once in
  `PaymentMixModel.methodLabel` (Reports) and once as `provider.paymentMethods`
  (Payroll's dropdown) — Expenses was the one place nobody had pointed at
  either. Now calls `provider.paymentMethods`, matching the pattern Payroll
  already used. Covered by a new test in `expenses_test.dart`.
- Dashboard's Revenue Analytics card showed amounts without thousands
  separators (`₹14941`) while Reports showed the same kind of figure grouped
  (`₹14,941`) — `formatRupees` (shared by the KPI row, the revenue chart and
  Revenue Analytics) called `Money.format` instead of `Money.grouped`. Fixed
  at the one shared helper in `panel_card.dart` rather than each call site.
  `dashboard_stats_test.dart`'s two currency assertions updated to match.

**Asked to check the Django models against the Flutter UI for drift.** Most of
it is genuinely in sync — `serializers.py` exposes `fields = '__all__'`
everywhere, and the Flutter model classes read essentially every field that
has anywhere to render. Three places don't:

- **`OrderItem.status` is parsed and carried (`OrderItemModel.status`) but
  never rendered.** The order detail Items list shows name / category /
  service / qty × price / line total — no per-item badge. `LIVE_AUDIT.md`'s
  capture explicitly has one (`DELIVERED` next to a line item), so this is a
  live-app gap, not just a nice-to-have. Note CLAUDE.md's own text is stale
  here — it says *"OrderItem is missing a per-item status"*, but the field
  exists now; only the UI never caught up to it.
- **`Order.delivery_charge` has no write path anywhere in the app.** New
  Order's checkout payload never sets it, and the order detail Edit dialog
  (`customer_name`, `customer_phone`, `delivery_type`, `scheduled_date`) does
  not offer it either — it's display-only (`order_detail_screen.dart:380-382`).
  Every order actually created through the app will show ₹0 delivery no
  matter the delivery type; the "Delivery ₹50" line seen during the walkthrough
  came from seed data, not from anything a user can do.
- **New Order always creates `delivery_type: STORE_PICKUP`** — `_checkout`
  in `new_order_screen.dart` hardcodes it. `delivery_type` and
  `scheduled_date` are only reachable afterward, through order detail's Edit
  dialog. Not a crash, just a workflow gap: there's no way to bill a Home
  Pickup / Home Delivery / Online order directly at checkout.

All three are now fixed:

- `order_detail_screen.dart`'s `_itemRow` renders a `StatusPill` next to each
  item's name, reusing the same widget the order-level pill already used —
  no new styling to keep in sync.
- New Order's right rail gained a **Delivery** selector (Store Pickup / Home
  Pickup / Home Delivery / Online, same `DeliveryType.labels` the Edit dialog
  already draws from) above Payment. Picking a carried type adds a ₹50 flat
  fee — the same rule `seed_db.py` already encodes for HOME_DELIVERY/ONLINE —
  as its own line between Subtotal and Total, and the checkout payload now
  sends real `delivery_type`/`delivery_charge` instead of a hardcoded
  Store Pickup with an omitted charge. Verified end-to-end in a browser: a
  Home Delivery order billed ₹15 + ₹50 = ₹65 and round-tripped correctly to
  order detail.

Both covered by new tests (`order_detail_test.dart` "Items", `new_order_test.dart`
"picking a delivery type other than pickup adds the flat fee"). Full suite
after: Django 160/160, Flutter 234/234, `flutter analyze` clean (same 38
info-level lints).

Deliberately left alone: the Edit dialog can still change `delivery_type`
after the order is placed without touching `delivery_charge` or
`total_amount` — recomputing totals on an already-placed order is a bigger,
riskier change (does `paid_amount` also move? what if it already shipped?)
than "give the field a write path," so it's still a known gap, just a smaller
one now that creation is fixed. `GarmentItem.icon` is also unused end to end
(seed never sets it past the model default, Flutter never reads it) but both
sides ignore it *consistently*, so it's dead weight rather than drift — left
alone.

---

## Google Sign-In

Added `/login`, matching the real app's route. Scoped deliberately narrow —
**UI-only**, decided up front rather than discovered partway through:

- Gates which screen `main.dart` shows (`LoginScreen` vs the existing switch),
  the same way the real app swaps `/login` for `/dashboard` once
  `onAuthStateChanged` fires.
- Does **not** touch the Django API, which stays exactly as documented: no
  auth, no permissions. A real, server-verified session — a User/Shop-owner
  model, ID token verification, a required session on API calls — is a
  separate, larger change than this.
- **A build with no `GOOGLE_CLIENT_ID` skips the gate entirely** and behaves
  exactly as before this session, checked by rebuilding and confirming
  `docker compose up` / `flutter run -d chrome` with no dart-define still
  lands straight on the dashboard. This was the point, not an afterthought —
  the project's zero-config promise had to survive adding auth.

### The one real wrinkle: `google_sign_in_web` doesn't compile off web

First pass gated the web-only button behind a `kIsWeb` *runtime* check inside
one shared widget. `flutter test` failed at the `JSString`/`JSObject`
compile step, not at runtime — `google_identity_services_web`'s
`dart:js_interop` types apparently don't exist on the plain-VM target
`flutter test` (and every non-web build) uses, so importing the file at all
was the problem, not calling into it. `kIsWeb` can't prevent that; it's a
runtime value, and this was a compile-time failure.

Fixed with a real conditional export —
`lib/utils/google_signin_button.dart`:

```dart
export 'google_signin_button_stub.dart'
    if (dart.library.js_interop) 'google_signin_button_web.dart';
```

— the same shape CLAUDE.md already documents for `dart:io`, mirrored for a
web-only dependency instead of a non-web-only one. Both files export a
`googleSignInButton({required VoidCallback onPressed})`; the web one ignores
`onPressed` (GIS reports sign-in through `AuthProvider`'s
`authenticationEvents` listener, not a callback — the SDK doesn't allow a
custom button that calls `authenticate()` on web at all) and renders Google's
own button via `google_sign_in_web`'s `renderButton`; the stub wires
`onPressed` straight to `AuthProvider.authenticate()`, which works
everywhere `supportsAuthenticate()` is true.

### Verified

- `flutter build web --dart-define=GOOGLE_CLIENT_ID=<fake-id>` compiled and,
  in a browser, rendered Google's actual pill-shaped "Sign in with Google"
  button (GIS loaded and ran `attemptLightweightAuthentication` cleanly even
  against a fake client ID — it only fails on an actual sign-in attempt).
  Console showed nothing but Google's own FedCM-migration notice.
- Same build with `GOOGLE_CLIENT_ID` omitted: straight to Dashboard, no
  login screen, confirming the skip-when-unconfigured path.
- `docker-compose.yml`'s frontend build now takes `GOOGLE_CLIENT_ID` as a
  build arg (default `""`, so `docker compose up --build` is unaffected
  unless a `.env` file sets it) — `docker compose config` checked to confirm
  it resolves to an empty string by default rather than erroring.
- Django 160/160, Flutter 236/236 (two new: `AuthProvider`'s unconfigured
  state, `LoginScreen` rendering), `flutter analyze` clean (38 info-level
  lints, unchanged).

### Left for whoever wires real auth later

- Sign-out is real (`AuthProvider.signOut()`) when configured, and falls back
  to the old fake snackbar when not — `sidebar_navigation.dart`'s `signOut()`
  branches on `AuthProvider.isConfigured`.
- Nothing displays the signed-in Google account anywhere (name, email,
  avatar) — the sidebar footer still shows the *shop's* `owner_name`, which
  is separate data (who the shop says its owner is, not who's currently
  authenticated) and was left alone on purpose rather than conflating the two.
- GIS sessions aren't renewed by the SDK itself (per `google_sign_in_web`'s
  own README) — `attemptLightweightAuthentication` on each app start is doing
  the same job the real app's slow "auth restore" does, but there is no
  server session behind it to expire or revoke.

---

## `washnlaundrycrm/wip.md` punch list — implemented

The user's own 6-item punch list (separate file, `washnlaundrycrm/wip.md` —
not this one) got a full pass: verified 4 of the 6 as already fixed by the
Antigravity diff (live-tested, not just read), then implemented the other 2
plus a `baseUrl` regression found along the way. Full detail — including the
side-by-side comparison against the real app.laundrybill.com that shaped the
approach — is in the approved plan at
`C:\Users\abhi3\.claude\plans\for-point-6-check-parsed-puddle.md`. Summary:

### Already fixed (live-verified, not touched further)
Recent activity click-through, refresh persistence (via Demo Mode, sidestepping
the always-succeeds Google lightweight-auth in the test browser), the Services
edit icon/three-dot menu, and the Staff sub-tabs (Active/Inactive/App
Logins/Delivery Agents).

### Item 4.2 — New service category fields, fixed
Signed into the real app and opened "New service category" there: it's
**Name / Active / Turnaround Days** — no icon picker. Ours had Name / Service
Icon / Active. Added `GarmentCategory.turnaround_days` (migration `0010`,
default `1`, matching what the real Ironing category showed), threaded it
through `GarmentCategoryModel`, and swapped the icon dropdown for a Turnaround
Days field in both the Add and Edit category modals in `services_screen.dart`
— removing `_iconLabels`, which had no other caller once the dropdown was
gone. Titles also corrected to match the real app ("Add Service" / "Edit
Service", not "New Service" / "Edit Service Category").

### Point 6 — the `go_router` migration
The real fix, not a patch — confirmed necessary by actually comparing against
the live app rather than guessing: placed a real test order
(`#WA3P-00004`) and watched `/new-order` stay put through checkout, then
watched `/orders` and `/orders/<firestore-id>` update the address bar in both
directions as real navigation happened. That ruled out a lighter "just make
the initial load work" patch — the real app is a genuine two-way router down
to individual records, so ours needed to be too.

- `AppProvider.currentNavIndex`/`setNavIndex`/`routePaths` all **kept** —
  `go_router` (`lib/router.dart`) is layered on top as the URL's source of
  truth, not a replacement. Each `GoRoute`'s builder keeps `currentNavIndex`
  in sync as a side effect. This is what kept `SidebarNavigation`'s read path,
  and every test that pumps a screen without a router ancestor, untouched.
- **Real bug hit and fixed along the way**: calling `setNavIndex` (which
  calls `notifyListeners()`) straight from a `GoRoute.builder` throws —
  `builder:` runs during the widget build phase, and Flutter doesn't allow
  marking a widget dirty mid-build. Every route defers the call via
  `WidgetsBinding.instance.addPostFrameCallback`. This bit the *test* helper
  too (`test/support/router_test_utils.dart`) before it was understood to be
  a production issue, not a test-only one — worth remembering if a future
  route needs to notify something from its builder again.
- `/orders/:id` (`lib/router.dart`) `watch`es `AppProvider` rather than
  `read`ing it, so a deep link hit before `loadDataFromBackend()` resolves
  shows a spinner that turns into the real order once data arrives, instead
  of a false "not found." Verified live: hard-reloaded a direct link to an
  order's UUID and watched the spinner resolve into the real detail screen.
  A genuinely bad ID resolves to "Order not found" / "Back to Orders" only
  once loading has actually finished.
- `OrdersScreen`'s old swap-its-own-body pattern is gone —
  `_selectedOrderForDetails` and `AppProvider.openOrderDetail`/`selectedOrder`/
  `clearSelectedOrder` are deleted. Both row-tap call sites
  (`orders_screen.dart`, `recent_activity_card.dart`) now call
  `context.go('/orders/${order.id}')` directly.
- New `lib/utils/navigation.dart`'s `context.goSection(n)` replaced every
  `setNavIndex(n)` call site — same shape, so it was a mechanical one-line
  swap at each of the ~10 sites.
- Landed as two phases matching the plan: section routes + auth gate first
  (order detail still worked via the old body-swap), then the real
  `/orders/:id` route and the cleanup it enabled, second — each independently
  test-green.

### Live-verified end to end
Direct navigation to `/new-order`, `/orders`, and `/orders/<id>` all land
correctly with the URL intact (previously all three reset to `/`). Clicking
"Customers" in the sidebar updates the address bar to `/customers` in real
time; browser back then correctly returns to `/orders`. All three
`/orders/:id` states — loading spinner, resolved detail, not-found — checked
by hand against real and fake IDs.

### Suites after
Django 160/160, Flutter 237/237 (one new test locking in the Turnaround
Days fix), `flutter analyze` clean at the same 41 info-level lints as before
this pass (no errors, no new warnings).

### Left alone, deliberately
- `ApiService.baseUrl`'s regression (auto-hardcoding `127.0.0.1:8000` on any
  `localhost`/`127.0.0.1` host with no explicit dart-define, reintroducing the
  exact anti-pattern a deleted comment in that file used to warn against) was
  fixed by gating the convenience behind `kDebugMode` instead of a runtime
  host sniff — so it can only ever affect a `flutter run` dev session, never
  a `flutter build web` (debug mode is always false there), release, or
  Docker output.
- `SettingsScreen` stays unrouted — adding `/settings` to the new router was
  explicitly out of scope for this migration, per the plan.

## Point 3 fixed — Timeline is now a real backend audit log

The "Timeline & Audit Log" / "Auto Recorded" labeling (from the Antigravity
diff) used to be cosmetic: `TimelineEntry.subtitle` existed but nothing
populated it, and the panel only ever showed the 7 fixed per-stage
timestamps `Order` already carried. Asked to pick a scope, chose the real
backend audit log over rolling the label back.

**New model** `OrderAuditLog` (`backend/api/models.py`, migration `0011`):
one row per recorded change — `order` FK, `status` (blank for non-stage
events), `title`, `detail`, and a settable `created_at` (not
`auto_now_add`, so seed data can backdate a plausible history the same way
`Expense.date` already does).

**Write points**, each producing one entry:
- `OrderSerializer.create` — the opening "Placed" entry.
- `Order.mark_status` (now takes an optional `note`) — every status
  transition, carrying the same note the Update Status dialog already
  collects.
- `OrderViewSet.payment` — "Payment Collected", with the amount and the
  resulting payment status in `detail`.
- `OrderViewSet.perform_update` (new) — diffs `customer_name`,
  `customer_phone`, `delivery_type`, `scheduled_date` and `notes` before vs.
  after a PATCH and logs a single "Order Updated" entry listing what
  changed, so the Edit Order dialog is covered too.

`seed_db.py` backfills a matching stage-by-stage trail per seeded order
(`bulk_create`, backdated to line up with the existing `STATUS_TIMESTAMP_FIELD`
stamps) so the panel has real content on a fresh seed instead of an empty
state.

**Frontend**: `TimelineEntry` gained a `fromJson` factory; `OrderModel`
gained an `auditLog` field parsed from the new `audit_log` array the
serializer now sends. `OrderModel.timeline` now returns real `auditLog`
entries (sorted oldest-first) instead of being derived from
`stageTimestamps` — `stageTimestamps` itself is untouched and still drives
the step bar. Live-verified against a real backend on port 8010: fetched a
seeded order's `audit_log`, then exercised `status` (with a note),
`payment`, and `PATCH` in sequence and confirmed each produced the expected
entry with correct `detail` text.

### Suites after this pass
Django 160/160 (unchanged pass rate, model/view changes covered by existing
`OrderTimelineTests`), Flutter 237/237, `flutter analyze` still the same 41
info-level lints, no new errors.

## Also added: `docker compose` seeding gotcha, documented in CLAUDE.md

`backend/Dockerfile`'s `CMD` only runs `migrate --noinput`, never `seed_db.py`.
"`docker compose up --build` is genuinely the whole command" was only true in
practice because `db.sqlite3` is bind-mounted, so a machine that had already
run local dev once had a seeded file sitting there for Docker to reuse. A
genuinely fresh clone gets a migrated-but-empty shop. Documented in
`CLAUDE.md`'s "Running it" section with the fix (`docker compose exec backend
python seed_db.py`, or `python seed_db.py` before ever starting Docker).
Confirmed live: `docker compose up --build` against the already-seeded host
db came up with 15 orders and a working `/api/orders/` proxy through nginx.

## Point 1 fixed — Recent activity's "broken alignment" was a real RenderFlex crash

The user re-flagged `washnlaundrycrm/wip.md` point 1 ("alignment... needs
attention") as still not done after an earlier pass had marked it fixed on
the strength of a live click-through test alone — alignment itself was never
actually exercised with real order data. This time: browser automation could
scroll the real app.laundrybill.com tab fine but was a no-op against our
Flutter build's canvas across ~10 attempts (wheel at multiple
coordinates/amounts, Page Down, End, drag, window resize) — a tooling
limitation, not a rebuttal of the bug report. Switched to a Flutter widget
test rendering `RecentActivityCard` directly with real `OrderModel` data,
which had **zero** prior test coverage anywhere in the suite.

That surfaced the real bug immediately: `_headerRow()`/`_dataRow()` in
`recent_activity_card.dart` wrapped the CUSTOMER column in
`Expanded(child: Text(...))` inside a *horizontally-scrolling*
`SingleChildScrollView` — which hands its child unbounded width, and
`Expanded` cannot compute a flex share of unbounded space. Flutter threw
`RenderFlex children have non-zero flex but incoming width constraints are
unbounded` on every row, every frame (23 exceptions in the first captured
run) — exactly what "left alignment is broken" looks like when the renderer
swallows a RenderFlex error per-frame instead of crashing the app outright.
A second, smaller bug in the same widget: the STATUS pill's label had no
overflow handling and clipped for longer labels ("Out for Delivery").

**Fix**: swapped the CUSTOMER `Expanded` for a fixed-width
`SizedBox(width: 170)`, matching every other column in the table (all were
already fixed-width — CUSTOMER was the only flex one), and removed the
`ConstrainedBox(minWidth: 620)` that had papered over the underlying
constraint problem without fixing it. Wrapped the STATUS label in
`Flexible(... overflow: ellipsis)`. Added
`test/recent_activity_card_test.dart` — asserts zero layout exceptions, that
the CUSTOMER column's left edge matches between the header and every data
row (the actual "left alignment" contract), and that the longest real status
label renders without overflow. Rebuilt the PNG-capture approach twice
(direct `toImage()`, then `tester.runAsync()`-wrapped) to actually *see* the
before/after — both hung indefinitely in this environment (a `flutter test`
image-encoding hang, unrelated to the widget code) and were abandoned in
favor of the geometry-assertion test above, which is more rigorous than a
screenshot anyway since it survives future refactors.

Full Flutter suite: 238/238 (237 + the new test). `flutter analyze`: 46
issues, same baseline plus 5 new `prefer_const_constructors` infos in the new
test file — no errors, no new warnings elsewhere.

Docker rebuilt afterward (`docker compose up --build`) so the running
containers serve this fix plus the earlier `OrderAuditLog` work — both had
been sitting stale in the containers since before either fix landed.

While reviewing `washnlaundrycrm/wip.md` for this, found the user had
directly edited it with new annotations. Both are now fixed:

## Point 5.1 fixed — Staff KPI cards were a second, redundant set of filters

`5.1` now adds *"Keep the above filter by click but remove the below ones"*.
`staff_screen.dart` had two separate controls doing the same job: the
sub-tabs bar (All Staff / Active / Inactive / App Logins / Delivery Agents,
the "above" one) and, below it, 4 of the 5 KPI stat cards *also* wired with
`onTap: () => setState(() => _selectedTab = N)` — a second, undocumented way
to change the filter, with no visual indication either control was linked to
the other. Removed the four `onTap` lines from the KPI card row (`onTap` on
`_buildKpiCard` was already optional, so this is a pure deletion — no
signature change). The cards are now purely informational stats; only the
sub-tab bar filters. Added
`test/screens_test.dart`'s *"the KPI cards are informational, not a second
set of filters"* — taps the Inactive KPI card (found by icon, since its
label text is shared with the sub-tab above it) and asserts nothing
filters, then taps the sub-tab with the same label and confirms it does.

## Point 3.1 fixed — the step bar could show a stale timestamp next to a fresher Timeline

`3.1` now adds *"The update and the audit logs dont match"*. Reproduced live
against the rebuilt Docker backend: the "Update Status" dialog
(`order_detail_screen.dart`) lists all 4 step-bar stages as selectable
regardless of the order's current stage, so walking an order backward (e.g.
Ready → Processing) and forward again (→ Ready) is a real, reachable path,
not a synthetic edge case. `Order.mark_status`'s old guard
(`if field and not getattr(self, field)`) only stamped a stage's timestamp
on its *first* arrival — so after a revisit, `ready_at` still read the
original arrival time from the first pass, while `audit_log` correctly
logged the revisit's `PROCESSING`→`READY` entries with today's timestamp.
The step bar (driven by `stageTimestamps`) and the Timeline & Audit Log
panel (driven by `audit_log`) told two different stories for the same order.

**Fix**: `mark_status` now always refreshes the stage timestamp, revisit or
not — nothing is lost, since every transition (including revisits) was
already being preserved in full in `audit_log`; only the single
summary-timestamp-per-stage now always reflects the *most recent* arrival
rather than the first. `backend/api/tests.py`'s
`test_stamps_are_not_overwritten_on_revisit` (asserting the old, now-wrong
behavior) became `test_stamps_refresh_on_revisit` (asserts the timestamp
advances), plus a new `test_every_transition_is_logged_even_a_revisit`
locking in that `audit_log` still records both the detour and the return.
Live-verified: revisited a seeded order (Ready → Processing → Ready) against
the rebuilt backend and confirmed `ready_at` now exactly matches
`audit_log[-1].created_at`.

### Suites after this pass
Django 161/161 (+1 for the new revisit-logging test). Flutter 239/239
(+1 for the Staff KPI test). `flutter analyze`: same 46-issue baseline, no
new errors. Docker rebuilt (`docker compose up --build`) so both containers
serve every fix from this session.

## Point 6.1 re-verified against the rebuilt Docker containers

The go_router migration that fixed `/new-order` not existing was implemented
and committed earlier this session, but never actually verified against the
rebuilt Docker containers afterward. Did that now: deep-linked to
`/new-order` (rendered correctly, item grid + cart panel) and hard-reloaded
it — stayed put rather than resetting to `/`, the exact original bug.
Went further and checked the two other routes the same migration touched:
`/orders` deep-links with real data (`15 Total`, all filter chips, full
table), and clicking into an order navigates to a real per-record URL
(`/orders/<uuid>`, e.g. `/orders/4dad5dcf-485f-4cc7-b947-9c3a1c4882d9`) that
also survives a hard reload and re-resolves the same order. All three
confirmed live via the browser, not just by reading the router code.

(Browser automation was flaky against this Flutter build again during this
check — screenshots intermittently timed out and network-request status
lagged behind reality by several seconds. Waiting longer and retrying
resolved it every time; nothing here pointed to an actual app bug, unlike
the `RecentActivityCard` investigation earlier in this file.)

---

## Session of 2026-08-21 — two gaps found, neither fixed yet

### New Order checkout is a different, lighter design, not a broken one

Reported as "the checkout button is present, once clicked it should behave
like the original but it is missing." Static reading of `_checkout` in
`new_order_screen.dart` showed it fully wired (builds a payload, POSTs to
`/api/orders/`, shows a `ReceiptDialog` on success) — not dead code. The real
gap only showed up by actually driving `app.laundrybill.com` (signed in as
the seeded owner) and clicking Checkout live, with explicit go-ahead to do so
on the account's own test data. Screenshots from that walkthrough are at
`screenshots/steps_order/step1-3.png`.

The real Checkout button does **not** submit the order — it swaps `/new-order`
(no route change) into a second **review step** our clone skips entirely:

1. **Cart** (matches ours): items, customer, Subtotal/Total, Checkout button.
2. **Checkout review** (missing here): customer card with "Change"; a
   **Fulfilment** selector — 3 cards, Shop Pickup / Home Delivery / Pickup
   from Home; a **Ready by** date row with −/+ day steppers; a **Payment**
   card with just a "Collect payment now" toggle (no method picker); an
   **Order Notes** box; a right-rail **Order Summary** — items, Subtotal, an
   editable **Discount** field, Total, and the actual **Place order** button.
3. **"Order Placed!" success view** (missing here): green check, Order ID,
   summary rows (Customer / Items / Order Type / Payment — "Balance Due: ₹X"
   or paid / Ready by / Total), then **New Order** / **Print Receipt** /
   **View Order Details** / **Share** / **Track** actions. Confirmed live by
   placing a real test order, `#WA3P-00005`.

Our clone instead keeps Delivery-type and payment-method chips inline in the
cart's right rail, has no date/notes/discount fields anywhere, and jumps
straight from "Checkout" to POST + an itemized `ReceiptDialog` popup (QR
code, WhatsApp button) — a different design, not a lighter version of the
real one.

**This is frontend-only.** `Order` already has `notes`, `scheduled_date`,
`discount_amount` (`backend/api/models.py:148,246,248`), `OrderSerializer`
only marks `order_number` read-only (`serializers.py:64`) and already folds
`discount_amount` into `total_amount` itself (`serializers.py:93`), and
`OrderModel`/`OrderItemModel` already parse `notes`/`scheduledDate`/
`discountAmount` (`order_model.dart:159,166,167,306,312,313`).
`order_detail_screen.dart` already renders both discount (`:384-386`) and
notes (`:580-589`) when present, and already has a working `showDatePicker`
pattern for `scheduled_date` in its Edit dialog (`:1010-1118`) to copy.
Nothing on the backend or in any other screen needs to change.

**Planned approach** (not started — full plan is at
`C:\Users\abhi3\.claude\plans\under-the-http-localhost-8080-new-order-melodic-wall.md`,
saved instead of implemented this session):

- Add `_showCheckoutReview` (+`_notes`, `_discountAmount`) to
  `_NewOrderScreenState`. Checkout no longer calls `_checkout` directly — it
  flips the flag, swapping the center column (search/category/item grid,
  `new_order_screen.dart:168-223`) for a new `_buildCheckoutReview`, and the
  right rail's cart list + Delivery/Payment/Paid-in-full block
  (`:301-444`) for a compact Order Summary + Place order button.
- Delete the inline Delivery/Payment-method chips from the cart screen
  (`:342-444`) — the real cart rail only shows Subtotal/Total/Checkout at
  that stage. Keep `_paymentMethod` defaulted to `'CASH'` with no chooser
  anywhere in New Order, matching the real flow and the model's own default
  (`backend/api/models.py:229`).
- Reuse `DeliveryType` (`order_model.dart:48-61`) but offer only 3 of its 4
  values here (drop `online`), relabelled to match the live app's copy:
  `storePickup: 'Shop Pickup'`, `homePickup: 'Pickup from Home'`.
- Payload gains `notes`, `discount_amount`, `scheduled_date`; total becomes
  `(subtotal + deliveryCharge - discountAmount).clamp(0, ∞)` to match the
  backend's own formula.
- Replace the auto-popped `ReceiptDialog` with a real "Order Placed!" view
  (check icon, Order ID, summary rows) and three real actions — **New
  Order** (reset), **View Receipt** (opens the existing `ReceiptDialog` as a
  secondary view instead of auto-showing it), **View Order Details**
  (`context.go('/orders/${created.id}')`). Deliberately *not* adding fake
  "Print Receipt"/"Track" buttons — no printable view or public tracking
  page exists in this clone (`LIVE_AUDIT.md` lists `/track/:trackingId` as
  never built), and this file already flags fake success actions elsewhere
  as tech debt to remove, not a pattern to add to.
- `new_order_test.dart`'s `'picking a delivery type other than pickup adds
  the flat fee'` (lines 180-208) targets the chips being deleted — move it
  into the new review step rather than dropping the coverage. Add tests for
  the review step's visibility, Ready-by stepping, Discount reducing the
  total, New Order fully resetting state, and the payload actually carrying
  `notes`/`discount_amount`/`scheduled_date`.

### Services "Show Inactive" toggle doesn't hide inactive items from New Order

Second gap, reported mid-investigation of the above, not yet root-caused in
depth. `GarmentItemModel.isActive` exists (`garment_model.dart:58`, parsed
from `is_active`, defaults `true`), and `services_screen.dart` already has a
real "Show Inactive" filter (`:171`) and an Active/Inactive toggle in its
edit dialog (`:1787,1822,1961-1964`) — disabling an item there is a real,
persisted write. But `new_order_screen.dart`'s `filteredItems` (`:110-116`)
only filters on `_selectedCategory` and `_searchQuery` — it never checks
`isActive`, so a garment disabled in Services still shows up and is
orderable on the New Order grid. Fix is presumably a one-line addition to
that filter's predicate (`&& item.isActive`), but not yet verified live
end-to-end or checked for whether Services' "Show Inactive" list should
still let you *view* inactive items without being able to add them to a
cart — worth confirming against the real app before just hiding them
outright.

### Customers page search doesn't match the AREA column it displays

Third gap, reported mid-session. There is no separate "Filters" control on
`/customers` in either app — `LIVE_AUDIT.md:112` and a live screenshot of
`app.laundrybill.com/customers` both confirm the header is just
`Customers N Total`, the search box, `Export`, `Add`, matching
`customers_screen.dart:98-161` exactly. So "the filter at the top" is that
search box, wired at `customers_screen.dart:60-66`:
```dart
final q = _searchQuery.trim().toLowerCase();
final filtered = customers.where((c) {
  if (q.isEmpty) return true;
  return c.name.toLowerCase().contains(q) ||
      c.phone.toLowerCase().contains(q) ||
      c.email.toLowerCase().contains(q);
}).toList();
```
Live-tested against the running clone (`localhost:8080/customers`, 10 seeded
customers): typing "Priya" correctly narrows to one row — the box isn't
dead. But typing **"Koramangala"** — the exact, visible value in Rohan
Verma's own AREA column, the table's third field — returns "No customer
matches "Koramangala"." The predicate above only checks `name`/`phone`/
`email`; `area` (`CustomerModel.area`, rendered right there in the table at
`customers_screen.dart:316`) is never included. A user filtering by
something they can see in the table gets a silent, confident-looking "no
results" instead of a match — that's almost certainly the "doesn't work"
being reported, not the box being unresponsive.

Not yet confirmed against the live app whether its own search also excludes
area (the signed-in test account only has one customer, area unset, so
there's nothing to search for there) — worth checking with a live account
that has area data before assuming the fix is simply adding
`|| c.area.toLowerCase().contains(q)` to the predicate. If real search does
cover area, that one-line addition is the whole fix; if it doesn't either,
this is at most a placeholder/copy mismatch, not a functional bug.

---

## All three fixed

### New Order checkout — the two-step flow, built as planned

Implemented per the plan above, in `new_order_screen.dart` and a 2-line
relabel in `order_model.dart`. `_showCheckoutReview` now gates a second
screen: cart's Checkout button no longer calls `_checkout` directly — it
sets a default `_readyBy` (tomorrow) and flips the flag, swapping the item
grid for `_buildCheckoutReview` (customer card, FULFILMENT — Shop Pickup /
Home Delivery / Pickup from Home, in that order, matching the live app
rather than the enum's own declaration order — Ready by with day steppers,
a Payment "Collect payment now" toggle defaulting off, Order Notes) and the
cart-items rail for `_buildOrderSummary` (items, Subtotal, an editable
Discount field, Total, **Place order**). The inline Delivery/Payment-method
chips and "Paid in full" switch that used to sit in the cart footer are
gone — the cart stage now only shows Subtotal/Total/Checkout, like the real
app. `_checkout`'s payload gained `notes`, `discount_amount`,
`scheduled_date`, and its total formula now matches the backend's own
(`subtotal + delivery_charge - discount_amount`, clamped to 0). On success
it resets all cart/review state first, then shows a new `_OrderPlacedDialog`
(green check, Order ID, Customer/Items/Order Type/Payment/Ready by/Total,
then **New Order** / **View Receipt** — opens the existing `ReceiptDialog`
as a secondary view / **Order Details** — `context.go('/orders/${id}')`)
instead of auto-popping the old receipt.

`new_order_test.dart`'s delivery-fee test was moved into the new review flow
(tap Checkout first) instead of being dropped, and two new tests cover the
review step's visibility and a discount reducing the total. Full suite
after: Flutter 241/241, `flutter analyze` clean (55 info-level lints, same
kind as the pre-existing baseline — no new errors or warnings).

Live-verified end-to-end against the rebuilt Docker frontend: added a
Shirt, Checkout → Home Delivery → Ready by defaulted to the next day →
discount ₹5 → paid toggle on → **Place order** created `#WASH-00018`
(`Subtotal ₹15, Delivery ₹50, Discount ₹5, Total ₹60`), the success dialog
matched the live app's almost exactly, and **Order Details** navigated to
`/orders/8e7533c2-...` showing the same delivery type, discount, total and
"Expected Delivery Aug 22, 2026" pulled straight from what was submitted.

**Not done**: `View Receipt`'s `ReceiptDialog` and the whole in-place
"Print Receipt" / "Track" pair from the real app's success screen were
deliberately left as scoped-out in the plan (no printable view or public
tracking route exists here) — still true, unchanged.

### Services inactive items — fixed

One-line fix, exactly as scoped: `new_order_screen.dart`'s `filteredItems`
predicate now requires `item.isActive`, so a garment turned off in Services
no longer appears in the New Order grid. The base `garments` list (used for
cart pricing/lookup) is untouched, so an item already in someone's cart when
it gets disabled doesn't silently vanish mid-order. Verified live via the
API (`PATCH /api/items/1134/ {"is_active": false}` → Shirt disappeared from
`/new-order`'s grid; re-enabling brought it back).

Whether Services' "Show Inactive" list should let you *view* an inactive
item without being able to add it to a cart is still an open question this
session didn't need to answer — New Order simply never shows inactive items
at all now, active-viewing-only wasn't part of what was reported broken.

### Customers AREA search — fixed

One-line fix: the search predicate in `customers_screen.dart` now also
checks `c.area.toLowerCase().contains(q)`. Live-verified: searching
"Koramangala" now finds Rohan Verma (previously "No customer matches"). The
open question from the original write-up — whether the real app's own
search covers area — is still unresolved; the fix was made on the merits
(AREA is a displayed column, so it should be searchable) rather than on
confirmed parity.

### One incident during this session: an accidental delete, caught and fixed

While live-testing the Services-inactive fix through the UI (before
switching to the API for reliability), a click meant for the "Edit Service /
Item" dialog's × close button appears to have landed on the adjacent red
**Delete** control instead — the dialog's content area was failing to
render for unrelated reasons (a rendering glitch, not caused by this
session's changes; matches the "browser automation was flaky against this
Flutter build" note elsewhere in this file), which made the click target
harder to judge from screenshots alone. The seeded "Shirt" item (Ironing,
id 1134) was gone from `GET /api/items/1134/` moments later. Caught via a
follow-up API check, fixed by `docker compose exec backend python
seed_db.py` — confirmed back to 79 items across 7 categories. No other data
was touched. Worth remembering for next time: prefer the API over clicking
through a dialog whose content isn't rendering, rather than trusting
coordinates against a screenshot that might be stale.

### Delivery charge — made editable, not just a fixed ₹50

Follow-up request after the checkout flow landed: the ₹50 Home Delivery fee
was still a hardcoded constant (`_deliveryFee`), applied automatically with
no way to change it per order. `new_order_screen.dart` now carries a real
`_deliveryCharge` field (was a getter derived from `_deliveryType`) plus a
`_deliveryChargeController`. Picking Home Delivery in FULFILMENT seeds the
field at the ₹50 default; picking a pickup type zeroes it and hides the
field again. In the Order Summary panel, the Delivery line is now an
editable `TextField` — same treatment as Discount already had — so a shop
can charge more or less than the default per order. Resets to the ₹50
default on the next order after a successful Place order, same as every
other review field.

`new_order_test.dart`'s delivery-fee test was rewritten to assert the field
is editable (checks the controller's default `'50'` text, then types `'30'`
and confirms the total follows) rather than just asserting a static ₹50/₹65
readout. Full suite after: Flutter 241/241, `flutter analyze` clean (same
12-issue file-level baseline, no new errors). User-validated live against
the rebuilt Docker frontend.

### Collect Payment — gated on Delivered

Another follow-up: `order_detail_screen.dart`'s Payment card offered
**Collect Payment** the moment any balance was owed, regardless of order
status — staff could record payment before an order had even left the
shop. `_paymentCard` now computes `isDelivered = order.status ==
OrderStatus.delivered` and only wires `onPressed` when true; the button
stays visible (so the balance is never hidden) but greys out otherwise,
with a caption — "Available once the order is marked Delivered." — so it's
clear why, not just that it's unresponsive.

`order_detail_test.dart` gained two tests: disabled + caption shown at
`OrderStatus.processing`, enabled + caption gone at
`OrderStatus.delivered`. Full suite after: Flutter 243/243, `flutter
analyze` clean on the file (0 issues).

**Not live-screenshotted this time** — browser automation's scroll/resize
was too unreliable this session to get the Payment card into frame (matches
the pre-existing "flaky against this Flutter build" note elsewhere in this
file; `resize_window` didn't change the captured viewport, mouse-wheel and
Page_Down scroll both no-opped on this page). Confidence here rests on the
two new widget tests directly asserting `FilledButton.onPressed` is
null/non-null by status, not on an eyeballed screenshot — worth a manual
look next session on `/orders/f37d7419-064e-4542-84a5-cffa635b46fd`
(`#WASH-00002`, due ₹126, status Placed) to confirm the disabled state
actually renders as expected.

### Customers KPI cards — now real filter tabs

Reported as "the tabs should filter, they aren't" — the only tab-like UI on
`/customers` is the Total/Active/New KPI row, which was purely read-only
(`_kpiRow`/`_kpi` in `customers_screen.dart`). Added `_kpiFilter` state
('all'/'active'/'new'); each `_kpi` card is now an `InkWell` that sets it,
with a colored border marking the selected one. The table's filter
predicate (already combining search) now also applies
`_isActiveCustomer`/`_isNewCustomer` — the same predicates the KPI counts
already used, extracted so the count and the filter can't drift apart. The
table heading and empty-state message ("No active customers yet." / "No
new customers this month.") follow the active tab too, matching the
Orders screen's existing pattern of a state-aware empty message.

`customers_test.dart` gained one test tapping through all three tabs and
checking the roster narrows correctly plus the heading/empty-state text.
Full suite after: Flutter 245/245, `flutter analyze` clean (0 issues on the
file). Live-verified against the rebuilt Docker frontend: Active correctly
dropped a freshly-added 0-order customer ("mukesh") from the list, heading
changed to "Active customers", selected card got a green border.

### New Order's "Add" customer — Existing/New tabs, matching the real app

Follow-up request: New Order's customer picker (`_CustomerPickerDialog`)
only ever searched existing customers, with "Bill to walk-in customer" as
the only other option — there was no way to add a brand-new customer
without leaving New Order for the Customers screen. The real app's own
"Bill to" dialog has **Existing customer** / **New customer** tabs (seen in
`screenshots/steps_order/step2.png`), so this was a real gap, not
invention.

The dialog now has that same tab pair. "Existing customer" is the search +
list + walk-in button, unchanged. "New customer" reuses the same four
fields as the Customers screen's own Add Customer dialog (Full Name, Phone
Number, Email, Area/Locality — deliberately identical, since it's the same
`provider.addCustomer` payload shape) with the same required-field
validation. On success it pops the dialog with the newly-created customer
(read back via `provider.customers.first`, since `addCustomer` inserts at
the front of the list rather than returning the record directly) so New
Order attaches it to the order immediately, same as picking an existing
one.

`new_order_test.dart` gained a test covering: both tabs are offered, New
customer hides the existing-customer UI and shows the form, submitting
blank fields surfaces the validation error without a network call, and
switching back to Existing customer restores the search list. (Actually
creating a customer end-to-end isn't covered — `addCustomer` hits a real
`ApiService` call with no mock seam in this test suite, same gap already
noted for order creation.) Full suite after: Flutter 245/245, `flutter
analyze` clean (same 12-issue baseline). Live-verified against the rebuilt
Docker frontend — the user's own test customer "mukesh" (0 orders, "Just
now") showed up in the Customers roster, created through this exact flow.

### Orders' "Filters" button — implemented

Last of the reported dead buttons: `orders_screen.dart`'s `Filters` was
`onPressed: () {}`. The 11 status chips, date-range dropdown and search box
already cover a lot, so the new dialog only adds the dimensions nothing else
does: **Delivery Type** (`DeliveryType.labels`), **Payment Method**
(`provider.paymentMethods`, same source Expenses/Payroll already use), and
an **Express only** toggle — all real `OrderModel` fields with no UI
anywhere else on this screen. Applied as a plain client-side `.where()` on
top of `provider.ordersFor(...)`'s result, no provider changes needed.

The dialog edits a scratch copy of the three values so **Cancel** truly
discards changes and **Clear all** only resets the in-dialog scratch state
(does nothing until **Apply**). The button itself shows an active count —
`Filters (2)` — and turns blue, mirroring the KPI-tab selection style
established on Customers this session. One implementation gotcha:
`AlertDialog.actions` lays children out in an `OverflowBar`, which doesn't
support flex children — an initial `Spacer()` directly in `actions` needed
wrapping in a single bounded `Row` inside one `actions` entry instead.

No existing test file pumped `OrdersScreen` at all (only
`orders_filter_test.dart`, which tests `AppProvider.ordersFor` directly) —
added `orders_screen_test.dart` covering: the dialog opens with all three
controls, selecting Home Delivery + Apply narrows the table and updates the
button label, Cancel discards an in-dialog toggle, Clear all resets before
Apply. Full suite after: Flutter 249/249, `flutter analyze` clean (4
pre-existing info-level lints, no new ones). Live-verified against the
rebuilt Docker frontend: Home Delivery filter took 20 orders to "Showing 7
of 20", every visible row correctly showing Home Delivery.

### Filter Orders — rebuilt from scratch after comparing against the live dialog

The version above was a reasonable-looking invention, not a copy — asked to
compare it against the real thing, opened `app.laundrybill.com/orders` and
its own Filters button side by side. The real "Filter Orders" dialog is a
completely different, considerably bigger surface: **ATTENTION NEEDED**
(Overdue Orders / Unpaid Dues — independent toggle cards, not radio),
**ORDER SOURCE** (All / Online "From public page" / In-shop "POS /
counter"), **ORDER TYPE** (All Types / Shop Pickup / Home Delivery /
"Pickup & Delivery"), **SERVICE TYPE** (a dropdown of the shop's actual
categories), **STATUS** (a radio list: All, Order Placed, Processing,
Ready, Partially Delivered, Delivered, Cancelled), closed by **Reset** /
**Apply Filters** — no Cancel button, just an × in the header. None of
Payment Method or Express-only exist in the real dialog at all; both got
dropped.

Rebuilt `orders_screen.dart`'s filter state and dialog to match section for
section:
- **Attention Needed** → `_overdueOnly`/`_unpaidDuesOnly`, independent
  booleans (`order.isOverdue`, `order.paymentStatus == UNPAID`) — same two
  conditions the main chip row's OVERDUE/UNPAID chips already compute, just
  reachable as an orthogonal layer here instead of a single-select swap.
- **Order Source** → `_orderSource` ('all'/'online'/'inshop'), mapped to
  `order.source`: Online = `PUBLIC_PAGE`, In-shop = `WEB`. `MOBILE_APP`/
  `STAFF_APP`/`AGENT_APP` orders (present in seed data — `seed_db.py`
  randomizes across all five) fall under neither non-"all" option, matching
  that the real dialog only exposes two.
- **Order Type** → `_orderType`, one of `DeliveryType`'s values (`online`
  deliberately excluded — it's under Order Source here, not Order Type,
  matching the real split). "Pickup & Delivery" maps to `homePickup`.
- **Service type** → `_serviceType`, a category name matched against
  `order.items.any((i) => i.serviceType == _serviceType)`, options read
  live from `provider.categories` rather than hardcoded, since the
  catalogue can differ shop to shop.
- **Status** → deliberately did *not* fork a second status variable. The
  dialog's Status radios write straight into the existing `_selectedTab`
  (same state the main chip row already owns), so there's one source of
  truth instead of two filters racing each other. One real adaptation:
  "Partially Delivered" isn't a status this data model tracks at all (no
  per-item partial-delivery concept — a real data-model gap, not something
  fixable in a dialog), so the radio list keeps `OrderStatus.outForDelivery`
  instead, which is real here and absent from the live list.

`orders_screen_test.dart` was rewritten alongside it — the old chip-based
assertions ('DELIVERY TYPE', 'PAYMENT METHOD', 'Cancel') no longer describe
anything that exists. New tests cover: all five section headers render:
Order Type narrows the table and the button shows the count; Overdue Orders
isolates the overdue seed order; Order Source's Online isolates the
public-page order; the Status radio for Delivered narrows the table *and*
leaves the main chip row's Delivered chip reading as selected (proving the
single-source-of-truth wiring); the × discards an in-dialog change with no
Cancel button to rely on; Reset clears the scratch state without closing
the dialog, requiring Apply Filters to actually commit. Full suite after:
Flutter 252/252, `flutter analyze` clean (1 pre-existing info-level lint).

Live-verified against the rebuilt Docker frontend: opened Filters, visually
near-identical to the real dialog — same title, same × placement, same
Attention Needed/Order Source/Order Type section layout and icons, same
Reset/Apply Filters footer. (Scrolling the dialog to check Service Type and
Status live hit the same browser-automation flakiness noted elsewhere in
this file — a stray scroll zoomed the whole page instead of scrolling the
dialog's content. Those two sections are confirmed working via the widget
tests above, just not re-confirmed with a live screenshot this session.)

---

## TODO — two gaps reported, not yet fixed

### 1. Disabling a whole Service *category* doesn't hide its items in New Order

The `is_active` fix earlier in this session (see "Services inactive items —
fixed" above) only covers the **item**-level toggle. `GarmentCategory` has
its own, completely independent `is_active` field
(`backend/api/models.py:165`; `GarmentCategoryModel.isActive`,
`garment_model.dart:101`) — Services already has a category-level
Active/Inactive concept, since `item_count`/`price_range` both filter to
`is_active=True` items server-side (`models.py:174-180`). But
`GarmentItemModel` carries no reference to whether its *own* category is
active — just `categoryId`/`categoryName` (`garment_model.dart:50-58`) —
and `new_order_screen.dart`'s `filteredItems` predicate
(`item.isActive && matchesCategory && matchesSearch`, `:113-119`) only
checks the item's own flag. So: turn off an entire category in Services,
and every item under it — each still individually `is_active: true` — stays
fully visible and orderable in New Order. Not yet confirmed live (no
category-level disable toggle has been exercised this session), but the
code path is unambiguous: nothing anywhere cross-references
`provider.categories` when building New Order's grid.

Likely fix shape: either have `filteredItems` also check
`provider.categories.firstWhere((c) => c.name == item.categoryName,
orElse: ...).isActive`, or thread the category's active flag onto
`GarmentItemModel` itself (the backend's item serializer would need to
start including it, or the client derives it client-side from
`provider.categories`).

### 2. Editing a Service's item ("Edit Service / Item") is broken

Directly observed earlier this session: opening this dialog live
(`services_screen.dart:1777`, `_showEditItemModal`) rendered the title bar
and the red **Delete** link, but the entire form body came up as a blank
grey box — nothing else painted. At the time this got misread as an
unrelated rendering glitch and worked around via the API instead (see the
"accidental delete" incident above — same dialog, same session).

Reading the code now turns up a real bug that fits: `selectedCat` is
seeded from `_categories[_selectedCategoryIndex]['title']`
(`:1781`) — the **sidebar's currently-selected category tab** — not from
the item's own actual category. That line is correct in
`_showAddItemModal` (`:1277`), where "default to whatever tab you're on"
is the right behavior for a *new* item, but it was copy-pasted into
`_showEditItemModal` where it's wrong: the form should seed from the item
being edited, not from whatever the sidebar happens to be showing. Under
plain single-category browsing the two usually coincide (you can only see
an item to click Edit on it if you're already on its category's tab), so
this may not be the direct cause of the blank-render — but it's a live
correctness bug regardless: if a future "search all items" or "Show
Inactive across categories" view ever lists an item next to a
different tab selection, Edit would silently preselect the *wrong*
category, and saving would move the item.

`selectedUnit`'s init is also suspect, separately:
```dart
String selectedUnit = PricingUnit.all.firstWhere(
  (u) => PricingUnit.label(u) == item['unit'],
  orElse: () => PricingUnit.piece,
);
```
compares `item['unit']` (almost certainly the raw backend code, e.g.
`'PC'`) against `PricingUnit.label(u)` (the human label, e.g. `'Per
piece'`) — those can never match, so this silently always falls back to
`PricingUnit.piece` regardless of the item's real unit. Doesn't crash
(has `orElse`), but means Edit always shows the wrong unit pre-selected too.

Not yet root-caused to certainty, not yet fixed. Next step: reopen this
exact dialog live, check the browser console for the actual thrown
exception (release-mode Flutter web swallows the red-screen overlay, which
is why this presented as a silent blank box rather than a visible error),
and confirm which of the two `selectedCat`/`selectedUnit` init lines — or
something else entirely — is the real cause before touching the fix.

---

## Both TODO items fixed, plus two more found along the way

### 1. Edit Service / Item — root cause confirmed and fixed

It was the `Spacer()`. Reproduced live with the console open:
`TypeError: Instance of 'minified:mC': type 'minified:mC' is not a
subtype of type 'minified:f4'` at render time — exactly the
`AlertDialog.actions` + bare `Spacer()` incompatibility already diagnosed
and fixed once this session in the Orders Filters dialog
(`OverflowBar`, which lays out `actions`, doesn't support flex children).
`_showEditItemModal`'s actions (`Delete … Spacer() … Cancel, Save`) had the
identical shape. Fixed the same way: wrapped the whole row in one bounded
`SizedBox(width: double.infinity, child: Row(...))` as the dialog's single
`actions` entry. Grepped the rest of `lib/` for the same pattern
(`Spacer()` within 20 lines of an `actions: [`) — no other instances.

`selectedCat`'s fragile derivation (seeded from the sidebar's selected tab,
not the item's own category — see the original TODO writeup above) was
real but turned out not to be reachable today, since `_currentItems` is
itself always pre-filtered to the selected tab. Fixed anyway for
robustness: added `'categoryName': g.categoryName` to the item view-model
map and seed `selectedCat` from that.

`selectedUnit`'s comparison, on closer reading, was actually correct —
`item['unit']` is set from `g.unitLabel`, which is itself
`PricingUnit.label(g.unit)`, so comparing `PricingUnit.label(u) ==
item['unit']` does match correctly. Not a bug; withdrawn from the fix list.

`services_test.dart` gained `'Edit Service / Item opens without crashing'`,
tapping the *second* `Icons.edit_outlined` (index 0 is the category
header's own edit pencil, easy to grab by mistake) and asserting
`tester.takeException()` is null plus all three action buttons render.

### 2. Category-level disable — the real root cause was one level deeper

Started fixing "New Order still shows items from a disabled category" and
found the actual bug was upstream of everything already built: `AppProvider
.loadDataFromBackend` calls `ApiService.fetchGarmentItems()` with no
arguments, and that method defaults to `includeInactive: false` — so
`provider.garments` **never contained an inactive item in the first
place**, for any screen, ever. Two consequences neither of us had noticed:

- New Order's `item.isActive` check (fixed earlier this session) was
  checking a field that was always true in practice — real code, vacuous
  effect, because the inactive rows it was meant to catch were never in the
  list to begin with.
- Services' own "Show Inactive" checkbox (`_showInactive`) was **never read
  anywhere** — `_currentItems`'s filter chain had no `is_active` clause at
  all. Toggling the checkbox changed a boolean nobody consulted.

Fixed at the source: `loadDataFromBackend` now calls
`fetchGarmentItems(includeInactive: true)`, so `provider.garments` always
has everything, and every screen filters client-side (consistent with how
search/category filtering already works everywhere else in this app).
`new_order_screen.dart`'s existing `item.isActive` check is now load-
bearing for real. `services_screen.dart`'s `_currentItems` gained
`.where((g) => _showInactive || g.isActive)`.

**Two more bugs in the same family, found while fixing this:**

- The sidebar category dot and the category header's "Active" pill
  (`services_screen.dart`) were both **hardcoded** to the green/Active
  styling — `Color(0xFF10B981)` and the literal string `'Active'`, with no
  reference to the category's real `is_active` at all. This is the "green
  signal should be grey when disabled" report. Added `'isActive':
  c.isActive` to the category view-model map and made both the dot color
  and the header pill (color + Active/Inactive text) conditional on it.
- `_showEditCategoryModal` (the category-level "Edit Service" dialog)
  hardcoded `bool isActive = true;` regardless of the category's actual
  state — editing an already-inactive category's name (or anything else)
  while never touching the Status switch would silently **reactivate** it
  on save, since the switch always opened on. Now seeds from
  `cat['isActive']`.

`new_order_test.dart` gained tests for an inactive item being hidden, an
item under an inactive category being hidden, and — a real regression
guard — that items are *not* hidden when a test seeds garments without
seeding categories at all (the first version of the category-cascade fix
broke exactly this: treating "category not found" as "category inactive"
hid the entire catalogue in every test that didn't bother seeding
categories). `services_test.dart` gained tests for: inactive items staying
hidden until Show Inactive is ticked (rewriting two pre-existing tests that
had been silently relying on the missing filter to show an inactive seed
item unconditionally), an inactive category reading "Inactive" instead of
a hardcoded "Active", and editing an inactive category preserving Inactive
on its Status switch.

Full suite after everything above: Flutter 258/258, `flutter analyze`
clean (same pre-existing baseline, no new issues).

Live-verified against the rebuilt Docker containers (both frontend and
backend rebuilt, database reseeded to a clean 79-item/7-category state
before and after):
- Edit Service / Item: pencil → full form renders (Service Category,
  Item Name, Price, Unit, Turnaround, Status, Image URL, Delete/Cancel/Save)
  — no more blank box.
- Toggling an item's Status to Inactive and saving: toast "Updated
  'Shirt'", item count 23→22, item vanished from the (default,
  Show-Inactive-off) grid immediately — the original "disabling doesn't
  disable it" report, confirmed fixed.
- Category dot/pill: browser-click flakiness made toggling the switch
  in-app unreliable this session (same class of issue noted earlier with
  this Flutter build), so verified via a direct API PATCH
  (`is_active: false` on the Ironing category) instead — reloaded and
  confirmed the sidebar dot turned grey and the header pill read
  "Inactive" in grey, both correctly reactive to the real flag. Reverted
  the PATCH and reseeded afterward; no lasting data changes.

---

## Session of 2026-08-25

Five separate asks, landed as four commits, then a production deploy.

### Login screen: "Sign in with mobile number instead" disabled, not hidden

Asked to keep the link visible (it matches the real login page's layout)
but make it do nothing, marking it as future work rather than a working
placeholder. `login_screen.dart`'s `InkWell` (which called
`_notAvailable('Mobile number sign-in')`, popping a toast) is now a plain
`Text` in `sidebar_navigation.dart`'s existing disabled-item grey
(`Color(0xFFCBD5E1)`) — no `onTap`, no ripple, no new color introduced.
Live-verified in the rebuilt Docker frontend: click does nothing, no
toast; `Forgot password?` beside it still shows its own toast, unchanged.
While in there, also live-tested Sign In (Demo Mode → `/dashboard` with
real backend data) and Sign Out (→ `/login`, survives a reload) end to
end. One tooling note: after a Docker rebuild, Chrome kept serving a
stale `main.dart.js` from its disk cache despite normal navigation and
even a `Ctrl+Shift+R`-style reload — had to force it with
`fetch(url, {cache:'reload'})` from the page console before a plain
`location.reload()` picked up the new build. Worth remembering next time
a rebuild doesn't seem to show up in the browser.

### Two commits landed from the previous session's uncommitted work

Prior session had left staff-wages-to-monthly and the login/auth rework
sitting uncommitted (see the tail end of the previous entries above this
one — the "Both TODO items fixed" pass and everything after it up through
the Google Sign-In section were still unstaged when this session opened).
Committed as:

- `80253bf` — `Shop.default_daily_wage`/`Staff.daily_wage` →
  `default_monthly_wage`/`monthly_wage` (migration 0012), payroll deriving
  a per-day rate from the paid month's actual day count instead of a flat
  daily number, `Staff.is_delivery_agent` dropped, Staff screen's sub-tabs
  cut from 5 to 3, and the sub-tab row's alignment gap fixed (`ListView`
  instead of `SingleChildScrollView(child: Row(...))`, which was handing
  its child unbounded width and letting the parent Column center the
  shrink-wrapped result).
- `27768b1` — login screen rebuilt to match the real
  `app.laundrybill.com/login` (Email/Password fields, Sign In/Create
  Account tabs, Forgot password?), the auth gate made unconditional (no
  more `isConfigured` bypass — Demo Mode is the way in when Google isn't
  configured, so `docker compose up` / `flutter run` now always show
  `/login` first), plus the mobile-number-link fix above.

### `CLAUDE.md`'s stale auth claim fixed — `14ee157`

The Authentication section still said "a build with no `GOOGLE_CLIENT_ID`
skips the login gate entirely," which stopped being true the moment
`27768b1` landed. Rewrote the section to describe both real sign-in paths
(Google when configured, Demo Mode always), how the Email/Password UI
relates to `signInAsDemo` (no backend to check those fields against), and
where `GOOGLE_CLIENT_ID` actually comes from per workflow (`.env` for
Docker via `docker-compose.yml`'s build arg, `--dart-define` for
`flutter run`).

### Customers/expenses edit+delete, salary payment history shown — `90ccd6f`

Three items from the CLAUDE.md backlog, asked together. None needed a
backend change — `/customers/`, `/expenses/` and `/salary-payments/` were
already full `ModelViewSet` CRUD; the frontend had just never called
anything past POST.

- Customers and Expenses both gained a row-level ⋮ menu (Edit/Delete),
  the same `PopupMenuButton` pattern Services already uses for catalogue
  items. Both screens' Add dialogs became a single add/edit dialog
  (`existing` null vs non-null), pre-filling the record's own values for
  Edit. Deleting a customer is safe — `Order.customer` is `SET_NULL`, so
  past orders keep their own snapshotted name/phone and just lose the
  link.
- Payroll gained a "History" link next to "Record Payment" opening a
  dialog that lists a staff member's full `SalaryPayment` ledger across
  *every* month, not just the one currently selected — new
  `SalaryPaymentModel`, `ApiService.fetchSalaryPayments`,
  `AppProvider.fetchSalaryHistory`, all reading `/salary-payments/?staff=`.

Live-verified against the rebuilt Docker frontend: edited a customer's
area and watched the PATCH round-trip into the table; deleted an expense
and watched entries/totals/chips update; opened History on a staff member
and saw a payment from a *previous* month that had never been visible
anywhere in the UI before.

### Test coverage raised to ~83%, one flaky backend test fixed — `da7c84d`

Asked for 80% coverage. Baseline was 76.6% line coverage
(`flutter test --coverage` / `lcov.info`), with real files — not edge
cases, whole files — never touched by any test: `router.dart` (the actual
`buildRouter`/`appRoutes`, as opposed to the synthetic stand-in
`test/support/router_test_utils.dart` provides for isolated widget pumps),
`dashboard_screen.dart` and every side panel it composes
(`QuickScanCard`, `NeedsAttentionCard`, `OrderChannelsCard`,
`StaffAttendanceCard`, `StoreHealthCard`, `RevenueAnalyticsCard`), and
most of `AppProvider`/`ApiService`'s own methods — every prior test only
ever exercised the network-free getters (`ordersForFilter`,
`filteredOrders`, counters).

There's still no mock HTTP client in this suite. The insight that unlocked
most of the gain: with no server reachable in a `flutter test` VM run,
`ApiService._send`'s catch-all turns the platform error ("no host
specified in URI") into a real `ApiException` almost instantly — and
every `AppProvider` method already has a `try { ... } on ApiException`
that handles it by setting an error and returning false/empty rather than
throwing. Driving every method to that failure path, deliberately, is
what it actually means for "fails gracefully" to hold — and it's fast and
deterministic, unlike waiting on a real network call.

New files: `router_test.dart` (the real auth gate — signed-out → `/login`,
Demo Mode in, sign-out back out — plus every section route and all three
states `/orders/:id` can resolve to), `dashboard_screen_test.dart`,
`app_provider_coverage_test.dart`, `api_service_test.dart`,
`panel_card_test.dart`, `load_state_test.dart`,
`google_signin_button_test.dart`. `login_screen_test.dart` gained
`signInAsDemo`/`signOut` persistence tests, not just the
already-covered unconfigured-build guard.

Two things learned the hard way:

- `pumpAndSettle()` hangs on any route that renders `SidebarNavigation`
  through the *real* `MaterialApp.router` (works fine through a plain
  `MaterialApp` in every other test file) — something about
  `AnimatedContainer` combined with go_router's own page transition never
  reaches Flutter's idea of "settled" in this harness. Every router test
  uses a bounded `pump()` + `pump(Duration)` pair instead, same fix this
  session already knew from the Payroll History dialog and the
  `RecentActivityCard` investigation two sessions ago.
- A `WashNLaundryCrmApp` (`main.dart`) widget test was attempted and
  dropped: `GoogleFonts.ibmPlexSansTextTheme` hung the suite for minutes,
  even with `GoogleFonts.config.allowRuntimeFetching = false` set before
  first use. Not worth chasing further for one small file — `main()`
  itself was always going to be untested anyway (conventional for a
  Flutter entrypoint), and this drops just the thin `MaterialApp.router`
  wrapper around it.

Also fixed, found while adding backend coverage as a sanity check
(already at 97% — no backend tests needed for the goal, but a run
surfaced a real flake): `test_stamps_refresh_on_revisit` called
`mark_status` three times back to back with no explicit `when`, so all
three could land on the same `timezone.now()` microsecond and "refreshed
to something later" failed comparing a value to itself. Fixed by passing
explicit, one-second-apart `when`s — `mark_status` already accepts one
for exactly this kind of backdating (`seed_db.py` uses it the same way).
Reran the suite three times afterward to confirm it's actually fixed, not
just not-flaked-this-time.

Final numbers: Flutter lcov 82.9% (was 76.6%), 387/387 tests, `flutter
analyze` clean at the same 56-issue baseline. Django 161/161, stable
across repeated runs (was flaking roughly 1 in 3 before the fix).

### Deployed to production — Vercel (frontend) confirmed manual, Render (backend) confirmed already automatic

Asked to push the frontend to Vercel after the coverage work. Built
`flutter build web --release --dart-define=API_BASE_URL=...` — the value
wasn't recorded anywhere in the repo (split-host deploys have always been
override-at-build-time per CLAUDE.md, and nothing here writes down what
that override *is*), so found it by fetching the *currently live* site's
`main.dart.js` and grepping for a baked-in absolute URL:
`https://laundrybill-backend.onrender.com/api`. Built and deployed that
exact bundle with `vercel deploy build/web --prod` from
`washnlaundrycrm/` (where `.vercel/project.json` already links this
directory to the `washnlaundry-crm` project). Confirmed live: `200`,
correct API URL baked into the served JS, deployment `READY` and tagged
to commit `da7c84d`.

Asked directly afterward whether the backend was also deployed to Render.
It was not touched manually, and didn't need to be: `render services`
shows `laundrybill-backend` has `autoDeploy: "yes"` / `autoDeployTrigger:
"commit"` on `branch: "main"`, so both of this session's pushes already
triggered their own Render deploys automatically. `render deploys list`
confirmed the latest is `live`, on commit `da7c84d` — matching what was
just pushed — and a direct `curl` to `/api/shops/` returned `200` in
about a second once past the free-tier cold start (the first attempt
timed out at 15s, which reads exactly like a hung backend; it wasn't —
Render's free web services sleep after inactivity and take significantly
longer than that to wake on the next request).

One red herring chased down while checking this: `render services` also
listed a Postgres instance (`laundrypro-db`) in `suspended` status with
`suspenders: ["billing"]`. Traced it to a *different* service entirely —
`laundrypro-api`, an unrelated project in the same Render account (name
collision with this project's "laundrybill" only by way of a shared
prefix). This project's backend uses SQLite per CLAUDE.md and has no
Postgres dependency at all, so the suspension is a non-issue here —
worth remembering only so it isn't mistaken for a real problem again.

---

## Session of 2026-08-26

Opened with a large uncommitted diff already sitting in the working tree —
every screen with a nav rail, `sidebar_navigation.dart`, `router.dart`, and a
new untracked `lib/widgets/app_shell.dart` / `test/app_shell_test.dart`, none
of it mentioned in this file yet. It turned out to be a finished implementation
of the "Tablet (~600–1080 logical px)" step from CLAUDE.md's "Future steps"
section, from a prior session that ended before committing or writing it up.
Verified rather than redone from scratch: `flutter analyze` was clean (70 info-
level lints, no errors — same baseline shape as before), `flutter test` passed
420/420 including new responsive-specific suites, and a live smoke test
(`flutter run -d web-server` against the seeded Django backend, driven through
`claude-in-chrome`: demo-mode sign-in, Dashboard, Orders) showed real data
rendering with no console errors. Browser window resizing wasn't controllable
in this environment (`resize_window` didn't change `window.innerWidth` no
matter what was requested — the Chrome window here appears to be a fixed-size,
undecorated one), so the exact-pixel breakpoint behaviour was verified through
the widget-test suite's `tester.view.physicalSize` harness instead of eyeballing
a resized browser, which is in any case the more precise of the two.

**What the diff actually contains:** `AppShell`/`AppDrawer` (new,
`lib/widgets/app_shell.dart`) replace the old per-screen
`Row(children: [SidebarNavigation(), Expanded(body)])` — all 14 screens that
carry the rail now do `Scaffold(drawer: const AppDrawer(), body:
AppShell(body: ...))` instead. Below `SidebarNavigation.railMinWidth` (700,
unchanged), `AppShell` drops the persistent rail for a 44px hamburger bar
that opens `AppDrawer`, hosting `SidebarNavigation(inDrawer: true)` — new
`inDrawer` flag forces the full labeled layout, fills the drawer's width
instead of a fixed rail width, drops the collapse toggle and rail border, and
closes itself on nav-item tap. Below each screen's own content breakpoint,
wide tables (Orders, Customers, Staff, Attendance, Payroll, Expenses,
Reports) fall back to a card/list layout, primary header actions collapse to
icon-only buttons, and secondary actions fold into an overflow menu; Services'
category rail collapses to horizontal chips and its tab bar becomes
horizontally scrollable; New Order's cart panel moves from beside the grid to
below it and the grid's column count drops; Order Detail/Customer Detail
stack their side-by-side panels. Every one of these has a widget test driving
the target width via `tester.view.physicalSize`, matching the pattern
CLAUDE.md's Constraints section already asked for.

**One real gap found while verifying, fixed before committing:** the diff had
each of 9 screens declare its own private `static const double _wideBreakpoint
= 760;` — the exact "scattering magic numbers" CLAUDE.md's Tablet section
explicitly said not to do (it says so because a screen's threshold silently
drifting out of sync with its neighbours is a real bug class here — three of
the doc comments on these constants literally said "same threshold as Orders'
own breakpoint," i.e. the sameness was already load-bearing and undeclared).
Centralized both breakpoints actually in play — `contentWideBreakpoint = 760`
and a second, looser `contentStackBreakpoint = 900` (used by Reports and
Customer Detail to collapse two side-by-side panels into one column without a
full card rebuild) — onto `SidebarNavigation`, next to `expandedMinWidth` /
`railMinWidth`, and repointed every screen at them. Deliberately left alone:
`dashboard_screen.dart`'s own pre-existing `_wideBreakpoint = 990` (unrelated,
predates this session) and the graduated 1/2/3/4-column grid functions in
`services_screen.dart`/`new_order_screen.dart` (a different kind of
breakpoint — a column-count ladder, not a single wide/narrow threshold — so
aliasing their `900` to `contentStackBreakpoint` would have implied a false
shared meaning). Re-ran `flutter analyze` and `flutter test` after the
refactor: still 70 info-level lints / 0 errors, still 420/420 passing.

Also found, not fixed: `garment_model.dart`, `order_model.dart`, `money.dart`,
`app_provider.dart`, and `api_service.dart` all showed as modified in the
original diff. Checked each — all five are pure `dart format` line-wrap
reflows, no logic changed. Left as-is; they're presumably fallout from
running `dart format` across the tree at some point in the prior session.

Updated CLAUDE.md's "Future steps" section to describe the tablet work as
done rather than "nothing here is done yet," including the breakpoint table
and the centralization. Also corrected a now-stale claim in the Android
section that a phone width gets "a 60px icon rail" — `AppShell` already gives
it a drawer instead now. Flagged, not fixed: `SidebarNavigation`'s own
internal `narrowRailWidth`/`narrow` branch (the 60px icon rail) is dead code
in production now that `AppShell` intercepts every width below
`railMinWidth` before `SidebarNavigation` itself ever sees it non-drawer —
it only still executes inside tests that pump `SidebarNavigation` directly.
Worth deleting once confirmed nothing else depends on it.

Committed as one commit covering both the recovered session's work and this
session's cleanup, since the two were verified and finished together.

---

## Session of 2026-08-26, continued — icon-only New Order, Services header cleanup

Same session, after the tablet-layout commit above landed. Two follow-up asks
from the user, live-testing both Docker web and a real Android emulator as
each change went in — this is the diff that was left uncommitted afterward
(picked up and finished in the next session, see below).

### Docker + Android both brought up as a baseline first

Asked to "restart the docker and android app." Rebuilt both containers
(the running images predated the tablet-layout commit), then booted the
`Medium_Phone_API_35` emulator and built/installed the debug APK with
`--dart-define=API_BASE_URL=http://10.0.2.2:8000/api` so it talks to the
same Dockerized backend. It landed on the Dashboard showing the same real
numbers as the web build, and the new drawer/hamburger layout from the
tablet-responsive work rendered correctly at real phone width — the first
time that layout had been seen live rather than only through
`tester.view.physicalSize`.

### `TopHeader`'s New Order button collapses to icon-only

Asked to make "+New Order" on Dashboard icon-only, "and similarly at other
places too" — `TopHeader` is the shared widget behind Dashboard, Payroll and
Expenses (Orders, Staff, Services, Customer Detail already had their own
icon-only treatment for their own add buttons), so fixing the one shared
widget covered all three in one change. `top_header.dart`'s `build` now
wraps its button row in a `LayoutBuilder` and picks
`_iconOnlyNewOrderButton()` vs. `_labeledNewOrderButton()` off
`constraints.maxWidth < SidebarNavigation.contentWideBreakpoint` — the same
760px threshold every other screen's narrow header already uses, not a new
one.

New `test/top_header_test.dart`: labeled button + tap fires the callback at
1400px, icon-only + tooltip "New Order" + tap still fires the callback at
600px. Full suite after: Flutter 422/422 (420 + 2 new), `flutter analyze`
clean (same 70-issue info-level baseline). Live-verified on the Android
emulator: rebuilt, reinstalled, confirmed the button renders icon-only next
to the help icon at phone width and tapping it navigates to New Order.
Separately confirmed on Docker web too, once asked — this is plain shared
Dart with no `kIsWeb`/`Platform` branching, so there was never a second
"web version" to implement; rebuilding the frontend image and grepping the
served `main.dart.js` for the new tooltip string was enough to confirm the
same compiled code is what's live.

### Services header simplified — the "same button" report was two different buttons

Follow-up, with phone screenshots: "in the services section, the new order
should be the same as dashboard... is it not getting imported everywhere."
Turned out to be a real UI inconsistency, but not the one first assumed —
the Services header's blue "+" is **"New Service"** (adds a catalogue item),
a completely different action from Dashboard's "New Order," which only
*looked* like the same button (same `0xFF1A4FD6` blue, same 38×38 icon-only
shape at narrow width, just an 8px vs. 10px corner radius and no tooltip).
That near-identical styling with no tooltip to disambiguate is what read as
"the same button, inconsistently wired."

Rather than reconcile two visually-similar-but-different buttons, removed
the redundant one: the header's own "+ New Service" (plus the Download and
Import buttons beside it, which never did anything, and the "Show Inactive"
checkbox) are gone from both `_buildHeader` (wide) and `_buildNarrowHeader`
(phone-width) in `services_screen.dart`. The per-category **"+ Add Item"**
link that already sits next to "Items (N)" inside the items grid
(`services_screen.dart:545`, pre-existing, calls the same
`_showAddItemModal`) is now the only way to add an item — one control
instead of two doing overlapping jobs. Inactive items are now
**unconditionally** hidden from the Items list (`_currentItems`'s filter
dropped `_showInactive ||`, keeping just `g.isActive`) rather than hidden
behind a checkbox nobody could tell was linked to anything, since removing
the toggle meant there was no longer a way to reveal them from this screen
at all. `_showInactive` and the now-unused `_headerButton` helper were
deleted; a stale doc comment above `_buildNarrowHeader` describing the
removed Download/Import row was rewritten to match.

`services_test.dart`: the catalogue gained a third, always-active item (so
"the active ones still render" has something to assert against once the
inactive-toggle path is gone), `'inactive items are hidden until Show
Inactive is ticked'` became `'inactive items are always hidden from the
Items list'` (dropped the checkbox-tap steps entirely), and the two
responsive-layout tests asserting `'+ New Service'` findsOneWidget/findsNothing
were cut down to just asserting the category rail's own wide/narrow
behavior. Full suite after: Flutter 422/422, `flutter analyze` clean (same
baseline). Live-verified on both the Android emulator (narrow: header reads
just "Services · 7 Items · 79 items" plus a full-width, centered-placeholder
search box — no +, Download, Import, or Show Inactive; "+ Add Item" still
opens the modal, pre-scoped to the category you're on) and Docker web at
desktop width (same header shape, search right-aligned instead of
full-width).

### Left uncommitted, picked up next session

The session ended without a commit or a wip.md write-up — this section was
written after the fact, once the next session found the diff still sitting
in the working tree. That session also caught and fixed two stale comments
this one left behind: `app_provider.dart`'s `loadDataFromBackend` and
`new_order_screen.dart`'s `filteredItems` both had doc comments referring to
Services' "Show Inactive" toggle as if it still existed. Neither affected
behavior — comment-only — but both were corrected before this diff was
committed. Re-ran the full suite after those fixes: Flutter 422/422,
`flutter analyze` clean, same baseline throughout.
