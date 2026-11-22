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
| A: primary DNS stopped | clients resolve via Mac 4 | Mac 1 dnsmasq stopped 19:05:00. `dig @Mac1` timed out, and the pcap shows ICMP `udp port 53 unreachable` from Mac 1. `nslookup` → `Server: 10.7.19.42`, `dscacheutil` → 10.7.3.251; Mac 4 replies `A 10.7.3.251` in the en0 pcap. 3× curl by name, no `-k` → HTTP/2 200 (A, B, A) via `mac2-primary`. Primary restarted 19:05:13 | ✅ | `mac1-kartikey-dns/evidence/phase2/A-backup-failover-20261122-190456.txt`, `mac1-kartikey-dns/evidence/phase2/A-failover-20261122-190456-{lo0,en0}.pcap` |
| A: both DNS stopped (contrast) | name resolution fails, IP reachable | _to run (Kartikey ready)_ | | |
| A: both backends stopped (contrast) | resolves + TLS OK, 502 | _to run (Kartikey ready)_ | | |
| B: record change, wait | old answer ≤30 s, then new | TTL 0 → 30 on the wire. Change issued 18:39:44, dnsmasq serving the new IP by 18:39:54; OS cache still old at 18:40:20, new at 18:40:23 (≈30 s); curl `X-Edge: mac2-primary` → `Failed to connect` at the same moment | ✅ | `mac1-kartikey-dns/evidence/phase2/B-ttl-20261122-183943.txt`, `mac1-kartikey-dns/evidence/phase2/B-ttl-onwire-20261122-183628.txt` |
| B: record change, flush | new answer immediately | record reverted 18:40:36, cache still stale at 18:40:38; flushed 18:40:39, next lookup already 10.7.3.251 and `X-Edge: mac2-primary` | ✅ | `mac1-kartikey-dns/evidence/phase2/B-ttl-20261122-183943.txt` |
| C: client → 3001 direct (Mac 3 pf) | blocked | before (19:02:23): `nc` succeeded, curl 200. After (19:10:43): `nc` **Connection refused** (pf `block return`), curl failed to connect; `https://app.cnteam.test:8443` still 200 A/B | ✅ | `mac1-kartikey-dns/evidence/phase2/C-client-blocked.txt` |
| C: client → 3002 direct (Mac 4 pf) | blocked | blocked at ~18:53 (`nc` from Mac 1: Operation timed out, pf drop). pf was then disabled on Mac 4 because its rules also blocked Mac 4's *outgoing* traffic (`No route to host` to Mac 2), and 3002 was open again at 19:10:43 / 19:13:09. **Re-test after Anwesha re-enables port-only rules** | ⏳ | `mac1-kartikey-dns/evidence/phase2/C-client-blocked.txt` |
| C: edge → 3001/3002 | allowed, LB alternates | Mac 2 → 3001 and 3002 both open, direct HTTP 200, through the edge A B A B A B | ✅ | `mac2-agnik-nginx-edge/evidence/phase2/C-edge-still-allowed-20261122-185417.txt` |
| C: rollback | direct access restored | pf anchor flushed and token released (`firewall-disable.sh`); direct nc/curl to 3001 restored from LAN clients | ✅ | `backend_a/scripts/firewall-disable.sh` |
| D: Backend A stopped | 100% served by B, 0 errors | A down 18:48:13–18:48:59 by Vishuti's clock (46 s; watcher on Mac 2 saw B-only 18:48:12–18:48:57, ~1 s clock skew): every request served by B. **252/252 requests HTTP 200** over 5 min. nginx re-probed A at 18:48:14, :29, :44 (each `Connection refused`) and retried on B **inside the same request** | ✅ | `mac2-agnik-nginx-edge/evidence/phase2/D-watch-agniks-MacBook-Pro-20261122-184729.txt`, `D-edge-logs-20261122-184728.txt` |
| D: Backend A restarted | alternation resumes in ~10–15 s | A served again at 18:48:58, A/B alternation resumed straight away | ✅ | same files |
| E: cutover to standby | cached clients on old edge ≤30 s, then standby | Mac 1 record → 10.7.15.127 at 18:57:53. Mac 1 client kept hitting `mac2-primary` until 18:58:18, flipped to `mac3-standby` at 18:58:20 (**27 s**, within TTL 30), 0 failed requests, A/B balancing continued on the standby. Primary edge log: Mac 1 requests stop after 18:58:17 and return at 18:59:38 (26 s after cut back at 18:59:12); Mac 1 client flipped back to `mac2-primary` at 18:59:39 (**27 s**). Watcher total: **90 requests, 0 errors**, A/B balancing on both edges. Standby log (Mac 3): Mac 1 traffic arrives continuously from **18:58:20**, all 200, `edge=mac3-standby`, HTTP/2 over TLS 1.3. **Finding:** the backup DNS (Mac 4) was not updated, so it kept answering 10.7.3.251. Clients using Mac 4 would have stayed on the old edge (servers disagreeing) | ✅ (Mac 1 path) | Kartikey's `E-cutover-*.txt`, `mac2-agnik-nginx-edge/evidence/phase2/E-edge-logs-20261122-185624.txt` |
| E: redo with BOTH DNS servers | both servers switch together; same TTL behaviour | Mac 1 cut over 19:18:42, Mac 4 mirrored by 19:18:52 (sync-check: both 10.7.15.127). Mac 1 client → `mac3-standby` at 19:19:13 (~30 s), cut back 19:20:36 → `mac2-primary` at 19:21:06 (30 s = TTL). **105/105 HTTP 200, 0 errors.** Primary edge log: last Mac 1 request 19:19:11, first again 19:21:06 (matches the client side to the second). **Finding:** on the way back Mac 4 reverted at ~19:20:05, ~30 s *before* Mac 1, so the two servers disagreed for ~30 s. In production one control plane (hosted zone / zone transfer) changes every name server atomically | ✅ | `mac1-kartikey-dns/evidence/phase2/E-redo-watch-*-191832.txt`, `E-redo-dns-sync-*-191852.txt`, `mac2-agnik-nginx-edge/evidence/phase2/E-edge-logs-20261122-191657.txt` |
| E: primary edge stopped after cutover | no client impact | _optional, not run_ | | |

