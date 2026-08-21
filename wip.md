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
