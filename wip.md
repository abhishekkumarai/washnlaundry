# WIP — session of 2026-08-11

Working notes on the LaundryBill CRM clone. Everything below is committed to
`main`. The previous session's notes (2026-08-10) are in git history at
`104c315`.

---

## What this session closed out

The previous session's **"Open items → Still hardcoded literals"** table. All
three screens on it are now wired:

| Screen | Was | Now |
|---|---|---|
| Attendance | `_staff` literal | `/api/attendance/` + a new bulk upsert |
| Payroll | `_staffPayroll` literal | `/api/payroll/` + a new `SalaryPayment` model |
| Reports | every number inline in `build()` | `/api/reports/` |

`CLAUDE.md`'s data-flow table now has no rows left in the "literal" column.

## Commits landed

| SHA | What |
|---|---|
| `4ee573b` | Wire Attendance to the API |
| `c19337d` | Wire Payroll to the API, and record what was actually paid |
| _(this)_ | Wire Reports to the API |

Suites at the end of the session: **Django 149 green** (was 96), **Flutter 202
green** (was 164), `flutter analyze` error- and warning-free — 37 remaining
issues, all `info`-level lint, down from 45 because rewriting the Payroll and
Reports screens cleared several `prefer_const_constructors`.

---

## Attendance

`GET /api/attendance/` already existed; there was no way to **write** a day.

The screen was the worst offender left in the app. It hardcoded six staff who
were not the seeded roster — "Mohan Das" and "Anita Sharma" were invention —
and **Save Register showed a green "Attendance saved successfully" snackbar
without making any network call at all.**

### The endpoint has to upsert

`Attendance` is `unique_together = ('staff', 'date')`. A create-only endpoint
would 400 the second time Save Register was pressed, which is a thing users do.
`POST /api/attendance/bulk/` uses `update_or_create`.

Validation runs over the whole batch **before the first write**. A half-saved
register is worse than a rejected one, because nothing on screen tells you
which half made it.

### LEAVE was missing from the UI

The backend has always had four statuses and `dashboard_stats` counts LEAVE.
The chip row only ever offered three. Now four.

### "not marked" is not ABSENT

A staff member with no row for the day renders as "not marked". Defaulting them
to ABSENT would have invented an unpaid day.

---

## Payroll

### It needed a new model, not just wiring

Wages *earned* were always derivable — `Staff.daily_wage` times what the
register says. What was **paid** had nowhere to live, so the screen's Paid /
Pending Balance cards and PAID/PARTIAL/UNPAID badges had no possible source.
That is why this screen was left until late.

`SalaryPayment` (staff, month, amount, paid_on, method, note), migration
`0007`. **Deliberately not unique on (staff, month)** — a month can be paid in
instalments, which is what makes PARTIAL a real state rather than a decoration.

### Half-days are worth half

`Attendance.DAY_VALUE` maps PRESENT → 1.0, HALF_DAY → 0.5, ABSENT and LEAVE →
0. HALF_DAY has always been storable and the register offers it, so paying it
as a whole day would have quietly overpaid. Overpayment floors pending at zero
rather than going negative.

Nothing is cached on the `Staff` row, so payroll cannot drift out of step with
the register.

### The seed was actively misleading here

Attendance was seeded for **7 days**. Payroll totals a calendar month, so every
employee read as roughly five days worked and almost no wages. Now 70 days,
minus Sundays, and the roll produces HALF_DAY (it never did before). Seeds
`SalaryPayment` rows so all three states appear on first run: last month
settled, this month part-paid for some and untouched for others.

### Latent seed crash, fixed in passing

`CREATED_BY` covered three of `OrderSource`'s five values while the seed picks
one at random — so `python seed_db.py` died with `KeyError: 'STAFF_APP'` on
roughly two runs in five. Unrelated to payroll, but it blocks the only source
of demo data in the repo.

---

## Reports

Everything was hardcoded, down to an eight-month bar chart whose heights were
typed in as ratios (`0.25`, `0.35`, …) and a status breakdown listing
**"Washing"** — a status deleted from the model in an earlier pass.

`GET /api/reports/?from=&to=` now returns the whole screen. Notes:

- **Breakdowns are driven by the canonical choices**, so `Washing` cannot come
  back and `Ironing` cannot be forgotten. Statuses with no orders are omitted.
- **`by_type` covers all four `DeliveryType` values**; the screen only ever
  showed two.
- **Percentage change is against the immediately preceding window of equal
  length**, which is what "▲ 12% vs last month" always claimed to be.
- **`monthly_series` carries rupee amounts**; the widget normalises against the
  series peak itself.
- **`payment_mix` percentages are computed server-side.** The screen used to
  recover the number by parsing its own label —
  `double.parse(pct.replaceAll('%', ''))`.
- **Null, not zero, when there is nothing to measure** — the rule
  `dashboard_stats` already set for Store Health. An idle period is not a 0%
  margin, and the screen renders `—` for it.

`Print` and `Export PDF` are still no-ops, now explicitly **disabled** rather
than live buttons that do nothing. Both are paid-plan gated on the live app and
have never been captured, so there is nothing to clone them against.

---

## Two things worth carrying forward

### Range-scoped loads do not go in `loadDataFromBackend`

A day of Attendance, a month of Payroll and a date range of Reports each load
on demand and carry their own `attendanceLoading` / `payrollLoading` /
`reportsLoading` and `*Error` flags.

Keeping these out of the shared `error` matters: `error` means "this shop
failed to load" and blanks a screen. A failed single-day attendance fetch
should surface inline and leave a roster that loaded perfectly well on screen.
The first cut conflated the two and made "no staff" indistinguishable from
"still loading".

### `flutter analyze` is slow cold, not hung

A combined `flutter test; flutter analyze` blew a 600 s timeout and looked like
a `pumpAndSettle` deadlock against the new infinite `LoadingState` spinner. It
was not — the suite runs in 10 s and analyze in 3.5 s once warm. The first
analyze after a large edit re-analyses from scratch and can take 90 s+.

---

## Open items

### Not addressed, carried over

- **Order number prefix.** Local DB generates `WASH-000NN`; the live app uses
  `WA3P-00002`, derived differently from the shop name `washing`.
- **Sidebar shape.** Live has 8 items; ours has 14. All the extras are
  paid-plan features that silently redirect to `/dashboard` on the live Free
  account. `CLAUDE.md` calls this the biggest structural divergence and it is
  still unresolved — the clone targets neither the Free surface nor the
  Business one.
- **No router.** `main.dart` still switches on `AppProvider.currentNavIndex`.
  `CLAUDE.md` calls the `go_router` migration the single highest-value refactor
  available, and it is the thing blocking Android (the system back button has
  nothing to pop).
- **Settings, Apps and Subscription stay disabled.** Confirmed deliberate.
  Re-enabling Settings is a two-line revert: flip `disabled` in
  `sidebar_navigation.dart`, restore `case 13` plus its import in `main.dart`.

### Not verified in a browser this session

The three screens are covered by widget tests and the endpoints by Django
tests, and the payroll endpoint was checked against freshly seeded data
(July settles to PAID, August comes back mixed, half-days show as `.5`). But
**nothing was driven through `flutter run -d chrome`** — the previous session's
end-to-end pass has not been repeated. Worth doing before trusting the Reports
screen's layout at real widths, since it packs six metric cards into one row.

### Caveats that still apply

- The live account is **Free plan**. `/attendance`, `/payroll` and `/reports`
  all redirect to `/dashboard` there, so **our versions of all three screens
  are invention, not clones.** Matching them needs a paid account.
- Only a human can sign in, and the app allows one active session per account.
