# Mac 3 (Vishuti) — Comprehensive Viva Preparation Guide (Phase 1 & Phase 2)

This document prepares Vishuti for both individual questions (Section 1) and whole-system questions (Section 2) during course evaluation.

---

## Section 1: Mac 3 Individual Viva Questions

### Question 1: Why does the server have to bind to `0.0.0.0` instead of `127.0.0.1`?
**Comprehensive Answer:**
- `127.0.0.1` is the IPv4 **loopback address** (`INADDR_LOOPBACK`). It binds strictly to the `lo0` virtual interface. Sockets bound to `127.0.0.1` only accept connections originated from the same physical machine. The OS network stack will immediately drop or reject any incoming packets from external network interfaces (`en0`).
- `0.0.0.0` represents `INADDR_ANY` (all IPv4 addresses on the local system). When a listening TCP socket binds to `0.0.0.0`, the operating system kernel binds the socket to **all active network interfaces** (both loopback `lo0` and physical Wi-Fi `en0`).
- Because Mac 2 (Agnik's Nginx edge proxy) communicates over the private LAN, packets arrive at Mac 3's Wi-Fi interface `en0` (`10.7.15.127`). If `backend_a.py` were bound only to `127.0.0.1`, Mac 2's TCP SYN packets would be met with an immediate `TCP RST` (connection refused).

---

### Question 2: What's the difference between `block return` vs `block drop` in `pf`? What does the client see, and which would you use in production?
**Comprehensive Answer:**
- **`block return`:**
  - The macOS kernel actively transmits a **`TCP RST` (Reset)** packet back to the client immediately upon receiving the TCP SYN.
  - **Client Symptom:** The client's TCP handshake fails instantly with **`Connection refused`** (`ECONNREFUSED`).
  - **Diagnostic Value:** Highly transparent for debugging and internal networking, as the client immediately knows the port/service is barred or rejected without hanging.
- **`block drop`:**
  - The macOS kernel completely discards the packet without generating any response.
  - **Client Symptom:** The client's TCP stack retransmits SYN packets according to exponential backoff until timing out with **`Operation timed out`** (`ETIMEDOUT`), typically taking 30–75 seconds.
  - **Production Preference:** In public, internet-facing production environments, **`block drop` (stealth mode)** is preferred for untrusted traffic to mitigate port-scanning and avoid wasting bandwidth on RST packets. However, for internal private subnets / microservices, **`block return`** is preferred to prevent upstream reverse proxies (like Nginx) from waiting on connection timeouts.

---

### Question 3: Walk through your `pf` anchor rules line by line. Why doesn't Nginx get blocked? What changes if Mac 2's IP changes?
**Comprehensive Answer:**
- **The Anchor Rules (`pf.cnteam.anchor`):**
  ```pf
  table <edges> { 10.7.3.251 }
  pass in quick on lo0 proto tcp from any to any port 3001
  pass in quick proto tcp from <edges> to any port 3001 keep state
  block return in quick proto tcp from any to any port 3001
  ```
- **Line-by-Line Breakdown:**
  1. `table <edges> { 10.7.3.251 }`: Defines a high-performance in-kernel lookup table containing authorized edge load balancer IP(s).
  2. `pass in quick on lo0 proto tcp from any to any port 3001`: Permits all loopback interface traffic. Crucial for local health monitoring, diagnostics, and the **Standby Edge on Mac 3** (which proxies to `127.0.0.1:3001`). `quick` stops further rule evaluation immediately.
  3. `pass in quick proto tcp from <edges> to any port 3001 keep state`: Evaluates packets arriving on `en0`. If the source IP matches `<edges>`, it allows the connection, stops further evaluation (`quick`), and creates a state entry in the state table (`keep state`) so bidirectional traffic flows unimpeded.
  4. `block return in quick proto tcp from any to any port 3001`: Any packet arriving from an IP NOT in `<edges>` (such as Kartikey's Mac 1 or Anwesha's Mac 4) is blocked and sent an immediate `TCP RST`.
- **Why Nginx Doesn't Get Blocked:**
  - In a reverse proxy architecture, Nginx terminates client TLS connections and originates a *new* TCP connection to Backend A with its own IP (`10.7.3.251`) in the IP source header.
  - Because `10.7.3.251` is in `<edges>`, rule 3 matches and admits the packet.
- **What Happens If Mac 2's IP Changes:**
  - If Mac 2's IP drifts (e.g. via DHCP) and the `<edges>` table is not updated, Nginx's connections will match the `block return` rule and be rejected.
  - Nginx will detect upstream failure and fail over to Backend B, or return `502 Bad Gateway`.
  - Fix: Update `MAC2_IP` in `team.env` and re-run `./scripts/firewall-enable.sh`.

---

### Question 4: Compare Edge (Mac 2) failure vs Backend failure vs Firewall misconfiguration.
**Comprehensive Answer:**

| Scenario | Point of Failure | Client-Side Symptom | Protocol Breakdown |
| :--- | :--- | :--- | :--- |
| **Edge (Mac 2) Failure** | Nginx down / Mac 2 unreachable | `Failed to connect: Connection refused` or `ETIMEDOUT` | DNS resolves, but TCP SYN to `:8443` receives RST or times out. **No TLS handshake, no HTTP status code.** |
| **Backend A Failure** | `backend_a.py` stopped | **`HTTP 200 OK` (transparent failover)** | Client connects to Nginx; Nginx upstream passive health check (`max_fails=2`) detects A is down and routes 100% of traffic to Backend B (`X-Backend: B`). If both down: **`502 Bad Gateway`**. |
| **Firewall Misconfiguration** | PF `<edges>` table missing Mac 2 IP | **`HTTP 200 OK` (routed to B)** or **`502`** | Nginx's TCP SYN to Mac 3 receives RST from PF. Nginx marks Backend A unavailable. Direct curl from Mac 1 or Mac 4 receives `Connection refused`. |

---

### Question 5: Explain Fresh Hit vs Conditional Request (304) vs Full Request. Why must ETags match across a backend pool?
**Comprehensive Answer:**
1. **Fresh Hit (Client Cache):**
   - The browser or cache client checks `Cache-Control: max-age=60`.
   - If the response is under 60 seconds old, the browser fulfills the request from memory/disk cache without sending any network packet (`(disk cache)` in DevTools).
2. **Conditional Request (304 Not Modified):**
   - Once `max-age` expires, the cached response is stale. The client sends a conditional GET with the header `If-None-Match: "39464b4ed106dad1"`.
   - The server verifies the ETag against the resource. Because it has not changed, the server returns **`HTTP/1.0 304 Not Modified`** with zero body bytes, saving network bandwidth.
3. **Full Request (200 OK):**
   - If the resource changed or no cache exists, server returns `HTTP 200 OK` with full headers and body.
4. **Why ETags Must Match Across Backend A and Backend B:**
   - In our load-balanced cluster, sequential requests alternate round-robin between Backend A and Backend B.
   - If `/api/status` were used, Backend A returns `{"backend":"A"}` and Backend B returns `{"backend":"B"}`. Their hashes/ETags differ!
   - A client caching Backend A's ETag would send it to Nginx; when Nginx proxies to Backend B, Backend B would see an ETag mismatch and return a full `200 OK` instead of `304`, defeating caching!
   - That is why **`/api/info`** serves byte-identical JSON (`{"service":"cnteam","version":"2.0"}`) on both backends, producing the exact same ETag (`"39464b4ed106dad1"`), ensuring 100% cache consistency across round-robin!

---

### Question 6: How does the Standby Edge on Mac 3 take over, and why did it need the same TLS key?
**Comprehensive Answer:**
- **How It Works (Extension E):**
  1. Mac 3 stands up a secondary Nginx edge listening on ports 8080/8443, configured with `add_header X-Edge "mac3-standby" always;`.
  2. Kartikey (Mac 1) and Anwesha (Mac 4) update their DNS `A` records for `app.cnteam.test` to point to Mac 3's IP (`10.7.15.127`).
  3. Already-cached clients continue sending traffic to Mac 2 until their local DNS TTL (30s) expires.
  4. Once TTL expires, subsequent DNS queries return Mac 3's IP, and clients transparently migrate to Mac 3's standby edge!
- **Why It Needs the Same TLS Key:**
  - The client connects to `app.cnteam.test` expecting the trusted certificate installed in their Keychain.
  - To terminate TLS for `app.cnteam.test` without triggering browser certificate warnings, the Standby Edge must present the public certificate (`cnteam.test.crt`) AND prove ownership via cryptographic signature with the matching private key (`cnteam.test.key`).
  - Without the private key, the Standby Edge cannot complete the TLS 1.3 cryptographic handshake.

---

## Section 2: Whole-System Architecture & Viva Questions

### Q7: Explain DNS Failure vs Application Failure.
- **DNS Service Failure:** dnsmasq on Mac 1 is down. Client `dig` times out or fails with `SERVFAIL`. The client never obtains an IP address, so zero TCP packets are emitted toward the edge.
- **Application Server Failure:** DNS resolves to Mac 2. TCP and TLS handshakes succeed with Nginx. But backends are unreachable, so Nginx returns `502 Bad Gateway`.

### Q8: What does a DNS TTL actually control?
- TTL (Time-To-Live) dictates how many seconds a recursive resolver or client OS (mDNSResponder) may cache a DNS record before querying authoritative nameservers again.
- In Phase 1, `local-ttl=0` meant zero caching, so record edits took effect immediately.
- In Phase 2, `local-ttl=30` introduces a 30-second cache window. During migrations, clients with unexpired cache entries continue hitting the old edge until TTL expires.
- Note: `dig` bypasses OS caching; `curl` and browsers use `dscacheutil` / mDNSResponder and respect TTL.

### Q9: What is the Single Point of Failure (SPOF) in Phase 2, and how is it resolved?
- In Phase 2, DNS is redundant (Mac 1 primary + Mac 4 backup), and backends are redundant (Mac 3 + Mac 4).
- **The remaining SPOF is Mac 2 (the primary Nginx Edge).** If Mac 2 crashes, all HTTPS traffic stops.
- **Enterprise Solutions:**
  1. **DNS Failover / Route 53 Health Checks:** Automatic health checking that points domain to secondary standby edge (Mac 3).
  2. **Virtual IP (VIP) with VRRP/Keepalived:** Both edges share a floating IP address; if primary fails, secondary claims the VIP via gratuitous ARP in milliseconds.
  3. **Anycast BGP:** Both edges announce the same IP prefix to network routers; routers automatically route around a dead node.
