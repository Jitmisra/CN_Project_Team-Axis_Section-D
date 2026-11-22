# Mac 3 (Vishuti) — Backend A & Standby Edge Architecture Document (Phase 2)

## 1. System Role & Topology

Within the 4-Mac Private Network Service Platform, **Mac 3** serves a dual role:
1. **Primary Role:** **Backend Application Instance A** — one of two identical, horizontally scaled application servers positioned behind the Edge Reverse Proxy and Load Balancer (Mac 2 / Agnik).
2. **Phase 2 Role (Extension E):** **Standby Edge Node** — hosts a secondary Nginx reverse proxy instance ready to assume traffic if DNS cutover is initiated.

```
+---------------------------------------------------------------------------------------------------+
|                                          LOCAL LAN SUBNET                                         |
|                                  10.7.0.0/19 (Gateway: 10.7.0.1)                                  |
+---------------------------------------------------------------------------------------------------+
        ^                                                                       ^
        | (1) DNS Query                                                         | (3) Proxied HTTP
        |     UDP :53                                                           |     TCP :3001
+---------------+                                                       +---------------+
|     Mac 1     |                                                       |     Mac 3     |
|   (Kartikey)  |                                                       |   (Vishuti)   |
|  Primary DNS  |                                                       |   Backend A   |
|   10.7.8.82   |                                                       |  10.7.15.127  |
+---------------+                                                       +---------------+
        ^                                                                       ^
        | (1b) Backup DNS (Ext A)                                               |
+---------------+                        (2) HTTPS (TCP :8443)          +---------------+
|     Mac 4     | ====================================================> |     Mac 2     |
|   (Anwesha)   |                                                       |    (Agnik)    |
|  Backend B /  | <==================================================== |  Primary Edge |
|  Backup DNS   |                       Encrypted TLS                   |  10.7.3.251   |
|  10.7.5.197   |                                                       +---------------+
+---------------+                                                               |
        ^                                                                       | (3b) Proxied HTTP
        +-----------------------------------------------------------------------+      TCP :3002
                                 (During Ext E Cutover)
                                 DNS points to Mac 3 (10.7.15.127:8443)
```

### Node Specification (Phase 2 - 2026-11-22)
- **Node**: Mac 3 (Vishuti)
- **Roles**: Backend Application Server A & Standby Edge Host
- **Private IPv4**: `10.7.15.127`
- **Subnet Mask**: `255.255.224.0` (`/19`)
- **Gateway**: `10.7.0.1`
- **MAC Address**: `10:9f:41:a9:20:0d`
- **Active Interface**: `en0`
- **Backend Application Service**: Python 3 REST Server (`backend_a.py`) on `0.0.0.0:3001`
- **Standby Edge Service**: Nginx reverse proxy on `8080` (HTTP) and `8443` (TLS)

---

## 2. Backend A Application Architecture (`backend_a.py`)

### Socket Binding Semantics
- **Bound Address**: `0.0.0.0:3001` (`INADDR_ANY`).
- **Rationale**: Binds the listening socket to all active network interfaces (`lo0` and `en0`). This allows local standby Nginx on Mac 3 to connect via `127.0.0.1:3001` and remote primary Nginx on Mac 2 to connect via `10.7.15.127:3001`.

### API Routes & Contract
1. `GET /`:
   - Status: `200 OK`, `text/plain`, `Backend A is running\n`
   - Headers: `X-Backend: A`, `Cache-Control: max-age=60`, `ETag: "1233d869f41ace6a"`
2. `GET /api/status`:
   - Status: `200 OK`, `application/json`, `{"backend": "A", "status": "ok"}`
   - Headers: `X-Backend: A`, `Cache-Control: max-age=60`, `ETag: "4a04d2d7b5598c32"`
3. `GET /api/info` (Phase 2 Caching Endpoint):
   - Status: `200 OK`, `application/json`, `{"service":"cnteam","version":"2.0"}`
   - Headers: `X-Backend: A`, `Cache-Control: max-age=60`, `ETag: "39464b4ed106dad1"`
4. `HEAD` Method Support:
   - Returns identical headers to `GET`, but writes zero body bytes (`Content-Length: 36`).
5. Conditional Requests (`If-None-Match`):
   - If client header contains matching ETag, server returns `HTTP/1.0 304 Not Modified` with empty body.

---

## 3. Security & Service Isolation Architecture (Extension C)

Mac 3 acts as the **team lead** for Packet Filter isolation.

### Anchor Configuration (`config/pf.cnteam.anchor`)
```pf
table <edges> { 10.7.3.251 }
pass in quick on lo0 proto tcp from any to any port 3001
pass in quick proto tcp from <edges> to any port 3001 keep state
block return in quick proto tcp from any to any port 3001
```

### Key Engineering Decisions:
1. **Anchor-Based Loading:** Uses `anchor "cnteam"` loaded from `/etc/pf.conf` or a root wrapper, preserving Apple's default system anchors (`com.apple/*`) instead of wiping them.
2. **Table `<edges>` Abstraction:** The authorized edge tier is abstracted into a kernel lookup table. Adding new edges (or updating drifted IPs) is an $O(1)$ table operation.
3. **`block return` vs `block drop`:** Default is `block return` which emits an active `TCP RST` (instant Connection Refused for diagnostics), while supporting `block drop` for silent timeout demonstrations.
4. **Token Management & Safe Rollback:** Enables PF via `pfctl -E` and preserves the reference token. Disable script flushes the anchor, reloads `/etc/pf.conf`, and releases the token (`pfctl -X <token>`), guaranteeing zero residual firewall rules.

---

## 4. Standby Edge Architecture (Extension E)

- **Standby Configuration:** Located in `standby-edge/`. Listens on ports 8080 and 8443 (TLS).
- **Header Injection:** Injects `X-Edge: mac3-standby` to make migration immediately distinguishable in HTTP traces.
- **Upstream Pool:**
  - `server 127.0.0.1:3001` (Backend A, local loopback)
  - `server 10.7.5.197:3002` (Backend B on Mac 4, remote)
- **Cutover Process:**
  1. Primary edge (Mac 2: `10.7.3.251`) serves traffic.
  2. DNS servers on Mac 1 and Mac 4 update `app.cnteam.test` $\to$ `10.7.15.127`.
  3. Already-cached clients continue hitting Mac 2 until 30s TTL expires.
  4. Subsequent client queries resolve to `10.7.15.127` and hit the Mac 3 Standby Edge seamlessly.
