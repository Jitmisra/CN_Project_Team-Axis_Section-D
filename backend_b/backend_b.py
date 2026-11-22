#!/usr/bin/env python3
import hashlib, json, sys, signal
from http.server import BaseHTTPRequestHandler, HTTPServer

BACKEND_ID = "B"
PORT = 3002

# MUST be byte-identical on A and B
SHARED_INFO = json.dumps(
    {"service": "cnteam", "version": "2.0"},
    sort_keys=True, separators=(",", ":")
).encode()

class Handler(BaseHTTPRequestHandler):
    def _route(self):
        if self.path == "/":
            return 200, f"Backend {BACKEND_ID} is running\n".encode(), "text/plain"
        if self.path == "/api/status":
            return 200, json.dumps({"backend": BACKEND_ID, "status": "ok"}).encode(), "application/json"
        if self.path == "/api/info":
            return 200, SHARED_INFO, "application/json"
        return 404, b'{"error":"not found"}', "application/json"

    def _handle(self, head):
        status, body, ctype = self._route()
        etag = '"' + hashlib.sha256(body).hexdigest()[:16] + '"'
        inm = [t.strip() for t in self.headers.get("If-None-Match", "").split(",") if t.strip()]
        not_modified = status == 200 and (etag in inm or "*" in inm)
        self.send_response(304 if not_modified else status)
        self.send_header("Content-Type", ctype)
        self.send_header("X-Backend", BACKEND_ID)
        self.send_header("Cache-Control", "max-age=60")
        if status == 200:
            self.send_header("ETag", etag)
        if not not_modified:
            self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if not head and not not_modified:
            self.wfile.write(body)

    def do_GET(self):
        self._handle(head=False)

    def do_HEAD(self):
        self._handle(head=True)

    def log_message(self, fmt, *args):
        print(f"[Backend {BACKEND_ID}] {self.address_string()} - {fmt % args}", flush=True)

def signal_handler(sig, frame):
    print(f"\n[Backend {BACKEND_ID}] Shutting down gracefully...", flush=True)
    sys.exit(0)

if __name__ == "__main__":
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    server = HTTPServer(("0.0.0.0", PORT), Handler)
    print(f"Backend {BACKEND_ID} listening on 0.0.0.0:{PORT}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        print(f"[Backend {BACKEND_ID}] Server stopped.", flush=True)