## 3. Troubleshooting findings (Ext F + drill)

Summarise the fault drill (`evidence/phase2/F-drill-log.md`) and the actual faculty-injected fault: symptom → layer-by-layer
checks → root cause → fix → verification. Note which faults were "silent" behind redundancy and how you spotted them.

**Finding 1 (DNS layer, Kartikey): a silent fault behind redundancy.** At 19:10 and again at 19:13 the backup DNS on Mac 4 answered `app.cnteam.test → 10.7.15.127` (the standby edge),
while Mac 1 answered 10.7.3.251. It was a leftover from practising the Ext E mirror command. Nothing visibly
broke: the standby edge was healthy, so clients whose resolver happened to pick Mac 4 got HTTP 200 from
`mac3-standby` instead of `mac2-primary`. That's the dangerous kind of fault, because redundancy hides it. It only
showed up because we compare both servers explicitly (`sync-check.sh`, board check "DNS servers agree").
`f-dns-check.sh` isolated it layer by layer: Mac 1 dnsmasq running, config valid, en0 IP matches `team.env`,
Mac 1 answer correct, no `/etc/hosts` override (dig = dscacheutil), query log shows the client's queries
arriving → Mac 1 healthy; **only Mac 4's data differs** → a DNS data fault on the backup, not a network or app
fault. Fix: rewrite the record on Mac 4 and restart. Lesson: with two name servers, "it resolves" isn't enough.
Both must give the *same* answer, and checking that has to be automated, which is what zone transfers or one
managed hosted zone do in production. Evidence: `mac1-kartikey-dns/evidence/phase2/F-dns-check-mac4-mismatch-20261122-191317.txt`.

## 4. Learning summary (one paragraph per extension)

**Ext A: Backup DNS** _(Kartikey, with Anwesha hosting the backup)_

Phase 1 had one DNS server (dnsmasq on Mac 1), so losing it made `app.cnteam.test` unreachable by name even
though the edge and both backends were healthy. In Phase 2 Anwesha runs a second dnsmasq on Mac 4. It's rendered
from the same template, so its records match Mac 1's, and every client lists Mac 1 then Mac 4 as resolvers. When
we stopped Mac 1's dnsmasq, queries sent to Mac 1 got no answer (ICMP port unreachable in `A-failover-*-lo0.pcap`).
mDNSResponder moved to Mac 4, whose query log showed the lookups arriving, and `curl https://app.cnteam.test:8443`
still returned 200 over a trusted TLS connection, with no `-k`. macOS doesn't do strict primary-then-secondary: it
can send a query to either listed server. So redundancy only works if both servers give the **same** answer, and
we check that before every demo with `sync-check.sh`. In production one zone is served by several name servers,
kept in sync by zone transfer (AXFR/IXFR) or a managed hosted zone. The contrast test showed that a
**DNS failure** and an **application failure** look different and sit at different layers. With both DNS servers
down, the client fails before any packet reaches the edge (`Could not resolve host`), while the edge still answers
by IP. With DNS up and both backends down, name resolution, TCP and TLS all succeed, and nginx returns
`502 Bad Gateway`. We also hit DHCP drift during setup: Mac 1's IP changed from 10.7.8.82 to 10.7.22.176, and the
Phase 1 config (`bind-interfaces` on a fixed IP) silently stopped dnsmasq. We switched to interface-based
listening. Clients still have to be told the new resolver IP, which is why real DNS servers use static addresses.

