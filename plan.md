# Plan: Rider tracking in washnlaundry (GeoTrack + DeliveryBoy), tested in git worktrees

## Context
washnlaundry (`sipu/washnlaundry/crm`, Django/DRF + Flutter Web) already has `HOME_PICKUP`/`HOME_DELIVERY` orders, an
`address`, `assigned_agent` (Staff), and pickup/delivery `TimeSlot`s, but no coordinates, no rider location and no
customer-facing tracking. Two existing projects cover the missing pieces:
- **GeoTrack** (`geo_tracking_app`): `tracking_core` SDK, `maps_osm` (flutter_map + OSM tiles), `DriverSimulator`
  (producer) + `LiveTrackingView` (consumer), pluggable `LocationBackend`.
- **DeliveryBoy** (`deliveryboy`): rider app with OSM/Nominatim/OSRM, `deliveryboy://task?payload=` ingestion,
  proof-of-delivery checklist, completion webhook. Sample payload: `docs/sample_live_task.json`.

Goal: order → rider task → rider GPS → customer live map → completion back into the order. Nothing here has been
simulated yet; the first deliverable is a working producer/consumer run on OSM before any production wiring.

## Architecture
1. **Django (washnlaundry) is the hub.** New app module `crm/backend/api/dispatch/`:
   - Models (tenant-scoped via `TenantModel`): `Order.pickup_lat/lng`, `drop_lat/lng` (nullable); `RiderTask`
     (order FK, kind PICKUP|DELIVERY, status, otp, rider=Staff); `RiderLocation` (task FK, lat, lng, ts; keep last N).
   - Endpoints: `POST /api/orders/<id>/dispatch/` (build task JSON in DeliveryBoy's schema), `POST /api/rider/location/`
     (producer ingest, rider auth), `GET /api/customer/orders/<id>/track/` (consumer; latest point + task status, polled
     every ~5 s, no new infra), `POST /api/rider/webhook/complete/` (DeliveryBoy's `postCompletionWebhook` target;
     HMAC-signed, advances Order status to OUT_FOR_DELIVERY/DELIVERED, stores POD).
   - Reuse `auth.py` roles (rider = `staff`), `middleware.py` tenancy, `api/urls.py` router.
2. **Producer** = DeliveryBoy (and DriverSimulator in tests) posting to `/api/rider/location/`.
   Add a `DjangoLocationBackend` implementing GeoTrack's `LocationBackend` in a new package.
3. **Consumer** = washnlaundrycrm Flutter Web `/my/orders/:id` screen embedding `tracking_core`'s `LiveTrackingView` +
   `maps_osm`. Add `go_router` route in `router.dart`, `ApiService.fetchTrack`. Depend via path/git dependency.
4. **Geocoding**: coordinates captured at order creation with Nominatim (rate-limit, cache on Order); routing via OSRM.

## Phases (each merged only after its worktree check passes)
- **P0 Simulation (no production code):** prove the loop on OSM.
- **P1 Backend:** fields + migrations, dispatch endpoints, tests (`test_dispatch.py`, tenant + RBAC cases).
- **P2 Consumer:** customer tracking screen using GeoTrack packages.
- **P3 Rider side:** DeliveryBoy `feature/django-backend` — swap Firestore GPS write for the Django endpoint, point
  task ingestion at the dispatch payload, keep the webhook.
- **P4 Owner view:** CRM order detail shows rider position / assign rider.

## Git worktrees (isolation for testing)
washnlaundry already has worktrees; add new ones from branch `develop`, outside the working tree:
```
git -C sipu/washnlaundry worktree add ../washnlaundry-wt-dispatch -b feat/rider-dispatch develop
git -C geo_tracking_app   worktree add ../geo_tracking_app-wt-django -b feat/django-backend
git -C deliveryboy        worktree add ../deliveryboy-wt-django -b feat/django-backend
```
- Run Django from the dispatch worktree on a throwaway SQLite (`DJANGO_DATABASE_URL` unset, `seed_db.py` is safe there
  because it is a separate db file) — never against prod Neon.
- `geo_tracking_app` currently fails git's "dubious ownership" check: needs
  `git config --global --add safe.directory C:/Users/abhi3/Documents/work/geo_tracking_app` (confirm with user first).
- DeliveryBoy's current branch has uncommitted screenshots and `web/`; the worktree leaves them untouched.
- Cleanup: `git worktree remove <path>`; branches merged via PR only on user approval. No pushes without approval.

## Verification (the producer/consumer simulation)
1. **Unit/API:** `python manage.py test api.test_dispatch` — producer posts pings, consumer endpoint returns latest,
   cross-tenant and customer-of-another-order requests get 403/404, bad webhook signature rejected.
2. **Simulation script** `crm/backend/scripts/simulate_rider.py`: fetch an OSRM route between two real Patna
   coordinates, play it back at 8 m/s (same maths as `DriverSimulator`), POST pings; a second consumer loop polls
   `/track/` and asserts monotonic progress and arrival within 50 m of the destination. OSM only, no API keys.
3. **GeoTrack:** `flutter test` in `packages/tracking_core` and `backend_fake` (19 + 11 existing) plus a new test for
   `DjangoLocationBackend` against a local server.
4. **End-to-end UI:** run Django (worktree) + Flutter Web customer screen in Chrome; drive the simulator; screenshot the
   marker moving. DeliveryBoy: `flutter test` (existing 153) and webhook posts to local Django.
5. Report results faithfully, including anything that fails or is skipped.

## Open points to confirm at approval
- Poll (5 s) vs websocket/SSE: plan starts with polling (works on Render free tier + Cloudflare proxy).
- Whether to run P0 first and stop for review before touching production code (recommended).
