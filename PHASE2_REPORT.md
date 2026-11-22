# Phase 2 Final Report: Team Axis, Section D

> Draft. Each extension lead fills in their paragraph and results rows; Agnik assembles.
> Evidence paths are listed in `EVIDENCE_INDEX.md`.

**Team:** Kartikey (Mac 1) · Agnik (Mac 2) · Vishuti (Mac 3) · Anwesha (Mac 4)
**Domain:** `app.cnteam.test`, `api.cnteam.test` · **Edge ports:** 8080 → 8443 (TLS)
**IP table on review day:** _(fill in from the session-start IP sync)_

| Machine | Owner | Roles in Phase 2 | IPv4 (review day) |
|---|---|---|---|
| Mac 1 | Kartikey | Primary DNS, test client | 10.7.22.176 (2026-11-22 18:12) |
| Mac 2 | Agnik | Primary edge (nginx LB + TLS) | 10.7.3.251 (2026-11-22, re-check) |
| Mac 3 | Vishuti | Backend A :3001, standby edge (Ext E) | 10.7.15.127 (2026-11-22 18:12) |
| Mac 4 | Anwesha | Backend B :3002, backup DNS, test client | 10.7.19.42 (2026-11-22 18:12) |

## 1. What changed from Phase 1

| Area | Phase 1 | Phase 2 | Config file |
|---|---|---|---|
| DNS | single dnsmasq on Mac 1, TTL 0 | + backup dnsmasq on Mac 4 (identical records), TTL 30, clients list both | `mac1-kartikey-dns/config/…` |
| Edge | round-robin, `max_fails=2 fail_timeout=5s` | tuned failover (`max_fails=1`, `fail_timeout=10s`, `proxy_next_upstream_tries 2`), edge access log with upstream, `X-Edge` header, HTTP/2 | `mac2-agnik-nginx-edge/config/…` |
| Standby edge | none | nginx on Mac 3, same cert, for DNS-based cutover | `mac2-agnik-nginx-edge/standby-edge/` |
| Backends | `/`, `/api/status`, Cache-Control | + `/api/info` with consistent ETag → 304, correct HEAD | `backend_a/backend_a.py`, `backend_b/backend_b.py` |
| Isolation | backend ports open to the whole LAN | pf anchor: only the edge tier (`<edges>`) reaches 3001/3002, rollback scripts | `backend_a/config/…`, `backend_b/config/…` |
| Diagnosis | per-machine scripts | team `tools/diagnose.sh` (layered DNS → TCP → TLS → HTTP → backend) | `tools/` |

## 2. Resilience tests and results

| Test | Expected | Observed (numbers/timestamps) | Pass | Evidence |
|---|---|---|---|---|
| A: primary DNS stopped | clients resolve via Mac 4 | | | |
| A: both DNS stopped (contrast) | name resolution fails, IP reachable | | | |
| A: both backends stopped (contrast) | resolves + TLS OK, 502 | | | |
| B: record change, wait | old answer ≤30 s, then new | record changed 18:39:44. Client OS cache kept the old IP until **t=+29 s**, then switched (dig showed the new IP from t=0) | ✅ | `mac1-kartikey-dns/evidence/phase2/B-ttl-20261122-183943.txt` |
| B: record change, flush | new answer immediately | record changed back 18:40:36, client still stale. Manual flush at 18:40:39 → new answer **immediately** | ✅ | same file |
| C: client → 3001/3002 direct | blocked (refused / timeout) | Mac 1 → 10.7.19.42:3002: `Operation timed out` (pf drop). 3001 on Mac 3: _pending Kartikey's test_ | ✅ (3002) | Kartikey's `C-client-blocked.txt` |
| C: edge → 3001/3002 | allowed, LB alternates | Mac 2 → 3001 and 3002 both open, direct HTTP 200, through the edge A B A B A B | ✅ | `mac2-agnik-nginx-edge/evidence/phase2/C-edge-still-allowed-20261122-185417.txt` |
| C: rollback | direct access restored | | | |
| D: Backend A stopped | 100% served by B, 0 errors | A down 18:48:13–18:48:59 by Vishuti's clock (46 s; watcher on Mac 2 saw B-only 18:48:12–18:48:57, ~1 s clock skew): every request served by B. **252/252 requests HTTP 200** over 5 min. nginx re-probed A at 18:48:14, :29, :44 (each `Connection refused`) and retried on B **inside the same request** | ✅ | `mac2-agnik-nginx-edge/evidence/phase2/D-watch-agniks-MacBook-Pro-20261122-184729.txt`, `D-edge-logs-20261122-184728.txt` |
| D: Backend A restarted | alternation resumes in ~10–15 s | A served again at 18:48:58, A/B alternation resumed straight away | ✅ | same files |
| E: cutover to standby | cached clients on old edge ≤30 s, then standby | Mac 1 record → 10.7.15.127 at 18:57:53. Mac 1 client kept hitting `mac2-primary` until 18:58:18, flipped to `mac3-standby` at 18:58:20 (**27 s**, within TTL 30), 0 failed requests, A/B balancing continued on the standby. Primary edge log: Mac 1 requests stop after 18:58:17 and return at 18:59:38 (26 s after cut back at 18:59:12); Mac 1 client flipped back to `mac2-primary` at 18:59:39 (**27 s**). Watcher total: **90 requests, 0 errors**, A/B balancing on both edges. Standby log (Mac 3): Mac 1 traffic arrives continuously from **18:58:20**, all 200, `edge=mac3-standby`, HTTP/2 over TLS 1.3. **Finding:** the backup DNS (Mac 4) was not updated, so it kept answering 10.7.3.251. Clients using Mac 4 would have stayed on the old edge (servers disagreeing) | ✅ (Mac 1 path) | Kartikey's `E-cutover-*.txt`, `mac2-agnik-nginx-edge/evidence/phase2/E-edge-logs-20261122-185624.txt` |
| E: primary edge stopped after cutover | no client impact | | | |

## 3. Troubleshooting findings (Ext F + drill)

Summarise the fault drill (`evidence/phase2/F-drill-log.md`) and the actual faculty-injected fault: symptom → layer-by-layer
checks → root cause → fix → verification. Note which faults were "silent" behind redundancy and how you spotted them.

## 4. Learning summary (one paragraph per extension)

**Ext A: Backup DNS** _(Anwesha)_:

**Ext B: DNS TTL and record change** _(Kartikey)_:

**Ext C: Service isolation** _(Vishuti)_:

**Ext D: HA failover** _(Agnik)_:

**Ext E: Controlled edge migration** _(Agnik + Vishuti)_:

**Ext F: Troubleshooting** _(everyone)_:

## 5. Remaining single points of failure and how we'd remove them

The Mac 2 edge is still the SPOF for live traffic (Ext E is a manual, TTL-bound migration, not automatic failover). Options:
two active edges + health-checked DNS failover, a VIP with VRRP/keepalived, anycast, or a managed multi-AZ load balancer.
Also mention: same Wi-Fi/AP for all machines, the single self-signed cert/key, passive-only health checks.
