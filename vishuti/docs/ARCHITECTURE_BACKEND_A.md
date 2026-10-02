# Mac 3 (Vishuti) — Backend A Architecture Document

## 1. System Role & Topology

Within the 4-Mac Private Network Service Platform, **Mac 3** acts as **Backend Application Instance A**. It is one of two identical, horizontally scaled application servers positioned behind the Edge Reverse Proxy and Load Balancer (Mac 2 / Agnik).

```
+-----------------------------------------------------------------------------------+
|                                  LOCAL LAN SUBNET                                 |
|                         10.7.0.0/19 (Gateway: 10.7.0.1)                           |
+-----------------------------------------------------------------------------------+
        ^                                                           ^
        | (1) DNS Query                                             | (3) Proxied HTTP
        |     UDP :53                                               |     TCP :3001
+---------------+                                           +---------------+
|     Mac 1     |                                           |     Mac 3     |
|   (Kartikey)  |                                           |   (Vishuti)   |
|   DNS Server  |                                           |   Backend A   |
|  10.7.8.82    |                                           | 10.7.18.246   |
+---------------+                                           +---------------+
        ^                                                           ^
        |                                                           |
+---------------+              (2) HTTPS (TCP :8443/:443)   +---------------+
|     Mac 4     | ========================================> |     Mac 2     |
|   (Anwesha)   |                                           |    (Agnik)    |
|   Backend B / | <======================================== |   Edge / LB   |
|  Test Client  |             Encrypted TLS Response        |  10.7.14.242  |
|               |                                           +---------------+
+---------------+                                                   |
        ^                                                           | (3b) Proxied HTTP
        +-----------------------------------------------------------+      TCP :3002
```

### Node Specification
- **Node**: Mac 3 (Vishuti)
- **Role**: Backend Application Server A
- **Private IPv4**: `10.7.18.246`
- **Subnet Mask**: `255.255.224.0` (`/19`)
- **Gateway**: `10.7.0.1`
- **MAC Address**: `10:9f:41:a9:20:0d`
- **Active Interface**: `en0`
- **Application Service**: Python 3 REST Server (`backend_a.py`)
- **Listen Address**: `0.0.0.0:3001` (TCP)

---

## 2. Backend A Application Architecture (`backend_a.py`)

### Design Philosophy
The application layer is deliberately dependency-free and lightweight. The objective of the course project is to demonstrate and measure network plumbing, socket binding, transport-layer segmentation, reverse-proxying, caching semantics, and packet filtering.

### Socket Binding Semantics
- **Bound Address**: `0.0.0.0:3001` (`INADDR_ANY`).
- **Rationale**: Binding to `0.0.0.0` instructs the macOS Darwin kernel to bind the listening socket to all network interfaces (`lo0`, `en0`, etc.). If the server were bound to `127.0.0.1` (`INADDR_LOOPBACK`), packets arriving from the LAN (specifically from Mac 2 at `10.7.14.242`) would be rejected at the transport layer with a TCP RST.

### API Routes & Contract
1. `GET /`:
   - Status: `200 OK`
   - Content-Type: `text/plain`
   - Body: `Backend A is running\n`
   - Headers: `X-Backend: A`, `Cache-Control: max-age=60`
2. `GET /api/status`:
   - Status: `200 OK`
   - Content-Type: `application/json`
   - Body: `{"backend": "A", "status": "ok"}`
   - Headers: `X-Backend: A`, `Cache-Control: max-age=60`
3. Fallback (`*`):
   - Status: `404 Not Found`
   - Content-Type: `application/json`
   - Body: `{"error":"not found"}`

### Diagnostic Headers
- **`X-Backend: A`**: A custom HTTP response header injected by Backend A. When Agnik's Nginx reverse proxy load-balances across the pool, the client observes this header alternating between `A` and `B`, providing deterministic proof of layer-7 load balancing.
- **`Cache-Control: max-age=60`**: Declares that client/proxy caches may store the response for 60 seconds without revalidation, supporting the Task F caching verification.

---

## 3. Security & Service Isolation Architecture (Phase 2 - Extension C)

In a multi-tier enterprise architecture, backend application servers should never be directly accessible by external clients; all traffic must pass through the edge reverse proxy / WAF.

To enforce this architectural invariant, Mac 3 utilizes macOS's kernel-level **Packet Filter (`pf`)**:

### Firewall Configuration (`pf_rules_isolation.conf`)
```pf
# 1. Allow loopback so local tests and monitoring continue to work
pass in quick on lo0 proto tcp from any to any port 3001

# 2. Block all incoming TCP traffic targeting port 3001
block in proto tcp from any to any port 3001

# 3. Explicitly allow Mac 2 (Agnik / Nginx Edge: 10.7.14.242)
pass in proto tcp from 10.7.14.242 to any port 3001
```

### Packet Evaluation Mechanics
1. **Rule Ordering**: In PF syntax, rules are evaluated sequentially. The last matching rule decides the packet's fate (unless `quick` is specified).
2. **Mac 2 Traffic**: A packet from `10.7.14.242:eph_port` to `10.7.18.246:3001` matches `block in ...` and then matches `pass in ... from 10.7.14.242`, allowing the TCP SYN handshake to complete.
3. **Client Direct Traffic**: A packet from any other client (e.g., Mac 1 or Mac 4) matches `block in ...` and fails to match rule 3. PF drops or sends a TCP RST to the unauthorized client.
4. **Local Loopback**: Rule 1 specifies `quick`, short-circuiting rule evaluation for internal management.

---

## 4. Failure Domains & High Availability (HA)

### Backend Failure vs Edge Failure Matrix

| Failure Scenario | Point of Failure | Client Observation | Protocol Explanation |
| :--- | :--- | :--- | :--- |
| **Backend A Stopped** (`Ctrl+C` on Mac 3) | Mac 3 (:3001) | Client requests continue to succeed! `X-Backend` header shows `B` only. | Mac 2's Nginx upstream pool detects TCP failure on `10.7.18.246:3001` (`fail_timeout=5s`, `max_fails=2`) and fails over transparently to Backend B. |
| **Both Backends Stopped** | Mac 3 & Mac 4 | Client receives `HTTP 502 Bad Gateway`. | DNS resolution succeeds, TCP handshake to Mac 2 succeeds, TLS handshake succeeds. Nginx fails to connect to any upstream and returns standard 502 error page. |
| **Edge Server Stopped** (Nginx down on Mac 2) | Mac 2 (:8443/:443) | `curl: (7) Failed to connect to app.cnteam.test: Connection refused` | DNS resolves domain to `10.7.14.242`, but TCP SYN packet to port 8443 receives a TCP RST. No TLS or HTTP handshake can begin. |
| **DNS Server Stopped** (dnsmasq down on Mac 1) | Mac 1 (:53) | `Could not resolve host: app.cnteam.test` | Client cannot resolve domain name to an IP. No TCP packets are emitted toward Mac 2. |
