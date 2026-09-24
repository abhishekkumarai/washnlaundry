# WIP — status as of 2026-09-23

All four items below are implemented, verified in Chrome on the Docker build
(frontend on localhost:8081 here, since 8080 is taken by another project), and
sitting in Jira **In Review** awaiting sign-off. Nothing is committed yet.

## Staff — KAN-42 — In Review
1. [x] "All Staff" lists everyone (active + inactive); Active / Inactive tabs filter.
   Header count now matches the rows (was 7 vs 6).
   1.1 [x] Status column is an on/off **switch** per row (flips Active ⇄ Inactive via
       `_toggleActive`). The Add/Edit dialog keeps an Active/Inactive radio; new staff
       default to **Inactive** (confirmed).
   1.2 [x] Search + "Add Staff" sit top-right, inline with All Staff / Active / Inactive.

## Payroll — KAN-43 — In Review
2.1 [x] Record-payment logic fixed. Pay owed stays **attendance-only** (the full-wage
    fallback for staff with no attendance was reverted, by decision). Fixed:
    - balance under ₹1 → PAID, ₹0 pending;
    - any recorded payment → never UNPAID;
    - ₹0 earned (no attendance) → payment still allowed (no ₹0 cap); overpay cap still
      applies when wages are earned.

## Expenses — KAN-44 — In Review
- [x] Notes field in the Add/Edit Expense dialog; shown in the list and in CSV export.

## Credits — KAN-45 — In Review
- [x] Credits section like Expenses, with notes: `/credits` page, sidebar entry,
  `Credit` model + migration 0017, `/api/credits/`, `credit_categories` in `/api/meta/`.
- [x] Fixed during verification: Credits shared nav index 14 with Help (both highlighted)
  → now 15; sidebar icon clashed with Reports' Net Profit icon (broke 2 tests) → now
  `Icons.savings_outlined`.

### Credit categories — KAN-46 (subtask of KAN-45) — In Review
- [x] Laundromat defaults: Laundry Income, Dry Cleaning Income, Delivery Charges,
  Customer Advance, Owner Investment, Other (migration 0018; `CreditCategory` table).
- [x] Managed in **Settings → Credit categories** (vertical tab): add, rename, turn
  on/off, delete (only when unused — in-use categories can only be turned off).
- [x] Settings is now routed (`/settings`, index 13) and enabled in the sidebar; other
  Settings tabs show "Not available yet". Settings "Sign Out" now really signs out.
- [x] Credits' dropdown lists only active categories, with a "Manage" link to Settings.
- Verified in Chrome 2026-09-24; test data cleaned up.

## Suites
Django 209/209. Flutter: full run 537 passed / 2 failed (the icon clash above), then
fixed; affected files rerun green. `flutter analyze`: no errors/warnings (52 info).

## Pending
- User sign-off to move KAN-42..46 to Done.
- Full `flutter test` for the credit-categories round was stopped early at the user's
  request (528 passed / 0 failed at that point); affected files pass.
- Commit the working tree.
