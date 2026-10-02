# Mac 3 (Vishuti) — Comprehensive Viva Preparation Guide

This document prepares Vishuti for both individual questions (Section 1) and whole-system questions (Section 2) during course evaluation.

---

## Section 1: Mac 3 Individual Viva Questions

### Question 1: Why does the server have to bind to `0.0.0.0` instead of `127.0.0.1`?
**Comprehensive Answer:**
- `127.0.0.1` is the IPv4 **loopback address** (`INADDR_LOOPBACK`). It binds strictly to the `lo0` virtual interface. Sockets bound to `127.0.0.1` only accept connections originated from the same physical machine. The OS network stack will immediately drop or reject any incoming packets from external network interfaces (`en0`).
- `0.0.0.0` represents `INADDR_ANY` (all IPv4 addresses on the local system). When a listening TCP socket binds to `0.0.0.0`, the operating system kernel binds the socket to **all active network interfaces** (both loopback `lo0` and physical Wi-Fi `en0`).
- Because Mac 2 (Agnik's Nginx edge proxy at `10.7.14.242`) communicates over the private LAN, packets arrive at Mac 3's Wi-Fi interface `en0` (`10.7.18.246`). If `backend_a.py` were bound only to `127.0.0.1`, Mac 2's TCP SYN packets would be met with an immediate `TCP RST` (connection refused).

---

### Question 2: What's the difference between the edge (Mac 2) failing vs your backend failing — what would a client see in each case?
**Comprehensive Answer:**
These failures represent two completely different layers of the network architecture:
1. **Edge (Mac 2) Failure:**
   - **What happens:** Nginx is down or Mac 2 is powered off.
   - **Client Symptom:** The client will successfully resolve `app.cnteam.test` via Mac 1's DNS to `10.7.14.242`. However, when the client attempts the TCP 3-way handshake to port 8443/443, the connection fails with **`Connection refused`** (`TCP RST` from OS) or **`Operation timed out`** (`ETIMEDOUT` if host is unreachable).
   - **Crucial Distinction:** The client **never reaches the TLS handshake** and **never receives any HTTP status code**.
2. **Backend A (Mac 3) Failure:**
   - **What happens:** `backend_a.py` is stopped or port 3001 is closed.
   - **Client Symptom (Normal HA Operation):** The client sees **no error at all!** The client connects to Mac 2, completes TCP and TLS handshakes, and receives `HTTP 200 OK`. However, the response header `X-Backend` will consistently show **`B`** (served by Anwesha's Mac 4), because Nginx's upstream passive health check (`max_fails=2 fail_timeout=5s`) detects that Backend A is down and routes all traffic to Backend B.
   - **Client Symptom (If Both Backends Fail):** If both Mac 3 and Mac 4 are stopped, Mac 2's Nginx edge will accept the TCP and TLS connection, but cannot obtain a response from any upstream server. Nginx returns **`HTTP 502 Bad Gateway`**.

---

### Question 3: Walk through what your `pf` rule actually does and why it doesn't break nginx's access.
**Comprehensive Answer:**
- **The Rule Configuration:**
  ```pf
  pass in quick on lo0 proto tcp from any to any port 3001
  block in proto tcp from any to any port 3001
  pass in proto tcp from 10.7.14.242 to any port 3001
  ```
- **Step-by-step Evaluation:**
  1. macOS uses the OpenBSD Packet Filter (`pf`) engine embedded in the Darwin kernel. Rules are evaluated sequentially for incoming packets.
  2. The first rule (`pass in quick on lo0 ...`) evaluates loopback traffic. Because of `quick`, if a connection originates locally on Mac 3 (e.g. `curl http://localhost:3001`), evaluation stops immediately and the packet is admitted.
  3. For LAN packets arriving on interface `en0`, rule 2 blocks all incoming TCP traffic targeting port 3001 by default (`block in ...`).
  4. Rule 3 (`pass in proto tcp from 10.7.14.242 to any port 3001`) specifies an exception. Because `pf` applies the **last matching rule**, any packet whose IP header source address is `10.7.14.242` matches rule 3 and is permitted to establish the TCP connection.
- **Why Nginx Access is Preserved:**
  - In a reverse proxy architecture, Nginx terminates client requests and opens a brand-new TCP connection from its own network interface to the backend.
  - Therefore, the source IP on the IP packet header arriving at Mac 3 is **`10.7.14.242`** (Mac 2's IP), NOT the original client's IP.
  - Because `10.7.14.242` matches rule 3, Nginx is authorized and can proxy traffic without impediment.
  - Any rogue client (e.g., Mac 1 or Mac 4 directly calling `curl http://10.7.18.246:3001`) only matches the `block` rule and is dropped or refused.

---

### Question 4: Explain the whole request flow from client to your backend and back, not just your own piece.
**Comprehensive Answer:**
1. **Name Resolution (DNS Layer - UDP 53):**
   - Client types `https://app.cnteam.test/api/status`.
   - The OS resolver queries Mac 1 (`10.7.8.82`) on UDP port 53.
   - Mac 1's `dnsmasq` responds with an `A` record pointing to Edge Mac 2 (`10.7.14.242`).
2. **Transport Handshake (TCP Layer - Port 8443/443):**
   - Client sends `TCP SYN` from an ephemeral port (e.g., `52341`) to `10.7.14.242:8443`.
   - Mac 2 responds with `SYN-ACK`.
   - Client returns `ACK`. The TCP connection is established.
3. **Security Handshake (TLS Layer):**
   - Client sends `ClientHello` (supported cipher suites, SNI = `app.cnteam.test`).
   - Mac 2 sends `ServerHello`, selects cipher, and transmits its X.509 certificate.
   - Key exchange (ECDHE) occurs, symmetric session keys are derived, and both send `Finished` messages.
4. **Edge Processing (Reverse Proxy & Load Balancing):**
   - Client sends encrypted `GET /api/status HTTP/1.1` over TLS.
   - Mac 2 decrypts the request.
   - Nginx evaluates the `upstream backend_pool` round-robin state.
   - If selected for Backend A, Nginx opens a new local TCP connection across the LAN to `10.7.18.246:3001`.
5. **Backend A Processing (Application Layer):**
   - Mac 3 kernel checks `pf` firewall: source is `10.7.14.242`, matching rule permits packet.
   - Kernel delivers TCP data to `backend_a.py` listening on `0.0.0.0:3001`.
   - `Handler.do_GET()` parses `/api/status`, writes headers (`Content-Type: application/json`, `X-Backend: A`, `Cache-Control: max-age=60`), and sends JSON payload `{"backend": "A", "status": "ok"}`.
6. **Return Journey:**
   - Mac 3 transmits HTTP response over TCP back to Mac 2.
   - Mac 2 encrypts the HTTP response using the client's TLS session keys.
   - Encrypted TLS packets travel back to the client.
   - Client decrypts and displays the JSON payload and headers.

---

## Section 2: General System & Viva Questions

### Q5: What makes Mac 2 an "AWS ALB / GCP Cloud Load Balancer" equivalent?
- It provides **centralized TLS termination** (offloading cryptographic computation from backends).
- It provides a **single stable virtual IP / domain** for clients, shielding internal network topology and private IP addressing.
- It performs **Layer 7 routing and health monitoring** (detecting backend failure and routing traffic dynamically).

### Q6: What is the single point of failure in the Phase 1 design?
- **Mac 2 (Nginx Edge) and Mac 1 (DNS):** If either goes down, the entire service is unreachable.
- **How to resolve:**
  - For DNS: Run secondary DNS resolver (Phase 2 Extension A on Mac 4) with client multi-resolver configuration.
  - For Edge: Deploy a secondary standby Nginx instance (Phase 2 Extension E) with DNS failover or a Virtual IP (Keepalived/VRRP).

---

## Section 3: Diagnostic Order for Faculty Injected Faults (Extension F)

When the faculty breaks something during the live demo, follow this strict layer-by-layer methodology out loud:

1. **Layer 3 (Network Layer):**
   - Run `ping 10.7.0.1` and `ping 10.7.14.242` to verify physical/Wi-Fi link and routing.
2. **Layer 4 (Transport / Socket Layer):**
   - Check if the process is running and bound to port 3001: `lsof -i :3001`.
   - Verify it is bound to `0.0.0.0:3001` and not mistakenly `127.0.0.1:3001`.
3. **Firewall / Security Layer:**
   - Inspect PF firewall rules: `sudo pfctl -sr`.
   - Check if Mac 2's IP was mistyped or blocked.
4. **Layer 7 (Application Layer):**
   - Test locally: `curl -i http://localhost:3001/api/status`.
   - Inspect application logs: `tail -n 20 logs/backend_a.log`.
