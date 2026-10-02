# Evidence Index

Every piece of Phase 1 evidence in this repo, organized by task letter / failure
demo, so anything can be found in under 30 seconds. See
[`ARCHITECTURE.md`](./ARCHITECTURE.md) for the system overview.

## Task A — LAN setup (network info, ping)
- `mac1-kartikey-dns/evidence/phase1/A-netinfo-Kartikeys-MacBook-Pro.txt`
- `mac1-kartikey-dns/evidence/phase1/A-ping.txt`
- `mac1-kartikey-dns/evidence/phase1/A-service-reachability.txt`
- `mac2-agnik-nginx-edge/evidence/mac2-network-info.txt`
- `mac2-agnik-nginx-edge/evidence/ping-results.txt`
- `backend_a/evidence/task-a-network.txt`
- `backend_a/evidence/task-a-ping.txt`

## Task B — Private DNS resolution
- `mac1-kartikey-dns/evidence/phase1/B-verify-Kartikeys-MacBook-Pro-20261002-122436.txt`
- `backend_a/evidence/dns-resolution.txt`
- `mac2-agnik-nginx-edge/evidence/task-g-final-verify.txt` (dig output, client-side)

## Task C — Backend REST services
- `backend_a/evidence/task-c-local-verify.txt`
- Source: `backend_a/backend_a.py`, `backend_b/backend_b.py`

## Task D — Edge reverse proxy + load balancer
- `backend_a/evidence/task-d-backend-access-log.txt`
- `backend_a/evidence/task-d-load-balancer-evidence.txt`
- `mac2-agnik-nginx-edge/evidence/verify.txt`
- `mac2-agnik-nginx-edge/evidence/task-g-final-verify.txt` (X-Backend alternation, no `-k`)

## Task E — TLS
- `mac1-kartikey-dns/evidence/phase1/C-tls-trusted-20261002-122925.txt`
- `backend_a/evidence/task-e-tls-verified-handshake.txt`
- `mac2-agnik-nginx-edge/evidence/cert-details.txt`
- `mac2-agnik-nginx-edge/evidence/task-g-final-verify.txt` (`SSL certificate verify ok.`)
- Cert (public only): `mac2-agnik-nginx-edge/certs/cnteam.test.crt`,
  `backend_a/config/app.cnteam.test.crt`

## Task F — HTTP caching
- `Cache-Control: max-age=60` confirmed in `mac2-agnik-nginx-edge/evidence/task-g-final-verify.txt`
  and `mac2-agnik-nginx-edge/evidence/verify.txt`

## Task G — Full protocol-flow packet captures (DNS, TCP, TLS, HTTP)
- `mac1-kartikey-dns/evidence/phase1/dns-Kartikeys-MacBook-Pro-20261002-122607.pcap` +
  matching `.txt`
- `mac2-agnik-nginx-edge/evidence/mac2-dns-query-en0.pcapng` (DNS, real LAN traffic)
- `mac2-agnik-nginx-edge/evidence/mac2-tls-handshake-lo0.pcapng` (TCP + TLS handshake)
- `backend_b/evidence/anwesha-dns-tls-capture.pcapng` (DNS + TCP + TLS across two real
  machines — includes a captured `Unknown CA` TLS alert from before her cert was
  trusted, useful as failure-mode evidence too)

## Phase 1 failure demo #1 — wrong DNS server on a client
- `mac1-kartikey-dns/evidence/phase1/F1-wrong-resolver-20261002-122520.txt`

## Phase 1 failure demo #2 — DNS record points to wrong IP
- `mac1-kartikey-dns/evidence/phase1/F2-wrong-record-20261002-122539.txt`

## Phase 1 failure demo #3 — one backend stopped
- `mac2-agnik-nginx-edge/evidence/failover-watch-20261002-125347.txt` (clean failover to
  B at 12:54:51, zero errors; resumes alternating after restart)
- `backend_a/evidence/phase1-demo-backend-a-down.txt`

## Phase 1 failure demo #4 — both backends stopped
- `mac2-agnik-nginx-edge/evidence/failover-watch-20261002-130123.txt` (502 Bad Gateway
  starting 13:04:02)
- `backend_a/evidence/phase1-demo-502-recovery.txt`

## Phase 1 failure demo #5 — wrong destination port on a client
- Run by Anwesha: `curl -v http://10.7.14.242:9999` → `Connection refused` (paired with
  a successful `ping` to the same host). Not yet committed as a file — see note below.

## Still manual / not yet in this repo
- Screenshots: DNS resolver settings before/after (System Settings → Network), and the
  `.pcap`/`.pcapng` files above opened in Wireshark. Flagged as outstanding in
  `mac1-kartikey-dns/README.md`.
- Failure demo #5's output (ping + wrong-port curl) — ask Anwesha to save her terminal
  output into `backend_b/evidence/` and add it here.
