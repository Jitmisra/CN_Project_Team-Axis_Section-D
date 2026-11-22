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
- `backend_b/evidence/phase1/F5-wrong-port.txt` (Anwesha: ping Mac 2 reachable, port 9999 connection refused, port 8443 open)

## Phase 2 — Resilience, Isolation, and Troubleshooting

### Extension A — Backup DNS Server & Failover
- `backend_b/config/cnteam.conf` (Mac 4 backup dnsmasq config with `interface=en0` and `local-ttl=30`)
- `backend_b/scripts/dns-backup.sh` (Management script: install, status, set-record, sync-check)
- `backend_b/evidence/phase2/A-backup-dns-dig.txt` (`dig @10.7.19.42 app.cnteam.test` output)
- `backend_b/evidence/phase2/A-resolver-settings.png` (Screenshot of Wi-Fi DNS resolvers: 10.7.22.176 primary, 10.7.19.42 backup)
- `mac1-kartikey-dns/scripts/demo-backup-failover.sh` (Kartikey: primary DNS stopped while resolution continues)

### Extension B — TTL & Record Modification
- `mac1-kartikey-dns/config/ttl.conf` (Kartikey: TTL 30s template)
- `mac1-kartikey-dns/scripts/demo-ttl.sh` (Kartikey: record change test)
- `mac1-kartikey-dns/evidence/phase2/B-ttl-20261122-183943.txt` (client watcher: cached answer held ~30 s, then switched; flush = instant). Anwesha's own client-side copy was not committed

### Extension C — Service Isolation (Firewall)
- `backend_a/config/pf_rules_isolation.conf` (Vishuti: port 3001 isolation)
- `backend_b/config/pf_rules_isolation.conf` (Anwesha: port 3002 anchor isolation for edge tier)
- `backend_b/scripts/firewall-enable.sh` / `firewall-disable.sh` / `firewall-status.sh`
- `backend_b/evidence/phase2/C-isolation-3002.txt` (Evidence: Mac 1 blocked, Mac 2 allowed, edge LB functioning)

### Extension D — High Availability & Passive Failover
- `mac2-agnik-nginx-edge/scripts/g-failover-watch.sh` (Agnik: edge load-balancer observer)
- `mac2-agnik-nginx-edge/evidence/phase2/D-watch-agniks-MacBook-Pro-20261122-184729.txt` (watcher: Backend A stopped 18:48:13–18:48:59, 252/252 HTTP 200, B-only during the outage) + `D-edge-logs-20261122-184728.txt` (in-request retries)

### Extension E — DNS-Based Standby Edge Migration
- `mac1-kartikey-dns/scripts/cutover.sh` (Kartikey: DNS repoint to standby edge)
- `mac2-agnik-nginx-edge/scripts/switch-dns.sh`
- `backend_b/evidence/phase2/E-client-observation.txt` (Anwesha: client observation of X-Edge header switching from primary to standby)

### Extension F — Faculty Fault Diagnosis
- `tools/diagnose.sh` (Anwesha: 9-layer automated diagnosis tool)
- `backend_b/evidence/phase2/F-diagnose-healthy.txt` (Baseline clean diagnosis run)
- `backend_b/evidence/phase2/F-caching-304-B.txt` (ETag validation & 304 Not Modified verification from Backend B)

