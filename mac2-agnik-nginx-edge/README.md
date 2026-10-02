# Agnik — Mac 2 — nginx Edge + Load Balancer + TLS

## Already done on this Mac
- **Task A**: network details captured — `evidence/mac2-network-info.txt`.
  Mac 2 row for the shared IP table:
  `10.7.14.242 | 255.255.224.0 (/19) | gateway 10.7.0.1 | en0 | fa:4e:b4:04:d0:00`
  (Same campus subnet as Kartikey's Mac 1 — 10.7.0.0/19, gateway 10.7.0.1.)
- **nginx installed** via Homebrew (`/opt/homebrew/opt/nginx`). Homebrew's default
  config binds **port 8080**, not 80, so it runs without sudo — this project treats
  8080/8443 as a fully valid substitution (no marks lost). Already running as a
  `brew services` background service.
- **TLS cert generated** — `certs/cnteam.test.crt` / `certs/cnteam.test.key`, self-signed,
  SAN covers `app.cnteam.test` and `api.cnteam.test`, 365-day validity. Details dumped
  to `evidence/cert-details.txt`. **The `.key` never leaves this machine or the
  Configuration Bundle** — only `.crt` goes to teammates for trust install.
- **nginx server-block script is ready** (`scripts/d-install-nginx.sh`) but not yet
  run — it refuses to run until Backend A and Backend B IPs are filled into
  `team.env`.
- **team.env** has this machine's IP filled in; `TEAM_DOMAIN=cnteam.test` (swap if
  your class assigned a real team name — tell the other 3 machines too, they all
  need to match).

## Status: Phase 1 edge is live and verified
All 4 IPs collected and in `team.env`:
- Mac 1 (Kartikey/DNS): 10.7.8.82
- Mac 2 (Agnik/Edge, this machine): 10.7.14.242
- Mac 3 (Vishuti/Backend A): 10.7.18.246:3001
- Mac 4 (Anwesha/Backend B): 10.7.5.197:3002

nginx is running with the real upstream pool, `./scripts/verify.sh` confirms:
- TLS 1.3 handshake completes end to end on port 8443 (ChaCha20-Poly1305 cipher).
- `X-Backend` alternates `A, B, A, B, ...` across repeated requests — round-robin
  load balancing confirmed working.
- `Cache-Control: max-age=60` present on responses.
- Ping to all 3 teammates: 0% loss.

One bug found and fixed along the way: `brew --prefix nginx` returns the formula's
Cellar symlink, not `HOMEBREW_PREFIX` — the config has to be written to
`$(brew --prefix)/etc/nginx/servers/`, not `$(brew --prefix nginx)/etc/nginx/servers/`,
or nginx silently never loads it. Fixed in `scripts/d-install-nginx.sh`.

## Phase 1: fully verified, no -k, no --resolve
- This Mac's DNS now points at Kartikey's Mac 1 (`10.7.8.82`) —
  `scripts/switch-dns.sh set` (original setting backed up in
  `evidence/mac2-dns-original.txt`, revert with `scripts/switch-dns.sh revert`).
- `dig app.cnteam.test` resolves to `10.7.14.242` via `10.7.8.82`.
- This Mac trusts its own cert (`security add-trusted-cert ... login.keychain-db`,
  no sudo needed).
- `curl https://app.cnteam.test:8443/api/status` with **no `-k`**:
  `SSL certificate verify ok.`, TLS 1.3 / AEAD-CHACHA20-POLY1305-SHA256,
  `X-Backend` alternates `B,A,B,A,B,A,B,A,B,A` across 10 requests,
  `Cache-Control: max-age=60` present. Full output in `evidence/task-g-final-verify.txt`.
- Kartikey (Mac 1) has independently verified the same thing from his machine —
  trusted the cert, DNS resolves, HTTPS works with no `-k`.
- Vishuti (Mac 3) also ran a verified end-to-end check from her machine with the
  cert via `--cacert` (no `-k`) — same result.

## Still to do
- Anwesha (Mac 4) still needs to: trust `certs/cnteam.test.crt`, point her DNS at
  `10.7.8.82`, and run her own Task G evidence capture (her traffic crosses the Wi-Fi
  between two machines, which is better DNS/TCP packet evidence than a loopback
  capture).
- ~~Wireshark capture~~ Done: `evidence/mac2-dns-query-en0.pcapng` (real DNS
  query/response to Kartikey's Mac 1 over the wire, confirmed via MAC addresses) and
  `evidence/mac2-tls-handshake-lo0.pcapng` (TCP 3-way handshake + TLS ClientHello/
  ServerHello into port 8443 — on `lo0` because the client and nginx are the same
  machine here, same as Kartikey's loopback note for his DNS capture). Open both in
  Wireshark for the screenshot evidence.
- Phase 2: Extension D (HA failover — config already supports it via
  `max_fails`/`fail_timeout`, needs a live stop/restart demo with
  `scripts/g-failover-watch.sh`), Extension C (confirm isolation once Vishuti/Anwesha
  firewall rules are up), Extension E (standby nginx for DNS cutover, coordinate with
  Kartikey).

## Run order (once Backend A/B IPs are known)
1. Fill `MAC1_DNS_IP`, `MAC3_BACKEND_A_IP`, `MAC4_BACKEND_B_IP` into `team.env`.
2. `./scripts/a-ping.sh` — confirm reachability to all three teammates.
3. `./scripts/d-install-nginx.sh` — renders and loads the real server block
   (upstream pool + TLS), restarts nginx.
4. `./scripts/verify.sh` — curls through the edge, shows TLS handshake, checks the
   `X-Backend` header alternates A/B, checks `Cache-Control`. Uses `--resolve` + `-k`
   as a local sanity check (DNS + trusted-cert demo must use the real thing later).
5. Give every teammate `certs/cnteam.test.crt` and have them run the
   `security add-trusted-cert` command printed by `e-make-cert.sh` so the **final
   demo has zero cert warnings and uses no `curl -k`**.
6. During the live failure demos: `./scripts/g-failover-watch.sh 30 1` while a
   teammate stops/restarts Backend A, then again with both backends stopped, to
   capture the 502 evidence.

## Found on this Mac
- No prior nginx/placeholder config existed — clean install, nothing needed renaming.
- Homebrew's nginx defaults to port 8080 for HTTP and has no HTTPS block until we add
  one — `scripts/d-install-nginx.sh` adds the 8443 SSL block for us.
- Same subnet/gateway as Kartikey's Mac 1 (10.7.0.0/19) — likely the same campus
  Wi-Fi. Per his note, if laptop-to-laptop ping fails for Mac 3/Mac 4, switch all 4
  Macs to a phone hotspot instead.

## Still to do
- [ ] Get Mac 3 and Mac 4 IPs, fill into `team.env`
- [ ] Run `d-install-nginx.sh`, confirm proxying + round-robin (`verify.sh`)
- [ ] Distribute `.crt` to all teammates, confirm trusted (no `-k` needed anywhere)
- [ ] Screenshot/record Wireshark TLS handshake on port 8443 (needs Wireshark —
      `brew install --cask wireshark`, same as Kartikey needs for DNS capture)
- [ ] Phase 2: Extension D (HA failover config — `max_fails`/`fail_timeout` already in
      the generated config, just needs live verification), Extension C (confirm
      isolation after Vishuti/Anwesha add firewall rules), Extension E (stand up
      standby nginx on Mac 3 or 4 for DNS-cutover demo, coordinate with Kartikey)
