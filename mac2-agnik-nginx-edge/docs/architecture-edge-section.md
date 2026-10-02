# Architecture Document — Edge / Load Balancer / TLS Section (Mac 2, Agnik)

## Role
Mac 2 is the single public entry point of the private network — the local
equivalent of a cloud load balancer / CDN edge node (e.g. AWS ALB, GCP Load
Balancer). Clients never connect to Backend A or Backend B directly; every request
is resolved by DNS to Mac 2's IP, TLS-terminated here, then reverse-proxied to
whichever backend nginx selects.

## Machine details
| Field | Value |
|---|---|
| IP | 10.7.14.242 |
| Subnet | 255.255.224.0 (/19) |
| Gateway | 10.7.0.1 |
| Interface | en0 |
| MAC | fa:4e:b4:04:d0:00 |

## Services running
- **nginx** (Homebrew, `/opt/homebrew/opt/nginx`) — reverse proxy + load balancer +
  TLS termination.
- Listening on **8080** (HTTP, redirects to HTTPS) and **8443** (HTTPS) — Homebrew
  nginx binds 8080 by default to avoid requiring sudo; this is the project's
  documented port-restriction fallback.

## Load balancing
- Strategy: **round-robin** (nginx's default when no `weight`/`least_conn` directive
  is given) across an `upstream backend_pool` containing Backend A (Mac 3:3001) and
  Backend B (Mac 4:3002).
- Passive health checking via `max_fails=2 fail_timeout=5s` on each upstream server,
  plus `proxy_next_upstream` on 502/503/504/timeout/error — this is what lets nginx
  route around a stopped backend automatically (Extension D).
- The client identifies which backend served a request via the `X-Backend: A` / `B`
  response header set by the backend itself and passed through unmodified by nginx.

## TLS
- Self-signed certificate, `CN=app.cnteam.test`, SAN covers `app.cnteam.test` and
  `api.cnteam.test`, RSA 2048, 365-day validity, generated with OpenSSL.
- TLS terminates at nginx — traffic from Mac 2 to the backends is plain HTTP inside
  the private LAN (the trust boundary for this project is the client-to-edge hop,
  matching how a cloud load balancer typically terminates TLS before an internal
  proxy hop).
- Handshake sequence demonstrated in Wireshark: ClientHello → ServerHello →
  Certificate → (Key Exchange) → Finished, then encrypted application data.

## Why the client never needs backend IPs
The client only ever resolves and connects to `app.cnteam.test` → Mac 2. The
`upstream backend_pool` block is the only place Backend A/B's addresses exist. This
is the same separation of concerns as DNS (a name) vs TCP (a connection) vs a load
balancer's routing table (an internal detail the client has no visibility into).

## Known single point of failure
Mac 2 itself. If nginx or this machine goes down, DNS still resolves `app.cnteam.test`
but nothing answers on 8443 — the whole service is unreachable even though both
backends are healthy. Removing this SPOF would require a second edge node plus a
mechanism to fail over between them (e.g. a second nginx + DNS-based cutover, which
is what Extension E demonstrates manually).

## Response flow summary
```
Client → DNS: app.cnteam.test → 10.7.14.242 (Mac 1)
Client → TCP SYN/SYN-ACK/ACK → 10.7.14.242:8443 (Mac 2)
Client → TLS handshake → 10.7.14.242:8443
Client → HTTP GET /api/status (encrypted) → Mac 2
Mac 2 → nginx upstream round-robin → Backend A (3001) or Backend B (3002)
Backend → JSON + X-Backend header → Mac 2 → Client (still encrypted)
```
