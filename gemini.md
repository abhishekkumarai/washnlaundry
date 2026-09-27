# LaundryBill CRM — Antigravity Workspace Context & Profile Instructions

## 🌐 Chrome Browser Configuration
Whenever performing browser automation, session verification, or screenshot captures using the Browser Agent, use the following Chrome profile settings:

- **Executable Path**: `C:\Program Files\Google\Chrome\Application\chrome.exe`
- **User Data Dir**: `C:\Users\abhi3\AppData\Local\Google\Chrome\User Data`
- **Profile Directory**: `Default`
- **Target URL**: `https://app.laundrybill.com/dashboard`

---

## 🛠️ Project Architecture & Tech Stack

### 1. Frontend (Flutter Web)
- **Directory**: `washnlaundrycrm/`
- **Framework**: Flutter Web SPA (Multi-screen dashboard, fast POS billing, responsive 14-screen sidebar navigation)
- **State Management**: `Provider` (`AppProvider`)
- **API Integration**: REST API Service (`lib/services/api_service.dart`) fetching from `http://localhost:8000/api/`

### 2. Backend (Django REST Framework & SQLite)
- **Directory**: `backend/`
- **Framework**: Django REST Framework (Python 3.11)
- **Database**: SQLite `db.sqlite3` with populated seed database (`backend/seed_db.py`)
- **API Endpoints**:
  - `GET/POST /api/orders/` — Orders directory & POS creation
  - `GET /api/items/` — Garment rate items & service categories
  - `GET /api/dashboard/stats/` — Real-time revenue & order statistics

### 3. Docker Containerization
- **File**: `docker-compose.yml`
- **Frontend Port**: `http://localhost:8080` (Nginx serving compiled Flutter SPA)
- **Backend Port**: `http://localhost:8000` (Gunicorn/Django serving REST API)

### 4. Production Deployment & Git Pre-Push Hook
- **Backend**: Render service `laundrybill-backend` (`https://laundrybill-backend.onrender.com/api`) backed by Neon Postgres (`washnlaundry-db`, pdx1).
- **Frontend**: Vercel project `washnlaundrycrm` in team `3abhishekkumar-3596's projects` (`3abhishekkumar@gmail.com`), served at `https://washnlaundry.com`, `https://app.washnlaundry.com`, and `https://washnlaundrycrm-eight.vercel.app`.
- **Automated Deploy Script**: `scripts/deploy_vercel.js` verifies the build and deploys `washnlaundrycrm/build/web` to Vercel production.
- **Git Pre-Push Hook**: `.git/hooks/pre-push` intercepts `git push origin main`, runs Django and Flutter test suites, compiles Flutter Web release bundle (`--dart-define=API_BASE_URL=https://laundrybill-backend.onrender.com/api`), and deploys to Vercel before the commit reaches `origin/main`.
- **Git Provider Link**: Direct GitHub auto-builds on Vercel are unlinked to prevent empty git builds from overwriting the compiled Flutter bundle with 404s.

---

## 📱 Modules & Features Implemented

1. **Dashboard (`/dashboard`)**: Summary cards, search bar, 14-day revenue bar chart, real-time status pipeline.
2. **New Order POS (`/new-order`)**: Garment item grid selector, express rate toggle ($1.5\times$), cart sidebar, WhatsApp receipt share.
3. **Orders Directory (`/orders`)**: 11 filter status tabs (*All, Placed, Processing, Ready, Out for delivery, Partial, Delivered, Cancelled, Overdue, Scheduled, Unpaid*), order list with status badges, and Order Detail route.
4. **Order Detail Screen (`/orders/:id`)**: Step progress bar (*Placed → Washing → Ready → Out for Delivery → Delivered*), customer profile card, garment itemization, subtotal & tax breakdown, WhatsApp bill share button, thermal print receipt, and status action buttons.
5. **Customers (`/customers`)**: Summary KPI cards (*Total, Active, New*), customer table with lifetime spending and dues, WhatsApp chat button, and `+ Add Customer` modal dialog.
6. **Services & Pricing (`/services` / `/inventory`)**:
   - **Items Tab**: Garment rate cards across 7 categories (*Ironing, Wash & Fold, Wash & Iron, Dry Cleaning, Household, Shoe Cleaning, Premium*) with item price edit dialogs.
   - **Service Areas Tab**: `Detect My Location` button, area adder, and locality chips.
   - **Pickup Schedule Tab**: Buffer time input (minutes), time slot toggles (*9-11 AM, 11 AM-1 PM, 2-4 PM, 4-6 PM*).
   - **Delivery Schedule Tab**: Buffer time input (minutes), time slot toggles (*9-11 AM, 11 AM-1 PM, 2-4 PM, 4-6 PM*).
7. **Staff Management (`/manage-staff`)**: Employee roster, role badges (*Washer, Ironer, Manager, Driver*), KPI metrics, and Add Staff Modal.
8. **Settings (`/settings`)**: Business Profile form, sub-sidebar options, contact inputs, and interactive Store Location Map container.
9. **Navbar Profile Footer**: User initial avatar (`AK`), shop title (`washing`), role subtitle (`Admin`), and logout trigger button.

---

## 📸 Preserved Audit Screenshots (`screenshots/`)

- `dashboard.png` & `docker_verified.png`
- `new_order.png`
- `orders.png` & `orders_scrolled_bottom.png`
- `order_details_live.png`
- `customers.png`, `customers_live.png`, `customers_scrolled_bottom.png`
- `services.png`, `services_live.png`, `services_scrolled.png`
- `items_scrolled_bottom.png`, `areas_scrolled_bottom.png`, `pickup_scrolled_bottom.png`, `delivery_scrolled_bottom.png`
- `staff.png` & `staff_scrolled.png`
- `settings.png` & `settings_scrolled.png`
- `full_audit_verified.png`

## JIRA
- Always allow jira MCP.

## CHROME-DEVTOOLS-MCP
- Always allow it.