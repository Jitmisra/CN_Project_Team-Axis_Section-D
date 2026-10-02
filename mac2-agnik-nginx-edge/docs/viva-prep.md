# Viva Prep — Agnik (Mac 2 — Edge/LB/TLS)

## Your four core questions
1. **Walk through the TLS handshake step by step from a Wireshark capture.**
   ClientHello (client proposes TLS version + cipher suites + random) → ServerHello
   (server picks cipher suite + sends its own random) → Certificate (server sends its
   cert chain; client validates against its trust store) → Key Exchange → both sides
   derive the session key → ChangeCipherSpec + Finished on each side → all further
   records are encrypted application data. Point at these message types by name in
   the capture, and note the handshake happens *after* the TCP three-way handshake
   completes and *before* any HTTP bytes are sent.

2. **Why does the client only ever see your domain/IP, never the backends'?**
   DNS only ever maps `app.cnteam.test` to Mac 2. The backend addresses exist only
   inside nginx's `upstream backend_pool` block — a purely internal routing table the
   client has no path to see or query. This is the same abstraction a cloud load
   balancer provides: the backend fleet can change size or IPs without clients
   noticing.

3. **Map your nginx config to AWS ALB / GCP Load Balancer concepts.**
   - `upstream backend_pool` ≈ a **target group** (ALB) / **backend service** (GCP LB).
   - Round-robin + `max_fails`/`fail_timeout` ≈ **health checks** removing unhealthy
     targets from rotation.
   - `listen 8443 ssl` + certificate ≈ **TLS termination at the load balancer**, a
     standard ALB/CLB pattern.
   - The `server_name` based `server {}` blocks ≈ **listener rules / host-based
     routing**.

4. **What's still a single point of failure in this design, and how would you remove it?**
   Mac 2 itself — if nginx or the machine dies, DNS still resolves but nothing
   answers. Removing it needs a second edge node and a failover mechanism between
   them (Extension E demonstrates this manually via a DNS record change to a standby
   nginx; a production system would use something like a floating VIP, anycast, or a
   DNS health-checked failover policy).

## Rest-of-system questions you should also be ready for
- **DNS (Mac 1/Kartikey's area):** difference between DNS resolution failing (wrong
  resolver) vs DNS returning the wrong answer (wrong record) vs the resolved service
  being down. What a TTL controls and why Phase 2 sets it to 30s when dnsmasq's
  per-record default is 0 (uncached).
- **Backends (Mac 3/4):** why they bind `0.0.0.0` not `127.0.0.1`; what `X-Backend`
  and `Cache-Control` each prove; the firewall rule that limits direct backend access
  to Mac 2's IP only (Extension C) — and why nginx still works afterward (it's the
  one IP explicitly allowed).
- **Caching (Task F):** difference between a fresh cache hit (no request sent, served
  entirely from the client's local cache within `max-age`), a conditional request
  (`If-None-Match`/`If-Modified-Since` → `304 Not Modified`, no body sent), and a full
  new request (`200` with a full body).

## Troubleshooting order (use this if the faculty injects a fault at your layer)
Diagnose layer by layer, narrating out loud — partial credit is given for correct
methodology even without a full fix:
1. **DNS** — does `dig app.cnteam.test` return Mac 2's IP at all?
2. **TCP** — does `nc -zv <mac2-ip> 8443` (or `curl -v` up to "Connected to") succeed?
   If not: nginx down, wrong port, or firewall blocking.
3. **TLS** — does the handshake complete (`curl -v` shows "SSL connection using
   TLSv1.x")? If not: cert/key mismatch, expired cert, wrong `server_name`.
4. **Application/backend** — does the HTTP response come back correctly, and is
   `X-Backend` present? If you get a clean TLS connection but a `502`, the fault is
   downstream at Backend A/B, not at your layer — say so explicitly, that's the kind
   of layer-isolation statement that earns credit even if you can't fix Vishuti's or
   Anwesha's machine yourself.