**Ext B: DNS TTL and record change** _(Kartikey)_

In Phase 1, record changes showed up instantly because dnsmasq's default `local-ttl` is 0, which tells clients
not to cache. That hid the most important property of DNS in a migration. We set `local-ttl=30` and confirmed it
on the wire: the `dig +noall +answer` TTL column went from 0 to 30 (`B-ttl-onwire-*.txt`). With clients pointed at
Mac 1 only (so the record change was the only variable), we changed `app.cnteam.test` from Mac 2 (10.7.3.251) to 10.7.19.42 at 18:39:44. `dig`,
which asks the server directly, showed the new IP immediately. `dscacheutil`, which is what curl and browsers use,
kept returning the old cached IP until about 30 s after it was cached (still old at 18:40:20, new at 18:40:23). The
curl loop showed the same thing at the application layer: requests kept reaching the Mac 2 edge
(`X-Edge: mac2-primary`, 200) through the whole stale window, then failed to connect once the cache
expired, because the new IP had no edge. So clients whose cache hadn't expired yet were protected from a bad
record, and anyone who looked it up afterwards was hit at once. Repeating the change with a
manual flush (`dscacheutil -flushcache; killall -HUP mDNSResponder`) made it take effect on the very next lookup.
The lesson: an authoritative change is instant, but clients see it only after their cached copy expires, so the
TTL is the upper bound on how long a DNS-based cutover takes to reach everyone. That's why production migrations
lower the TTL hours *before* the move (the old, long TTL has to expire first), cut over, then raise it again.
Even after the TTL expires, existing TCP or keep-alive connections never re-resolve and stay on the old server
until they close. So you keep the old edge running until its traffic drains (Ext E).

**Ext C: Service isolation** _(Vishuti)_

In Phase 1, backend port 3001 was directly reachable by any machine on the Wi-Fi, violating the cloud architecture principle that application backends should sit in a private tier isolated behind the edge load balancer. In Phase 2, we implemented kernel-level service isolation on macOS using Darwin's Packet Filter (`pf`). To avoid clobbering Apple's default system anchors (`com.apple/*`), we structured our configuration inside a dedicated sub-anchor (`anchor "cnteam"`). Within this anchor, the authorized edge tier is defined in a dynamic kernel table (`table <edges> { 10.7.3.251 }`). Traffic originating on loopback (`lo0`) is explicitly permitted via `pass in quick on lo0`, preserving local monitoring and local Standby Edge access. Traffic from `<edges>` is passed with stateful inspection (`keep state`). For all other LAN hosts, we configured `block return in quick proto tcp from any to any port 3001`, which actively responds with a TCP RST. This gives an immediate "Connection refused" to unauthorized clients like Mac 1 (`nc -vz -G 3 10.7.15.127 3001` failed instantly at 19:10:43), clearly separating administrative blocking from silent network dropouts (`block drop` / timeout). When verified through the edge (`https://app.cnteam.test:8443`), traffic flowed cleanly with round-robin alternation. For safe operations, we built token-based lifecycle scripts with `pfctl -E` and `pfctl -X <token>`, taking pre-activation backups of `/etc/pf.conf` and ruleset state so testing never permanently alters the OS network stack. Rollback via `firewall-disable.sh` flushes the anchor and releases the token, immediately restoring direct client reachability.

**Ext D: HA failover** _(Agnik)_

