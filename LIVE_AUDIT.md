# Live audit — app.laundrybill.com

Captured 2026-07-30 from the `washing` / Admin account (plan: **Free**). Screen-by-screen spec of the real app, for building the Flutter + Django clone.

Real app is React + Firebase (Firestore project `laundryos`). Order and customer IDs are Firestore doc IDs (`LJfbyvJZMq2nwuT6TU2f`, `pNVvh2xjbuLX6ZcvyzJ4`).

---

## Plan gating — read this first

The sidebar has **8 items**, not 14. On the Free plan these routes **silently redirect to `/dashboard`**:

`/manage-staff` · `/attendance` · `/payroll` · `/expenses` · `/reports` · `/scan` · `/settings/public-page` · `/settings/offers`

Confirmed against the plan comparison table: Staff management, Attendance, Payroll, Expenses, Reports & analytics, QR scans, Public ordering page are all paid features.

Accessible on Free: `dashboard`, `new-order`, `orders`, `orders/:id`, `customers`, `customers/:id`, `inventory`, `apps`, `settings`, `shop-settings`, `delivery-settings`, `settings/subscription`, `help`.

**Our clone puts Staff / Attendance / Payroll / Expenses / Reports / Scan in the top-level sidebar. The real app does not.** That's the biggest structural divergence.

### Plans

| | Pro | Pro+ | Business | Franchise |
|---|---|---|---|---|
| Price | mobile app only | ₹799/mo | ₹1,999/mo | ₹4,999/mo |
| Team logins | — | 4 | 15 | 15 |
| Shops | 1 | 1 | 1 | 4 |

Yearly billing = −20%. Pro is purchased in the mobile app (Play/App Store); Pro+ and above subscribe on web. Feature matrix rows: Orders/month, Customers, Team logins, Services, Order tracking, WhatsApp receipts, Staff management, Attendance, Payroll, Expenses, Reports & analytics, QR scans, Damage photos, Driver/Agent app, Plant dashboard, Public ordering page, Web dashboard.

---

## Dashboard

Top: **Quick Scan & Search** — "Find an order or customer", `Search` + `Scan Order`.

KPI row (5), each with a delta vs yesterday: Orders today · Revenue today · Ready for pickup (`● live`, "in queue") · Overdue ("needs action") · Customers ("new today").

- **Revenue** — bar chart, last 14 days, with "▼ 100% vs prior" and day-of-month axis labels.
- **Order pipeline** — "Live across stages": Received / Processing / Ready / Out for delivery.
- **Store Health** — "Operational performance · last 30 days", 0–100 SCORE with a verdict label ("Needs attention"), and On-Time Delivery, On-Time Pickup, Order Flow, Collection Rate. Footer "N active orders on schedule" + `View reports`.
- **Revenue Analytics** — "This month overview": COLLECTION PROGRESS bar (% collected, ₹ collected / ₹ pending), then Sales, Collected, Uncollected, Monthly Expenses, Net Profit. `View Full Reports`.
- **Recent activity** — count badge + `View all`. Columns: TIME · ORDER · CUSTOMER · TYPE · PAYMENT · STATUS.
- **Needs attention** — Scheduled ahead ("Booked for a later day") / Overdue orders ("Past scheduled window") / Unpaid invoices ("₹N outstanding") / Online orders ("From public page").
- **Order channels** (today) — Store Pickup, Home Pickup, Home Delivery, Online.
- **Staff attendance** — Present / Absent / Leave, "Total staff: N".

We are missing: Store Health scoring, Revenue Analytics collection progress, Needs attention, Order channels, and the staff-attendance widget.

---

## Orders

Header: `Orders  N Total`, date-range select (**All time / Today / This Week / This Month / Last Month**), search "Search by order ID, phone, or name", `Filters`, `Export`, `New Order`.

11 filter chips: **All · Placed · Processing · Ready · Out for delivery · Partial · Delivered · Cancelled · Overdue Orders · Scheduled · Unpaid Dues**

