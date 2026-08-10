# WIP — session of 2026-08-10

Working notes from one session on the LaundryBill CRM clone. Everything below
is committed and pushed to `main` unless a section says otherwise.

---

## Commits landed

| SHA | What |
|---|---|
| `741b895` | Wire Services, Staff and New Order to the backend |
| `f380032` | Delete the abandoned Next.js implementation and one-off audit scripts |
| `68cf0f0` | Wire Customers to the API and add the customer detail screen |
| `d802390` | Wire Expenses to the API and let an expense carry its own date |
| `5d3c652` | Rework the order detail screen against the live capture |

Suites at the end of the session: **Django 96 green, Flutter 164 green**,
`flutter analyze` error-free (45 remaining issues are all `info`-level lint).

---

## Repo cleanup

The abandoned parallel Next.js implementation is **gone**: `app/`, `components/`,
root `lib/`, `prisma/`, `node_modules/`, `next.config.js`, `package.json`,
`postcss.config.js`, `tailwind.config.js`, `tsconfig.json`, plus the eleven
one-off Chrome screenshot/audit scripts that sat at the repo root.

Two things to know:

- **The Next.js files were never tracked by git** — all gitignored — so history
  is not an undo for them. A tar of all 53 source files was written to the
  session scratchpad, which is session-scoped and by now likely gone. The
  eleven audit scripts *were* tracked and are recoverable at `741b895~1`.
- **Kept deliberately**: `app_index.js`, `app_ui.js`, `index_fetched.html` and
  `screenshots/`. CLAUDE.md documents these as live reference material and they
  are untracked too, so deleting them would also be unrecoverable.

`gemini.md` was kept at the user's instruction. Note it has drifted: it claims
the API base URL is `http://localhost:8000/api`, whereas `api_service.dart`
defaults to a relative `/api`.

---

## Screens wired to the API this session

`CLAUDE.md`'s data-flow table is now accurate. Newly real:

- **Services**, **Staff** (in `741b895`)
- **Customers** + a new **Customer detail** screen (`/customers/:id`, which had
  no local equivalent — the old screen popped a modal)
- **Expenses**

The Customers screen had been *fabricating* data: one hardcoded fake customer
called "Me", plus an invented area (`'Hbr layout'`) and last-order time
(`'7h ago'`) for anyone found in the orders list — while `AppProvider` was
already loading the real list and being ignored.

---

## Live capture — order detail

Captured `app.laundrybill.com/orders/EPHoc8XH3OcXtoGTmoEO` (`#WA3P-00002`, a
store-pickup order). **This corrects LIVE_AUDIT.md** and is the most valuable
reference gained this session.

### The step bar is four stages and adapts to fulfilment type

The real app collapses `Out for Delivery` into the Timeline, so the bar is:

| Step | Store pickup | Delivery |
|---|---|---|
| 1 | Order Placed | Order Placed |
| 2 | Processing | Processing |
| 3 | **Ready for Pickup** | Ready |
| 4 | **Picked Up** | Delivered |

Ours was a fixed five-step path that still said "Washing" — a word in none of
the three status vocabularies — and showed Out for Delivery / Delivered steps on
collection orders that can never reach them. Now driven by
`OrderModel.stepLabels` / `stepStatuses` / `stepIndex`.

### The right rail switches too

Store pickup gets **FULFILMENT / Expected Ready**. Delivery gets
**DELIVERY & ROUTE / Assigned Agent**. The audit had only recorded the latter.

### Actions row

Live has `WhatsApp` · `Edit` · `Print Receipt` · `Update Status` · `⋮`.
The audit had recorded only WhatsApp and Print Receipt.

### Update Status modal

Radio list of the four stages with a `CURRENT` badge, `Cancelled` separated out
and marked *"This action cannot be undone"*, a **Notes (optional)** field, and
`Share via WhatsApp` + `Update Status`. All reproduced.

### Provenance

Live timeline writes **"Created by abhishek kumar"** for a counter order but
"Created by Mobile App" for an app one — it holds *either a person or a
channel*, which `OrderSource` cannot represent. Added `Order.created_by` as free
text falling back to the source label (migration `0006`).

---

## What was fake in our order detail (all now real)

Found by reading the file, not from the screenshot:

1. **Status buttons only called `setState`** — never touched the API, so a
   status change looked applied and vanished on reload. `provider.updateOrderStatus`
   already existed and was simply never called.
