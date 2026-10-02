# Agnik — Mac 2 — nginx Edge + Load Balancer + TLS

## Status: Phase 1 complete

| Item | Result |
|---|---|
| IP | `10.7.14.242` / 255.255.224.0 (/19) / gw `10.7.0.1` / en0 / `fa:4e:b4:04:d0:00` |
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
  `g-failover-watch.sh` (live load-balancer/failover watcher used during demos).
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

## Phase 2 (not started — gated behind Phase 1 approval)
- Extension D (HA failover) — config already supports it via `max_fails`/`fail_timeout`;
  already demonstrated live during Phase 1's failure demos, formal Phase 2 writeup still
  to do.
- Extension C (service isolation) — backend-side firewall rules are Vishuti/Anwesha's
  job; this Mac just needs to confirm it's still the one IP allowed through afterward.
- Extension E (DNS-based edge cutover) — needs a standby nginx on Mac 3 or 4 and
  coordination with Kartikey's DNS record change.
