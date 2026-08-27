# Payroll page fix — todo

## Confirmed issue
- [x] `TopHeader`'s primary button is hardcoded "New Order" -> `context.goSection(1)`
      on every screen that embeds it (Dashboard, Expenses, Payroll — see
      `top_header.dart` + each screen's `TopHeader(...)` call). On Payroll
      and Expenses this was wrong: clicking it dropped the user into the New
      Order POS instead of doing anything relevant to that screen.
  - Fix: `TopHeader` now takes a screen-specific primary action
    (label/icon/handler) instead of a hardcoded "New Order" everywhere.
  - Dashboard keeps "New Order" -> New Order screen (that one's correct).
  - Expenses: button now reads "Add Expense" and opens the same dialog as
    the in-page "Add Expense" button (`_showAddExpense`). **Done** — this
    was the same bug the user separately flagged ("Expenses page should not
    have +New Order").
  - Payroll: button now reads "New Payroll" and opens a staff picker dialog
    that then reuses the existing per-row `_showRecordPayment` dialog
    (amount/method/note) for whichever staff member is picked.

## Investigation (done)
- [x] Opened `/payroll` in the running Docker app (localhost:8080) — data and
      layout were fine; the only real bug was the "+ New Order" header
      button. No other visible issues found.

## Implementation
- [x] `top_header.dart`: `onNewOrderPressed` -> `onActionPressed`, plus
      `actionLabel` (default `'New Order'`) and `actionIcon` (default
      `Icons.add`).
- [x] `dashboard_screen.dart`: renamed param only, behavior unchanged.
- [x] `expenses_screen.dart`: `actionLabel: 'Add Expense'`, wired to
      `_showAddExpense`; removed now-unused `navigation.dart` import.
- [x] `payroll_screen.dart`: `actionLabel: 'New Payroll'`, wired to new
      `_showNewPayrollDialog`; removed now-unused `navigation.dart` import.

## Also (separate, unrelated asks)
- [x] Staff page: remove the "Show Inactive" checkbox.
  - `staff_screen.dart`: deleted `_showInactive` state and both checkbox UI
    blocks (wide + narrow header). The "All Staff" tab's filter (line ~91)
    is now just `s['status'] == 'ACTIVE'` — inactive staff no longer show
    there at all, but remain fully reachable via the existing "Inactive"
    sub-tab (unaffected by this change). Cleaned up two stale doc comments
    that described the checkbox's narrow-layout placement.
  - `test/screens_test.dart`: rewrote the test that used to tick the
    checkbox — now seeds one active + one inactive staff member, asserts
    the inactive one is absent from "All Staff" and no `Checkbox` exists
    on the page, then taps the "Inactive" sub-tab and asserts it shows up
    there.
  - Verified in Chrome (rebuilt Docker frontend): checkbox gone, "Inactive"
    tab still works (shows its own empty state — seed data has no inactive
    staff today).
- [x] Make all search bars center-aligned.
  - Added `textAlign: TextAlign.center` to every search `TextField` in the
    app that didn't already have it (Services' was already centered and
    served as the reference pattern): `orders_screen.dart` (desktop +
    mobile header), `customers_screen.dart` (desktop + mobile header),
    `staff_screen.dart`'s shared `_searchField()` (covers both headers in
    one edit), `new_order_screen.dart` (item search + the "Bill to" dialog's
    customer search). Expenses/Payroll/Attendance/Reports have no search
    bar (confirmed — their `TextField`s are plain form fields).
  - Deliberately not extracted into a shared widget — no shared search-bar
    widget existed before this, and CLAUDE.md's "don't introduce
    abstractions beyond what the task requires" argues against adding one
    just for this.
  - Verified visually in Chrome across Staff, Orders, Customers, New
    Order's item search, and the "Bill to" customer-search dialog — text
    reads centered and reasonably balanced against the left search icon in
    every box, including the narrowest ones.
- [x] CSV export — Orders and Customers. Both "Export" buttons were dead
      (`onPressed: () {}` on Orders; a permanent "Export is not available
      yet." snackbar on Customers). Now both export the currently
      filtered/searched rows as a real CSV download.
  - New shared utils: `lib/utils/csv.dart` (pure-Dart RFC 4180 builder,
    platform-independent) and `lib/utils/csv_download.dart` (conditional
    export on `dart.library.js_interop`, same shape as
    `google_signin_button.dart`) with `csv_download_web.dart` (real
    `Blob`/`URL.createObjectURL`/`<a download>` trigger via `package:web`,
    added as a direct dependency — it was already transitive) and
    `csv_download_stub.dart` (returns `false`, keeps `flutter test`'s VM
    target and any future non-web build compiling).
  - `orders_screen.dart` / `customers_screen.dart`: both header Export
    buttons now build a CSV of the filtered list and call `downloadCsv`;
    an empty filtered list shows "No orders/customers to export." instead
    of downloading a header-only file; a `false` return (non-web) shows
    "Export is only available in the web app."
  - Verified in the running Docker app: clicked Orders' Export, then read
    the actual temp file the browser wrote to Downloads — full, correctly
    formatted CSV of all 17 orders. Customers' export uses the identical
    code path and its own passing widget tests; a second browser download
    didn't visibly land only because Chrome's own download-confirmation UI
    (outside the page viewport, not something the browser automation can
    see or click) was still holding the first one — not an app bug.
  - Added widget tests: `orders_screen_test.dart`'s new "OrdersScreen
    Export" group, `customers_test.dart`'s new "CustomersScreen Export"
    group. Full `flutter test` — 428 tests (some rows counted per
    responsive variant), all passing.

## Payroll/Expenses/Reports follow-ups (this round)
- [x] Payroll page: add a search box.
  - `payroll_screen.dart`: new `_searchField()` (filters by staff name or
    role, case-insensitive), wired into `_titleRow` — a 220px box next to
    the month nav at wide width, full-width and stacked at narrow width.
    `_empty()` now distinguishes "no payroll this month" from "no staff
    match the search" so a search with no hits doesn't misleadingly say
    "Mark attendance to build up wages."
  - Fixed 3 existing tests whose `find.byType(TextField).first` now
    ambiguously matched the new search field instead of the record-payment
    dialog's amount field — scoped them to `find.byType(AlertDialog)`.
    Added 2 new tests for the search itself.
- [x] Expenses page: search box + the two "based on your expertise" gaps
      found while reviewing the screen (per user follow-up asking me to
      review Expenses on my own judgment).
  - Added a search box (`_searchField()`, filters by title/category/payment
    method) — confirmed absent before this.
  - **Found & fixed:** Expenses had no CSV export at all (Orders and
    Customers already did) — added one using the same `csv.dart`/
    `csv_download.dart` utils, exporting the currently filtered
    (category + search) rows.
  - **Found & fixed:** `_titleRow()` had no narrow-width handling at all
    (no `LayoutBuilder`, no stacking) — every other list screen in the app
    collapses to icon-only actions and stacks below
    `SidebarNavigation.contentWideBreakpoint`, but Expenses' title+button
    row didn't. Added a `narrow` branch: title + icon-only Add stack above
    a full-width search field and a full-width Export button.
  - Verified in the running Docker app: search filters the list correctly,
    and clicking Export with an active search downloaded a CSV containing
    only the filtered row (read the actual temp file from Downloads to
    confirm).
  - Added widget tests: search filtering, empty-search-result message,
    Export (dead-button-fixed, empty-list message), and a new
    `responsive layout` group covering the narrow-width stacking.
- [x] "Remove redundant 2nd payroll/Expenses" — resolved by an audit of
      every screen, not just Payroll/Expenses (see `wip.md`'s "Session of
      2026-08-27" for the full writeup).
  - **Payroll: not actually redundant, nothing changed.** "New Payroll"
    opens a staff picker before landing on the record-payment dialog — a
    different, page-level action from any single row's "Record Payment"
    (scoped to one staff member, no picker involved).
  - **Expenses: confirmed redundant, fixed.** The "Add Expense" fix earlier
    in this same session had itself created a duplicate — `TopHeader`'s new
    action button and the pre-existing in-page `_titleRow()` button both
    called `_showAddExpense`, always visible together. This is the same
    mistake two earlier sessions already caught and fixed elsewhere (Staff
    KPI cards duplicating the sub-tab filter; Services' header "+ New
    Service" duplicating "+ Add Item") — codebase convention is to remove
    the newly-introduced duplicate and keep the pre-existing control, not
    merge both into one handler. `TopHeader.onActionPressed` is now
    nullable; Expenses' `TopHeader` call passes none, so the header renders
    just the title + help icon and the in-page "Add Expense" button is the
    only control.
  - Every other screen (Dashboard, Orders, Customers, Staff, Attendance,
    Reports, Services, New Order, Order Detail, Customer Detail, Settings,
    Scan, Login) audited clean — no redundant duplicates found.
  - Added `top_header_test.dart`'s "omits the action button entirely when
    onActionPressed is null" and `expenses_test.dart`'s "the header has no
    Add Expense button of its own". Full suite: 440/440. Verified live in
    the rebuilt Docker frontend.
- [x] Reports page: Net Profit indicator now turns red when negative, green
      when positive — was hardcoded green regardless of sign.
  - `reports_screen.dart` L441-443 (KPI card's icon/accent color) and the
    Net Profit gauge panel (L586-668: the progress ring, the margin %, and
    the ₹ figure — introduced one `profitColor` local reused by all three)
    are now conditioned on `r.netProfit >= 0`. The small change-label under
    the gauge (`r.netProfitChange`) already did red/green correctly and was
    the pattern copied.
  - Added 2 widget tests (`reports_test.dart`) asserting the icon, ring, and
    margin-% color for both a loss and a profit scenario.
  - Verified live: this month's real seed data is at a loss (-₹29,441,
    -338% margin) and every part of the Net Profit display — KPI card icon,
    gauge ring, margin %, and the ₹ figure — now renders red.

## Verification
- [x] `flutter analyze` on the touched files — no issues.
- [x] Widget tests: added two new Payroll tests (header shows "New Payroll",
      not "New Order"; staff picker -> record-payment dialog; empty-month
      snackbar). Fixed `top_header_test.dart`'s renamed param and
      `expenses_test.dart`'s now-ambiguous `find.text('Add Expense')` taps
      (header now shares that label with the in-page button).
- [x] Full `flutter test` — 424 tests, all passing.
- [x] Manual check in Chrome (rebuilt the Docker frontend, hard-refreshed):
      Payroll's "New Payroll" opens the staff picker, picking a staff member
      opens the prefilled record-payment dialog; Expenses' "Add Expense"
      header button opens the same dialog as the in-page one.

As of the Payroll/Expenses/Reports follow-up round above: full `flutter
test` is 438 tests, all passing.
