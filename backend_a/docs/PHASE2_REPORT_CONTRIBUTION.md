# Phase 2 Report Contribution — Mac 3 (Vishuti)

These paragraphs are prepared for Agnik to assemble into the team's final `PHASE2_REPORT.md`.

---

## 1. Extension C: Service Isolation via Packet Filter (pf)

**Owner: Vishuti (Lead for Backend A) & Anwesha (Backend B)**

In Phase 2, we implemented kernel-level service isolation to enforce a fundamental cloud architecture principle: backend application instances must never be directly accessible from untrusted client networks. Using macOS's Darwin Packet Filter (`pf`), we restricted direct access to TCP port 3001 exclusively to authorized edge nodes. 

Rather than overwriting the global ruleset, which would strip Apple's default system anchors (`com.apple/*`), we structured our implementation around a dedicated anchor: `anchor "cnteam"`. Within this anchor, the authorized edge tier is abstracted into a kernel lookup table (`table <edges> { 10.7.3.251 }`). Traffic originating on loopback (`lo0`) is explicitly permitted via `pass in quick on lo0`, ensuring that local diagnostic tools and Mac 3's local Standby Edge retain uninterrupted access. Packets originating from `<edges>` are permitted and tracked with stateful inspection (`keep state`). For all other LAN sources, we configured `block return in quick proto tcp from any to any port 3001`, which actively responds with a `TCP RST` packet. This provides an immediate "Connection refused" error to unauthorized clients (such as Mac 1 attempting direct curls), distinguishing active administrative blocking from arbitrary network dropouts (`block drop`). To guarantee zero disruption after evaluation, we introduced token-based lifecycle management using `pfctl -E` and `pfctl -X <token>`, accompanied by automated pre-activation backups of `/etc/pf.conf` and ruleset state.

---

## 2. Extension E: Standby Edge Hosting & Controlled DNS Cutover

**Co-written: Vishuti (Host) & Agnik (Lead)**

To eliminate the single point of failure (SPOF) present in the Phase 1 edge layer without requiring specialized hardware, Mac 3 was configured as a standby Nginx edge node. The standby instance was deployed on ports 8080 (HTTP) and 8443 (HTTPS), utilizing the identical trusted TLS certificate (`cnteam.test.crt`) and private key (`cnteam.test.key`). To make edge execution transparent in HTTP headers, the standby instance injects `X-Edge: mac3-standby`.

The standby reverse proxy routes traffic across the redundant backend pool: connecting to Backend A locally via `127.0.0.1:3001` (permitted by loopback firewall rules) and Backend B remotely across the LAN (`10.7.5.197:3002`). During the cutover demonstration, primary DNS records on Mac 1 and Mac 4 were updated from Mac 2 (`10.7.3.251`) to Mac 3 (`10.7.15.127`). Because Phase 2 configured a 30-second TTL (`local-ttl=30`), existing clients with active DNS cache entries continued hitting Mac 2 (`X-Edge: mac2-primary`) until their TTL expired, after which fresh lookups smoothly transitioned to Mac 3 (`X-Edge: mac3-standby`). Zero dropped requests or connection resets occurred during the cutover. Following the demo, an automated uninstallation script cleanly halted Nginx, purged configuration files, and securely deleted the private key.

---

## 3. Phase 1 Gap Closure & Demo Step 7: HTTP Caching & ETag Consistency

**Owner: Vishuti & Anwesha**

In Phase 1, responses included `Cache-Control: max-age=60`, but lacked validation mechanisms for stale cache revalidation. In Phase 2, we introduced deterministic HTTP `304 Not Modified` handling. A critical distributed systems challenge emerged: because round-robin load balancing alternates requests between Backend A and Backend B, caching `/api/status` would produce differing payload hashes and differing ETags, causing conditional requests to repeatedly miss and force full 200 responses.

To solve this, we implemented the `/api/info` endpoint returning a standardized, byte-identical JSON payload (`{"service":"cnteam","version":"2.0"}`). Both backends compute a deterministic SHA-256 ETag (`"39464b4ed106dad1"`). When clients send conditional headers (`If-None-Match: "39464b4ed106dad1"`), the receiving backend verifies the hash and responds with `HTTP/1.0 304 Not Modified`, writing zero body bytes. This guarantees that conditional cache validation succeeds regardless of which backend instance services the request.
