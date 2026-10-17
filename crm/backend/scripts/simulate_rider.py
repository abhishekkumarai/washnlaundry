"""P0 producer/consumer simulation on OpenStreetMap data (stdlib only, no keys).

Producer: replays a real OSRM route at constant speed, POSTing pings (same maths
as GeoTrack's DriverSimulator). Consumer: polls the track endpoint and checks
progress. The hub here is a stand-in for the future Django /api/rider/location/
and /api/customer/orders/<id>/track/ endpoints; swap --base to point at Django.

    python simulate_rider.py                # self-hosted stub hub
    python simulate_rider.py --base http://127.0.0.1:8000/api --no-stub
"""
import argparse, json, math, threading, time, urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

PICKUP = (25.5941, 85.1376)   # Patna: Gandhi Maidan area (lat, lng)
DROP = (25.6100, 85.1600)

def haversine(a, b):
    r = 6371000.0
    p1, p2 = math.radians(a[0]), math.radians(b[0])
    dp, dl = p2 - p1, math.radians(b[1] - a[1])
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h))

def osrm_route(a, b):
    url = (f"https://router.project-osrm.org/route/v1/driving/{a[1]},{a[0]};{b[1]},{b[0]}"
           "?overview=full&geometries=geojson")
    with urllib.request.urlopen(url, timeout=20) as r:
        coords = json.load(r)["routes"][0]["geometry"]["coordinates"]
    return [(lat, lng) for lng, lat in coords]

def walk(route, step_m):
    """Yield points every step_m metres along the polyline, ending on the last vertex."""
    carry = 0.0
    yield route[0]
    for a, b in zip(route, route[1:]):
        seg = haversine(a, b)
        d = step_m - carry
        while d <= seg:
            t = d / seg
            yield (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
            d += step_m
        carry = seg - (d - step_m)
    yield route[-1]

class Hub(BaseHTTPRequestHandler):
    last = {}
    def log_message(self, *a): pass
    def _send(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
    def do_POST(self):
        data = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        Hub.last = {**data, "received_at": time.time()}
        self._send(201, {"ok": True})
    def do_GET(self):
        self._send(200, Hub.last or {"status": "waiting"})

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="http://127.0.0.1:8765/api")
    ap.add_argument("--no-stub", action="store_true")
    ap.add_argument("--speed", type=float, default=8.0, help="m/s")
    ap.add_argument("--interval", type=float, default=0.05, help="wall seconds between pings (sped up)")
    ap.add_argument("--django", action="store_true",
                    help="drive the real Django API (needs --task-id --tenant --token --order)")
    ap.add_argument("--task-id"); ap.add_argument("--tenant"); ap.add_argument("--order")
    ap.add_argument("--token", help="customer Bearer token for the consumer side")
    args = ap.parse_args()

    if args.django:
        args.no_stub = True
        args.base = args.base if "8765" not in args.base else "http://127.0.0.1:8000/api"
    if not args.no_stub:
        srv = HTTPServer(("127.0.0.1", 8765), Hub)
        threading.Thread(target=srv.serve_forever, daemon=True).start()

    route = osrm_route(PICKUP, DROP)
    length = sum(haversine(a, b) for a, b in zip(route, route[1:]))
    pings = list(walk(route, args.speed * 2))  # one ping per 2 simulated seconds
    print(f"OSRM route: {len(route)} vertices, {length:.0f} m -> {len(pings)} pings")

    seen, errors = [], []
    done = threading.Event()

    def consumer():
        while not done.is_set():
            try:
                if args.django:
                    rq = urllib.request.Request(f"{args.base}/customer/orders/{args.order}/track/",
                                                headers={"Authorization": f"Bearer {args.token}"})
                    with urllib.request.urlopen(rq, timeout=5) as r:
                        loc = json.load(r).get("location")
                    if loc:
                        # Django does not echo our seq; the server-side recorded_at is monotonic per ping.
                        seen.append((loc["at"], loc["lat"], loc["lng"]))
                else:
                    with urllib.request.urlopen(args.base + "/track/", timeout=5) as r:
                        t = json.load(r)
                    if "lat" in t:
                        seen.append((t["seq"], t["lat"], t["lng"]))
            except Exception as e:
                errors.append(str(e))
            time.sleep(args.interval / 2)

    c = threading.Thread(target=consumer); c.start()
    for i, (lat, lng) in enumerate(pings):
        body = {"seq": i, "lat": lat, "lng": lng, "ts": time.time()}
        headers = {"Content-Type": "application/json"}
        url = args.base + "/location/"
        if args.django:
            body = {"task_id": args.task_id, "lat": lat, "lng": lng}
            headers["X-Tenant-ID"] = args.tenant
            url = args.base + "/rider/location/"
        req = urllib.request.Request(url, method="POST", data=json.dumps(body).encode(), headers=headers)
        urllib.request.urlopen(req, timeout=5).read()
        time.sleep(args.interval)
    time.sleep(args.interval * 3)
    done.set(); c.join()

    seqs = [s for s, _, _ in seen]
    last = seen[-1] if seen else None
    end_gap = haversine((last[1], last[2]), DROP) if last else float("inf")
    checks = {
        "consumer received updates": len(seen) > 5,
        "seq never goes backwards": seqs == sorted(seqs),
        "consumer saw final ping": bool(last) and (args.django or last[0] == len(pings) - 1),
        "arrived within 50 m of drop": end_gap < 50,
        "no consumer errors": not errors,
    }
    print(f"consumer observed {len(seen)} updates, final gap to drop {end_gap:.1f} m")
    for k, v in checks.items():
        print(("PASS " if v else "FAIL ") + k)
    raise SystemExit(0 if all(checks.values()) else 1)

if __name__ == "__main__":
    main()
