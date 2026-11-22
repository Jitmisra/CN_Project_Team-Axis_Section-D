# Phase 2 report: Kartikey's paragraphs (Ext A + Ext B)

For Agnik to paste into `PHASE2_REPORT.md` §4. Fill each `[__]` from the evidence files after the demo, then delete
this note. **Don't submit placeholders.**

## Results rows (§2 table)

| Test | Expected | Observed | Pass | Evidence |
|---|---|---|---|---|
| A: primary DNS stopped | clients resolve via Mac 4 | Mac 1 dnsmasq stopped 19:05:00. `dig @Mac1` timed out, and the pcap shows ICMP `udp port 53 unreachable` from Mac 1. `nslookup` → `Server: 10.7.19.42`, `dscacheutil` → 10.7.3.251; Mac 4 replies `A 10.7.3.251` in the en0 pcap. 3× curl by name, no `-k` → HTTP/2 200 (A, B, A) via `mac2-primary`. Primary restarted 19:05:13 | ✅ | `A-backup-failover-20261122-190456.txt`, `A-failover-20261122-190456-{lo0,en0}.pcap` |
| A: both DNS stopped | resolution fails, IP reachable | Mac 1 stopped 19:38:17, Mac 4 confirmed down 19:38:28 (3 misses). Both `dig`s timed out; curl by name: `Resolving timed out after 8000 ms`. Same edge by IP: `nc :8443` succeeded, `curl -k https://10.7.3.251:8443` → HTTP/2 200 → **DNS layer failure, app healthy**. Both DNS back by 19:40:12 | ✅ | `A-dns-vs-app-failure.txt` |
| A: both backends stopped | resolves + TLS OK, 502 | A stopped 19:40:44, B shortly after; 19:42:50: `dig` + `dscacheutil` → 10.7.3.251, `nc :8443` succeeded, TLS 1.3 `SSL certificate verify ok` (no `-k`), then `HTTP/2 502` → **application layer failure, DNS fine**. A back 19:43:40, B restarted after | ✅ | `A-dns-vs-app-failure.txt` |
| B: record change, wait | old answer ≤30 s, then new | TTL 0 → 30 on the wire. Change issued 18:39:44, dnsmasq serving the new IP by 18:39:54; OS cache still old at 18:40:20, new at 18:40:23 (≈30 s); curl `X-Edge: mac2-primary` → `Failed to connect` at the same moment | ✅ | `B-ttl-20261122-183943.txt`, `B-ttl-onwire-20261122-183628.txt` |
| B: record change, flush | new answer immediately | record reverted 18:40:36, cache still stale at 18:40:38; flushed 18:40:39, next lookup already 10.7.3.251 and `X-Edge: mac2-primary` | ✅ | `B-ttl-20261122-183943.txt` |
| C: client → 3001 direct (Mac 3 pf) | blocked | before (19:02:23): `nc` succeeded, curl 200. After (19:10:43): `nc` **Connection refused** (pf `block return`), curl failed to connect; `https://app.cnteam.test:8443` still 200 A/B | ✅ | `C-client-blocked.txt` |
| C: client → 3002 direct (Mac 4 pf) | blocked | **still open** from Mac 1 at 19:10:43 and 19:13:09 (`nc` succeeded): Anwesha's pf wasn't blocking Mac 1 yet | ❌ (pending) | `C-client-blocked.txt` |

## Ext A: Backup DNS

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

## Ext B: DNS TTL and controlled record change

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

## Ext F finding (DNS layer): a silent fault behind redundancy

At 19:10 and again at 19:13 the backup DNS on Mac 4 answered `app.cnteam.test → 10.7.15.127` (the standby edge),
while Mac 1 answered 10.7.3.251. It was a leftover from practising the Ext E mirror command. Nothing visibly
broke: the standby edge was healthy, so clients whose resolver happened to pick Mac 4 got HTTP 200 from
`mac3-standby` instead of `mac2-primary`. That's the dangerous kind of fault, because redundancy hides it. It only
showed up because we compare both servers explicitly (`sync-check.sh`, board check "DNS servers agree").
`f-dns-check.sh` isolated it layer by layer: Mac 1 dnsmasq running, config valid, en0 IP matches `team.env`,
Mac 1 answer correct, no `/etc/hosts` override (dig = dscacheutil), query log shows the client's queries
arriving → Mac 1 healthy; **only Mac 4's data differs** → a DNS data fault on the backup, not a network or app
fault. Fix: rewrite the record on Mac 4 and restart. Lesson: with two name servers, "it resolves" isn't enough.
Both must give the *same* answer, and checking that has to be automated, which is what zone transfers or one
managed hosted zone do in production. Evidence: `F-dns-check-mac4-mismatch-20261122-191317.txt`.
