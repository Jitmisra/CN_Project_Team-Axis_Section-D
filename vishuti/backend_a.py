#!/usr/bin/env python3
import json
import sys
import signal
from http.server import BaseHTTPRequestHandler, HTTPServer

BACKEND_ID = "A"
PORT = 3001

class Handler(BaseHTTPRequestHandler):
    def _send(self, status, body, content_type="application/json"):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("X-Backend", BACKEND_ID)
        self.send_header("Cache-Control", "max-age=60")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/":
            self._send(200, f"Backend {BACKEND_ID} is running\n".encode(), "text/plain")
        elif self.path == "/api/status":
            payload = json.dumps({"backend": BACKEND_ID, "status": "ok"}).encode()
            self._send(200, payload)
        else:
            self._send(404, b'{"error":"not found"}')

    def do_HEAD(self):
        self.do_GET()

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