Table: ORDER · CUSTOMER · TYPE · STATUS · PAYMENT · TOTAL · UPDATED.
Row shows order no (`#WA3P-00001`), customer avatar + name + "N items", type (`delivery home`) with a scheduled date line (`Delivery Sat, Aug 1`), status pill, payment pill, total, relative time. Footer: "Showing N" / "No more orders".

Order numbers are **shop-prefixed and sequential** — `WA3P` (from shop name `washing`) + `-00001`. We use `LB-2001`.

---

## Order detail — `/orders/:id`

Breadcrumb `Orders / #WA3P-00001`. Actions: `WhatsApp`, `Print Receipt`.

Header: order no, status pill, type, "Placed Jul 29, 10:20 AM".

**Step progress** with timestamps: Order Placed → Processing → Ready → Delivered.

**Items** — grouped under a category heading (`SHOE CLEANING`), each line: name, **per-item status badge** (`DELIVERED`), service name, `1 × ₹200`, line total.

Totals: Subtotal · **Delivery ₹50** · Total.

**Timeline** — full audit trail including stages the step bar collapses (Out for Delivery), plus provenance: **"Created by Mobile App"**.

**Customer** card — name, phone.
**DELIVERY & ROUTE** — Expected date, **Assigned Agent** ("No agent assigned").
**Payment** card — status, Total, Amount Paid, Balance Due, `Collect Payment`.

Fields our `Order`/`OrderItem` models lack: delivery charge, expected/scheduled date, assigned agent, per-item status, created-by/source channel, and per-status timestamps for the timeline.

---

## Customers

Header: `Customers  N Total`, search "by name, phone, or email", `Export`, `Add`.
KPI cards: Total · Active · New.
Table "All customers": CUSTOMER (avatar, name, phone) · AREA · ORDERS · LIFETIME · LAST ORDER · chevron.

### Customer detail — `/customers/:id`

Breadcrumb `Customers / Me`, `New Order` button.
Header: avatar, name, phone, "Member since Jul 2026".
KPIs: Lifetime value · Total Orders · **Avg order value** · Last order.
**Order History** table: ORDER · DATE · ITEMS · STATUS · TOTAL.
**CONTACT & ADDRESSES** section.

---

## Services — `/inventory`

Header: `Services  7 Items · 79 items`, `Show Inactive`, `Download`, `Import`, `New Service`.
Tabs: **Items · Service Areas · Pickup · Delivery**.

SERVICE CATEGORIES sidebar, each with count + price range, plus `New service category`:

| Category | Items | Range |
|---|---|---|
| Ironing | 23 | 10–100 ₹ |
| Wash & Fold | 3 | 85–185 ₹ |
| Wash & Iron | 17 | 25–140 ₹ |
| Dry Cleaning | 19 | 90–700 ₹ |
| Household | 5 | 15–280 ₹ |
| Shoe Cleaning | 7 | 100–350 ₹ |
| Premium | 5 | 100–600 ₹ |

**79 items total; our seed has 35.**

Detail pane: category name + `Active` toggle, "N items in X", price range, `Items (N)` + `Add Item`.
Item card: `Active` badge · name · **unit label ("Per piece")** · **turnaround ("1d")** · `₹15 / pc`.

Units in use: `/pc`, `/kg` (Regular Cloths ₹85/kg), `/sq.ft` (Carpet Vacuum ₹15), `/set` (Sofa Cleaning ₹200). **We only model per-piece.**

`GarmentItem` needs: `unit`, `turnaround_days`, `is_active`. The real model is one row per (category, item) with a single price — not our five price columns on one row.

---

## New Order POS — `/new-order`

Left: category tabs `All` + the 7 categories.
Grid of product cards: name, `₹15`, `per pc`, an **EXPRESS** toggle, `Add to List`.
Right rail **Current order**: item count badge, customer selector (`W` avatar / "Walk-in customer" / "Tap to add a customer" / `Add`), empty state "No items yet — Tap products to add them to the order", then Subtotal, Total, `Checkout · ₹0`.

---

## Settings — `/settings`

Sub-nav: Business profile · Tax & currency · Bank details · Operations · Preferences · Subscription & billing · Payment history · Help & support · **Sign Out**. Header shows `washing / Admin` and `Save changes`.

