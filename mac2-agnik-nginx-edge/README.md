# Agnik — Mac 2 — nginx Edge + Load Balancer + TLS

## Status: Phase 1 complete

| Item | Result |
|---|---|
| IP (Phase 1) | `10.7.14.242` (now `10.7.3.251`) / 255.255.224.0 (/19) / gw `10.7.0.1` / en0 / `fa:4e:b4:04:d0:00` |
| nginx | Installed via Homebrew, running as a `brew services` background service on **8080/8443** (no sudo needed — valid port substitution per project rules) |
| Upstream pool | Backend A `10.7.18.246:3001` + Backend B `10.7.5.197:3002`, round-robin, `max_fails`/`fail_timeout` health checking |
| TLS | Self-signed cert, SAN covers `app.cnteam.test` + `api.cnteam.test`, trusted on all 4 machines |
| Verified | `curl https://app.cnteam.test:8443/api/status` with **no `-k`**: `SSL certificate verify ok.`, TLS 1.3, `X-Backend` alternates A/B across repeated requests, `Cache-Control: max-age=60` present — see `evidence/task-g-final-verify.txt` |
| Wireshark | `evidence/mac2-dns-query-en0.pcapng` (real DNS query/response to Mac 1 over the wire) + `evidence/mac2-tls-handshake-lo0.pcapng` (TCP handshake + TLS ClientHello/ServerHello) |
| Failure demos | One-backend-down failover and both-down 502 both captured — `evidence/failover-watch-*.txt` |

Independently re-verified from Kartikey's, Vishuti's, and Anwesha's own machines too
(DNS resolves, cert trusted, HTTPS works with no `-k`).

## One bug found and fixed along the way
`brew --prefix nginx` returns the formula's Cellar symlink, not `HOMEBREW_PREFIX` — the
server config has to be written to `$(brew --prefix)/etc/nginx/servers/`, not
`$(brew --prefix nginx)/etc/nginx/servers/`, or nginx silently never loads it. Fixed in
`scripts/d-install-nginx.sh`.

## Files
- `team.env` — all 4 machines' IPs, domain, ports.
- `scripts/` — `a-network-info.sh`, `a-ping.sh`, `e-make-cert.sh` (TLS cert),
  `d-install-nginx.sh` (renders + loads the real nginx config), `switch-dns.sh`
  (point this Mac at Mac 1's DNS, with revert), `verify.sh` (full chain check),
  `g-failover-watch.sh` (client-side failover/cutover watcher, real DNS, no `-k`),
  `edge-logs.sh` (live access/error log capture), `c-verify-isolation.sh` (Ext C from the edge),
  `set-backends.sh` (update backend IPs + re-render).
- `certs/cnteam.test.crt` — public cert only. **The private `.key` is intentionally
  not committed** (see root `.gitignore`); regenerate locally with `e-make-cert.sh`
  if you need to re-run this edge from scratch.
- `docs/architecture-edge-section.md` — this machine's section of the Architecture
  Document (see also the combined `/ARCHITECTURE.md` at repo root).
- `docs/viva-prep.md` — answers for this role's individual viva questions.
- `evidence/` — all captured output for Task A, D, E, F, G and both failure demos.

## Re-running this from scratch
1. Fill `MAC1_DNS_IP`, `MAC3_BACKEND_A_IP`, `MAC4_BACKEND_B_IP` into `team.env`.
2. `./scripts/a-ping.sh` — confirm reachability to all three teammates.
3. `./scripts/e-make-cert.sh` — generates a fresh TLS cert/key (key is gitignored).
4. `./scripts/d-install-nginx.sh` — renders and loads the server block, restarts nginx.
5. `./scripts/switch-dns.sh set` — point this Mac's resolver at Mac 1.
6. `./scripts/verify.sh` — full chain check (DNS, TLS, load balancing, caching).
7. Distribute `certs/cnteam.test.crt` to teammates so the final demo needs no `-k`.
8. `./scripts/g-failover-watch.sh <seconds> <interval>` while a teammate stops/starts
   backends, to capture failover/502 evidence.

## Phase 2: Mac 2 side built and pre-tested (2026-11-22). Joint demo still pending

> **IPs drift** (campus DHCP). Mac 2 is now **`10.7.3.251`** (was `10.7.14.242`). Re-check every
> session, update `team.env`, then run `./scripts/set-backends.sh <MAC3_IP> <MAC4_IP>`.

| What | Where |
|---|---|
| One nginx template for **both** edges (Ext E "same configuration") | `config/edge.conf.tmpl` |
| Live primary config (rendered, no secrets) | `config/app-cnteam.test.conf` |
| Ext D failover: `max_fails=1 fail_timeout=10s`, `proxy_next_upstream … tries 2`, connect 2 s / read 5 s | template |
| `X-Edge: mac2-primary` / `mac3-standby` header (shows which edge answered) | template |
| HTTP/2 via ALPN (`http2 on;`) | template |
| Edge access log with `upstream=` (shows retries) | `$(brew --prefix)/var/log/nginx/edge-access.log` |
| Standby edge bundle for Mac 3 | `standby-edge/` (README inside) |
| Local pre-test results (failover timings, 304 across backends) | `docs/phase2-edge-pretest.md` |

### Phase 2 run order (Mac 2)
```bash
./scripts/set-backends.sh <MAC3_IP> <MAC4_IP>   # after the session-start IP sync (renders + reloads)
./scripts/verify.sh                             # real DNS + trusted cert: TLS, HTTP/2, X-Edge, A/B, ETag/304
#   LOCAL=1 ./scripts/verify.sh                 # same, but pins the name to Mac 2 (skips DNS)

# Ext D: HA failover (Vishuti stops/starts Backend A on cue)
./scripts/edge-logs.sh D                        # terminal 1, Ctrl-C when done -> evidence/phase2/D-edge-logs-*.txt
./scripts/g-failover-watch.sh 90 1 D            # terminal 2 (better: run it on a CLIENT Mac)

# Ext C: after Vishuti + Anwesha enable pf
./scripts/c-verify-isolation.sh                 # edge still reaches 3001/3002, LB still alternates

# Ext E: standby on Mac 3 (AirDrop the key to Vishuti, never git)
./scripts/edge-logs.sh E                        # watch requests on the primary taper off after the cutover
```
All scripts save output to `evidence/phase2/` with the extension letter as a prefix. None of them use `curl -k`.