2. **Collect Payment** — same story; `provider.collectPayment` existed unused.
3. **Hardcoded delivery address** — every order claimed
   `"Hbr layout, Bengaluru - 560064"`.
4. **Invented invoice rows** — "Express Delivery Fee (1.5x)" and "Tax (GST
   Included)", both permanently ₹0, and `totalAmount` mislabelled as "Subtotal"
   with no delivery line.

---

## Backend bug fixed: expense dates

`Expense.date` was `auto_now_add=True`, so an expense could only ever be filed
under the moment it was typed in. The seed proved the damage — it creates
"Monthly Shop Rent (July)" and Django stamped all eight rows with the current
timestamp, so the dashboard's month-to-date expense total counted last
quarter's rent as today's spending. Now `default=timezone.now` (migration
`0005`), settable so the Add Expense dialog can backdate.

---

## Running it locally (no Docker)

Docker Desktop was not running, and `docker compose up` pulls a multi-GB Flutter
SDK image, so the session used the non-Docker path:

```bash
cd backend && python manage.py runserver 8000 --noreload
cd washnlaundrycrm && flutter build web --release --no-tree-shake-icons \
  --dart-define=API_BASE_URL=http://localhost:8000/api
cd build/web && python -m http.server 8080 --bind 127.0.0.1
```

`API_BASE_URL` must be absolute here: the bundle defaults to a relative `/api`,
which only resolves behind the nginx proxy in the Docker setup. Cross-origin
works because `CORS_ALLOW_ALL_ORIGINS = True`.

**Both servers were background processes of that session and are now stopped.**

### The checkout 500 — cause and lesson

Checkout failed with:

```
django.db.utils.IntegrityError: NOT NULL constraint failed: api_order.created_by
POST /api/orders/ 500
```

Not a code bug. The server was started with `--noreload` *before* `created_by`
was added, then the migration ran. The database had the new `NOT NULL` column
while the process still held the old model in memory, so the INSERT omitted the
column — and Django keeps field defaults in Python, not at the DB level, so
there was nothing to fall back on.

**Lesson: `--noreload` means any model change needs a manual restart.** After
restarting, checkout was verified end-to-end through the UI (`#WASH-00016`,
Walk-in customer, Store Pickup, ₹15). Both test orders created during
verification were deleted afterwards.

---

## Open items

### Still hardcoded literals

| Screen | Literal |
|---|---|
| Attendance | `_staff` |
| Payroll | `_staffPayroll` |
| Reports | derives from the Attendance / Payroll literals |

Reports should come last, since it feeds off the other two.

### Deliberately left alone

**Settings, Apps and Subscription stay disabled** (`disabled: true`, "Soon"
chip). Settings was taken out on purpose in `3bce9e4` and the user confirmed it
stays that way. Re-enabling Settings is a two-line revert: flip the flag in
`sidebar_navigation.dart` and restore `case 13` plus its import in `main.dart`.

### Known divergences not yet addressed

- **Order number prefix.** Local DB generates `WASH-00016`; the live app uses
  `WA3P-00002`, derived differently from the shop name `washing`. Our
  `Shop.order_prefix` holds `WASH`.
- **Sidebar shape.** Live has 8 items; ours has 14, promoting Staff /
  Attendance / Payroll / Expenses / Reports / Scan to top level. All of those
  are paid-plan features that silently redirect to `/dashboard` on the live Free
  account. CLAUDE.md calls this the biggest structural divergence and it is
  still unresolved — the clone targets neither the Free surface nor the Business
  one.

### Caveats on what can be cloned at all

- The live account is **Free plan**. `/manage-staff`, `/attendance`, `/payroll`,
  `/expenses`, `/reports`, `/scan`, `/settings/public-page` and
  `/settings/offers` all **silently redirect to `/dashboard`**. Our versions of
  those screens are invention, not clones. Matching them needs a paid account.
- **Only a human can sign in** (CLAUDE.md), and the app allows one active
  session per account.
- The **`Edit` order dialog is our own design** — the live one was never opened,
  because clicking Edit would have put a real order into an edit state. It edits
  header fields our model carries and is deliberately *not* a line-item editor.
- **Only a store-pickup order has been seen.** The delivery-side step labels
  come from the audit's earlier capture, not from direct observation. Opening a
  `delivery home` order would confirm them.
