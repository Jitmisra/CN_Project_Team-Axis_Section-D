#!/usr/bin/env python3
import json
from http.server import BaseHTTPRequestHandler, HTTPServer

BACKEND_ID = "B"
PORT = 3002

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

    def log_message(self, fmt, *args):
        print(f"[Backend {BACKEND_ID}] {self.address_string()} - {fmt % args}")

if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", PORT), Handler)
    print(f"Backend {BACKEND_ID} listening on 0.0.0.0:{PORT}")
    server.serve_forever()