In Phase 1 the upstream used `max_fails=2 fail_timeout=5s`. For Phase 2 the edge config is rendered from one
template (`config/edge.conf.tmpl`) with `max_fails=1 fail_timeout=10s`, `proxy_next_upstream error timeout
http_502 http_503 http_504`, `proxy_next_upstream_tries 2`, `proxy_connect_timeout 2s` and `proxy_read_timeout 5s`, plus an edge
access log that records `$upstream_addr`. With a client watcher running for 5 minutes, Vishuti stopped Backend A
at 18:48:13 and restarted it at 18:48:59. Every request in that window was served by Backend B, and all 252/252
requests returned HTTP 200. The key evidence is in the edge log: at 18:48:14, 18:48:29 and 18:48:44 nginx re-tried A
(`connect() failed (61: Connection refused)`, then `upstream server temporarily disabled`), and the log line for
each of those requests shows `upstream=10.7.15.127:3001, 10.7.19.42:3002`. The retry happened **inside the same client
request**, so the client never saw the failure. A rejoined at 18:48:58. A local pre-test showed that the type of failure
sets the cost: a refused connection costs nothing, a silent host costs one 2 s connect timeout, and a hung backend
costs one 5 s read timeout. After that first failure, passive health checking takes the backend out for 10 s.
This is the main gap compared with a cloud load balancer: nginx open source only learns from real failed requests (passive),
while AWS ALB target groups or nginx Plus probe on a timer (active). The remaining single point of failure is the
edge itself. If nginx on Mac 2 dies, DNS still resolves but nothing answers. Removing it needs a second
active edge plus health-checked DNS failover, a floating VIP (VRRP/keepalived), anycast, or a managed multi-AZ load balancer.
Ext E shows the manual version.

**Ext E: Controlled edge migration** _(Agnik + Vishuti)_

The standby edge on Mac 3 is rendered from the **same template** as the primary. Only `X-Edge: mac3-standby`
and a local upstream for Backend A differ. It uses the same certificate and private key, because clients trust
that specific certificate, and every edge of a service must be able to prove it is `app.cnteam.test`. The
`X-Edge` header made the cutover visible in plain curl output. With TTL 30 on both DNS servers, Kartikey repointed
`app.cnteam.test` to the standby at 18:57:53. His client kept reaching `mac2-primary` from its cached answer until
18:58:18, then flipped at 18:58:20 (27 s). The primary edge log shows the same thing from the other side: Mac 1's
requests stop after 18:58:17, and the standby log shows them arriving from 18:58:20. The cut-back took another
27 s, with 0 failed requests. The first run exposed a real operational mistake: the backup DNS on Mac 4 was not
updated, so clients that asked Mac 4 would have stayed on the old edge. In the redo both servers switched (Mac 4
10 s after Mac 1). The client flipped at 19:19:13 and the primary saw its last Mac 1 request at 19:19:11. After the
cut-back at 19:20:36 the client returned at 19:21:06 (30 s = TTL), with 105/105 requests OK. On the way back Mac 4
reverted about 30 s before Mac 1, so the two servers briefly disagreed. Production systems avoid this with one
control plane (a hosted zone or zone transfer) that changes every name server together. Lessons: a DNS cutover
is manual and bounded by the TTL (tens of seconds here, often minutes in production, where the TTL is lowered in
advance). Existing keep-alive connections ignore DNS entirely, so the old edge must keep running until its traffic
drains. And this is migration, not automatic failover, which is why the edge is still the single point of failure in Ext D.

**Ext F: Troubleshooting** _(everyone)_:

- **Backend & PF isolation layer (Vishuti):** Our layered troubleshooting script (`scripts/troubleshoot.sh`) isolates faults sequentially: IP and subnet verification on `en0`, socket binding on `:3001` (`lsof -i :3001`), pf anchor status and `<edges>` table inspection (`pfctl -a cnteam -sr -t edges -T show`), and local HTTP checks (`/api/status` and `/api/info`). This separated application-layer crashes from firewall drops. In particular, when DHCP shifted Mac 2's IP from 10.7.14.242 to 10.7.3.251, the edge was immediately blocked by pf with `Connection refused` (causing 502s at the edge); inspecting the `<edges>` table quickly surfaced the mismatch, which was resolved by re-rendering the anchor template with the new IP. Local loopback testing (`127.0.0.1:3001/api/info`) verified that the deterministic ETag (`"39464b4ed106dad1"`) and 304 revalidation functioned correctly independent of network-layer packet filters.

## 5. Remaining single points of failure and how we'd remove them

The Mac 2 edge is still the SPOF for live traffic (Ext E is a manual, TTL-bound migration, not automatic failover). Options:
two active edges + health-checked DNS failover, a VIP with VRRP/keepalived, anycast, or a managed multi-AZ load balancer.
Also mention: same Wi-Fi/AP for all machines, the single self-signed cert/key, passive-only health checks.
