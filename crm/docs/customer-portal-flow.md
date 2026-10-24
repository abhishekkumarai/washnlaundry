# Customer portal: flow and screens

The customer portal is the Flutter build on `customer.washnlaundry.com` (locally
http://localhost:8081, or `--dart-define=FORCE_CUSTOMER_HOST=true`). Screens live in
`washnlaundrycrm/lib/screens/portal/`, routes in `portalRoutes()` / `portalRedirectFor` in
`washnlaundrycrm/lib/router.dart`. This file is the target design. `crm/CLAUDE.md`
("Customer portal") describes what is built today.

## The flow

```
Sign in / sign up ─▶ Your location ─▶ Nearby laundries ─▶ Laundry page (select / join)
                                                                  │
        ┌─────────────────────────────────────────────────────────┘
        ▼
   Book: Services ─▶ Pickup time ─▶ Address ─▶ Review & place ─▶ Order placed
```

- Each step has one job and one primary button. Booking steps 2 to 4 hide the tab bar, the way a
  checkout does, and Back always returns to the previous step.
- People who have done a step before skip it. A remembered location skips **Your location**, a
  remembered laundry skips the list, and a saved address is preselected.
- A shop link or QR (`/s/<slug>`) goes from sign-in straight to that laundry's page, skipping
  the location and list steps.

## Tabs (signed in, laundry chosen)

| Tab | Route | Holds |
|---|---|---|
| Book | `/book` | The booking flow (home after sign-in) |
| Orders | `/orders` | **Current** (open orders, status line) and **Past** (calendar + pages) |
| Help | `/help` | FAQ, contact the laundry, report an issue on an order |
| Profile | `/profile` | Name, phone, email, addresses, current laundry + Change, Sign out |

- Phone (< 600 px): bottom `NavigationBar` with the four tabs.
- Wide (≥ 900 px, `PortalShell.wide`): the same four tabs as links in `PortalNavBar`. No sidebar
  and no bottom bar.
- 600–899 px: phone layout, with content capped at 640 px and centred.

## Breakpoints and grid

| | Phone < 600 | Tablet 600–899 | Wide ≥ 900 |
|---|---|---|---|
| Columns | 4, 16 px gutters | 8, capped 640 | 12, capped 1120 (content 760) |
| Navigation | bottom tabs | bottom tabs | top links |
| Booking | one column, sticky footer CTA with running total | same | steps on the left, sticky summary card on the right (services, slot, address, total, CTA) |
| Lists | full-width rows | full-width rows | rows, max 760 |

- Spacing comes from an 8 px base: 8 / 16 / 24 / 32.
- Type uses four sizes at most per screen (12 / 14 / 16 / 22), with 28 only for the order-placed
  headline. Prices, dates and counts use tabular figures.
- The theme is light, using `AppColors` from `lib/theme/app_theme.dart`. Groups are separated by
  space first, then hairlines. No gradients, glass or emoji.

## Routes: old → new

| Old | New |
|---|---|
| `/` → `/account` | `/` → `/book` |
| prompt inside `/find` | `/location` (own screen) |
| `/find` | `/find`, the nearby list only, with the chosen location and a Change link |
| `/s/:slug`, `/join` | `/s/:slug` laundry page with Select / Join inline; `/join` stays as a fallback |
| `/book`: Items, Pickup time, Address, Review | `/book`: **Services**, Pickup time, Address, Review |
| `/orders`, `/orders/:no` | same; Current / Past tabs; `/orders/:no?placed=1` shows the confirmation |
| `/account`, `/profile`, `/addresses` | `/profile` (the account overview folds in); `/addresses` is its sub-page; `/account` redirects to `/profile` |
| — | `/help`, `/help/report?order=<no>` |

Gate (`portalRedirectFor`), in this order:
1. Signed out: only `/login`, `/verify`, `/reset` and `/s/<slug>` open. Anything else goes to `/login`.
2. Signed in, no laundry, no remembered location choice → `/location`.
3. No laundry → `/find`.
4. Not a customer of that laundry → `/join` (or the Join form on `/s/<slug>`).
5. `/login` or `/join` once all of that is done → `/book`.

## Screen inventory

For each screen: its job, its content ranked **P**rimary / **S**econdary / **T**ertiary, and its states.

### 1. Sign in / sign up — `/login`
Job: get the customer signed in, whether or not they have an account.
- P: Email field → "Send code", or "Continue with Google".
- S: Brand mark and one line about what the portal does.
- T: Terms and privacy links.
- States: sending, code sent (→ 2), Google error, rate-limited.

### 2. Verify code — `/login` (code stage), `/verify`
Job: type the 6-digit code.
- P: Six-digit input that submits automatically when full.
- S: "Sent to <email>" with a Change link.
- T: Resend timer.
- States: wrong code, expired, too many tries.

### 3. Your location — `/location`
Job: tell us where to look for laundries.
- P: "Use my current location" (browser geolocation).
- S: Or type a PIN code / area.
- T: Why we ask, in one line.
- States: permission denied (falls back to typing), locating…, unknown PIN code.
- Remembered in `PortalProvider` (lat/lng or pin, in prefs).

### 4. Nearby laundries — `/find`
Job: pick a laundry.
- P: List of laundries, nearest first, each showing name, area, distance and whether it serves
  your PIN code. Laundries you've already joined come first.
- S: The chosen location with a Change link, and search by name.
- T: "Not listed? Ask your laundry for its link."
- States: none nearby (shows the full list with distances), loading skeleton, offline.

### 5. Laundry page / join — `/s/:slug`
Job: confirm this is the laundry and become its customer.
- P: **Select** (already joined) or **Join** (name and mobile, prefilled when another laundry
  already has your details).
- S: Name, address, distance, services offered, pickup PIN codes.
- T: Phone and email.
- States: laundry not taking online customers, already a customer, phone pending approval.

### 6. Book: Services — `/book` step 1
Job: choose what needs cleaning.
- P: Service categories (`GarmentCategory`: Wash & fold, Dry clean, Iron…) as the first choice,
  then that category's items with + / − steppers.
- S: Sticky footer (phone) or summary card (wide) showing pieces · total · "Continue to pickup time".
- T: "Picks up from <PIN codes>".
- States: laundry has no services listed, empty cart (CTA disabled).

### 7. Book: Pickup time — step 2
Job: pick a pickup slot.
- P: Day strip (today plus the next 6 days) and that day's slots, with full slots disabled.
- S: The chosen slot echoed in the footer ("Tomorrow, 9–11 AM").
- T: "Slots close a little before they start."
- States: no slots that day, all slots full.

### 8. Book: Address — step 3
Job: where we pick up (and deliver back to).
- P: Saved addresses, served ones selectable and the default preselected.
- S: "Add address" (map pin + form, `address_editor.dart`).
- T: Note that delivery comes back to the same address.
- States: no saved address, address outside the laundry's PIN codes.

### 9. Book: Review & place — step 4
Job: confirm and place the order.
- P: **Place order**.
- S: Blocks for Services / Pickup / Address, each with Edit, plus an optional note.
- T: "You pay when your clothes come back."
- States: slot filled meanwhile (back to step 2), placing…, error.

### 10. Order placed — `/orders/:no?placed=1`
Job: reassure and show what happens next.
- P: Headline "Pickup booked" with the order number, slot and address.
- S: Status line (Booked → Cleaning → Ready → Out for delivery → Delivered).
- T: "Book another", "Go to orders".

### 11. Orders — `/orders`, `/orders/:no`
Job: see where an order is and what was done before.
- P: **Current** tab: open orders (not `DELIVERED` / `CANCELLED`) with a status progress line,
  next step and slot.
- S: **Past** tab: the existing month calendar with dots, a day filter, and pages of 10.
- T: Order detail shows items, totals, timeline, address, and "Need help with this order?" →
  `/help/report?order=<no>`.
- States: no current orders ("Book a pickup"), no history, loading, error.

### 12. Help & Support — `/help`, `/help/report`
Job: get an answer, or reach the laundry.
- P: FAQ (expanding questions on pricing, pickup slots, payment on delivery, damaged or lost
  items, cancelling).
- S: Contact the laundry with Call (`tel:`), WhatsApp (`wa.me`) and Email (`mailto:`), using the
  chosen laundry's details.
- T: Report an issue: pick an order, a category (missing item, damage, late, billing, other) and
  a message, then Submit. This saves an `OrderIssue` and emails the laundry.
- States: laundry has no phone/email (those buttons are hidden), report sent, report error.

### 13. Profile — `/profile`, `/addresses`
Job: manage who you are and where we pick up.
- P: Name, phone, email (phone editable).
- S: Addresses (count and default) → `/addresses`; current laundry with Change → `/find`.
- T: Sign out.

## Backend changes this needs

- `GET customer/orders/?state=current|past` filter for the two Orders tabs.
- `customer/shops/<slug>/` returns the laundry's phone, WhatsApp and email for Help.
- `OrderIssue` model + `POST customer/orders/<no>/issues/`: the customer's own order only,
  throttled, emails `Shop.email`. Follow-up (not in this round): show and resolve issues in the
  CRM; for now they are visible in Django admin only.

## Design direction and mockups

**Stitch project:** https://stitch.withgoogle.com/projects/326722180970203396 ("WashnLaundry
customer portal", design system "WashnLaundry Claim Ticket").

### Direction: the claim ticket
This is a product UI, not a marketing page. The design serves booking and is not there to decorate.
- **Palette:** restrained, the app's own `AppColors`. Warm paper `#F8F7F5`, white cards with
  `#E4E0D8` hairlines, ink `#141A24`, navy `#182C4F` for primary actions and selected states, blue
  `#2563EB` only for links, focus and the active tab (under 10% of the surface), green only for
  "Delivered" and "Picks up here".
- **Type:** IBM Plex Sans everywhere, plus **IBM Plex Mono** only for order numbers, prices, times
  and PIN codes (tabular figures). Section labels are 12 px uppercase, letter-spaced and muted.
- **The one memorable element:** every order is drawn as a laundry **claim ticket**. That means a
  white card with a punched hole at the top-left, and a dashed perforation separating the stub
  (order number in large Plex Mono plus a status pill) from the body (items, slot, status line). It
  appears on Order placed, Orders → Current, the Order detail header and the desktop Review summary.
  Everything else stays quiet.
- **Motion:** restraint. Step changes slide 150–200 ms, chips and tiles change state with no
  bounce, and nothing animates on load.
- **References** (21st.dev via Magic): "Booking Slot Calendar" for the week strip and slot taps,
  "Meeting Booking Calendar" for the perforated "booked" ticket, "Order Status Card" for the
  5-dot status line, and "Tabbed FAQ Accordion" for FAQ with a contact callout. All were remixed,
  none copied.

### Screens in Stitch
Phone (390): Sign in · Enter your code · Your location · Nearby laundries · FreshFold Laundry
(laundry page / join) · Book: Services · Book: Pickup time · Book: Address · Book: Review & place
order · Order placed · Orders — Current · Orders — Past · Order detail · Help · Report an issue ·
Profile.

Desktop (1280): Sign in (split: pitch left, form card right) · Nearby laundries · Book: Services
(steps left, sticky "Your pickup" summary right) · Book: Review (claim-ticket summary right) ·
Orders · Order detail (ticket + items left, pickup and help cards right) · Help (FAQ left, contact
and report cards right) · Profile. Desktop versions of Code, Location, Pickup time and Address
reuse the phone layout centred at 640 px, inside the same top bar.

### Decisions from the review (these override the mockups)
- **No sidebar on desktop.** The top bar links (Book · Orders · Help · Profile) are the only
  navigation, and pages are capped at 1120 (two-column) or 760 (single column). Two mockups (Orders,
  Help) still show a sidebar, which would duplicate the top links.
- **Copy comes from this file, not from the mockups.** Stitch kept inventing labels ("CLAIM
  TICKET", "Pickup & Delivery FREE", "Standard rider", slot counts, hub names). Build only the
  content in the screen inventory above.
- The step label appears once, above the step bar (the Pickup time mockup repeats it in the
  header).
- Status line labels: Booked · Cleaning · Ready · Out for delivery · Delivered (two lines on
  phones if needed, never "Out"). The mockups' "Picked up" step does not exist in the data: the
  order statuses are PLACED → PROCESSING → IRONING → READY → OUT_FOR_DELIVERY → DELIVERED, and
  Processing and Ironing are both shown as "Cleaning" (`portalStepIndex` in `portal_ticket.dart`).
- The laundry page's Join opens the existing `/join` step (auto-join with details from another
  laundry, else the name + mobile form) rather than an inline form.
- Sign out is an outlined ink button, never red.