**Business profile**: Shop Name; Contact Information (Phone `+91` — *"Registered phone number cannot be changed"*; WhatsApp Number — *"Defaults to your registered phone"*; Email — *"Registered email cannot be changed"*); Location with `Get Location` + draggable map marker; Address, City, State, PIN Code; GPS Location ("No location captured yet").

### `/shop-settings`

Superset of the above plus **Business Details** (GST Number, PAN Number), **Tax Settings** (%), **Bank Details** (Account Holder Name, Account Number, IFSC Code, Bank Name, UPI ID), and the full Delivery & Pickup block. Has a `Share` action and `Save Settings`.

### `/delivery-settings`

- **Service Areas** — detect-location button, `Add`, list of areas.
- **Pickup Time Slots** / **Delivery Time Slots** — identical widgets. "Changes save automatically." Buffer (minutes) before slot, with helper *"e.g. 30 = user cannot book 9–10 AM slot after 8:30 AM"*. Add slot = Start time + End time (**15-minute increments, 6:00 AM – 10:00 PM**) + **Capacity** ("Max orders per day for this slot; leave empty for unlimited") + `Save`.
- Default slots both sides: 9:00–11:00 AM, 11:00 AM–1:00 PM, 2:00–4:00 PM, 4:00–6:00 PM, all Capacity Unlimited.

Slot **capacity** and **buffer** are real scheduling constraints we don't model at all.

> Note: the live app has untranslated i18n keys leaking here — `settings.detectMyLocation`, `settings.noAreasAdded`. Don't reproduce the bug.

---

## Apps — `/apps`

"LaundryBill app suite · 3 apps". These correspond to the `/staff/*`, `/agent/*`, `/plant/*` route trees.

| App | Who | Platforms |
|---|---|---|
| Staff App | Front desk | iOS, Android, Web |
| Delivery Agent | Pickup & delivery | iOS, Android |
| Plant App | Washers / Pressers | Android, Web |

Detail pane: `Live` badge, description, "N active logins", version (`v3.8.0`). **PLATFORMS & DISTRIBUTION** (iOS 14+ · 58 MB; Android 8+ · 44 MB; Web · responsive — each with an On toggle). **Features** (5 included): POS order intake, Status updates, Customer lookup, Attendance clock, Tag printing. **ACCESS & ROLES**: Staff, Manager. **RELEASE & SHARE**: current version, last updated, `Share via WhatsApp`, `Copy Link`, `Open`.

---

## Help — `/help`

Contact support: Call `+919666211137` · WhatsApp `919666211137` · Email `hello@laundrybill.com`.
"Guides by page": New Order, Staff & App Logins — each a video tutorial.

---

## Not captured

Gated on this plan or not reachable: `/reports`, `/manage-staff`, `/attendance`, `/payroll`, `/expenses`, `/scan`, `/settings/public-page`, `/settings/offers`, `/settings/payment-history`, `/shops`, `/shops/new`.

Public routes never visited: `/track`, `/track/:trackingId`, `/track/:shopId/:publicId`, `/receipt/:orderId`, `/order/:shopSlug`, `/:shopSlug`.

Portals never visited: `/staff/*`, `/agent/*`, `/plant/*`, `/super-admin/*`, `/team/*`.

To capture these, either upgrade the account or reason from `app_index.js`.

---

## Capture notes

- **The app enforces one active session per account.** Signing in elsewhere (another tab, the phone app) kills this one with *"You were signed out because your account was signed in on another device."* Close every other session before a capture run.
- Auth restore takes ~10–30 s; the app renders `/login` first and swaps in once `onAuthStateChanged` fires. Console line `[Auth] onAuthStateChanged fired, user: <uid>` is ground truth.
- The **Poper Blocker** extension (`bkkbcggnhapdmkeljlodobbkopceiche`) throws repeated `AbortError: The user aborted a request` into the page and breaks the profile fetch → `Failed to load profile` → forced sign-out. Disable it for this domain.
- Gated routes redirect to `/dashboard` **without any message**, so always check the returned URL, not just the content.
- `--remote-debugging-port` is unavailable: Chrome ≥136 refuses it on the default profile dir (Chrome here is 150).
