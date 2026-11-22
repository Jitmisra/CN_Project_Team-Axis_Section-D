# Phase 2 report: Kartikey's paragraphs (Ext A + Ext B)

For Agnik to paste into `PHASE2_REPORT.md` §4. Fill each `[__]` from the evidence files after the demo, then delete
this note. **Don't submit placeholders.**

## Results rows (§2 table)

| Test | Expected | Observed | Pass | Evidence |
|---|---|---|---|---|
| A: primary DNS stopped | clients resolve via Mac 4 | `dscacheutil` → [__], curl (no `-k`) → 200 from Backend [__]; Mac 4 log shows query from [__] | [__] | `mac1-kartikey-dns/evidence/phase2/A-backup-failover-*.txt`, `A-failover-*.pcap` |
| A: both DNS stopped | resolution fails, IP reachable | `Could not resolve host`; `curl -k https://<MAC2_IP>:8443` → [__] | [__] | `A-dns-vs-app-failure.txt` |
| A: both backends stopped | resolves + TLS OK, 502 | `dig` NOERROR, `SSL certificate verify ok`, `HTTP/1.1 502` | [__] | `A-dns-vs-app-failure.txt` |
| B: record change, wait | old answer ≤30 s, then new | change at [__], OS cache flipped at [__] (+[__] s) | [__] | `B-ttl-*.txt`, `B-ttl-onwire-*.txt` |
| B: record change, flush | new answer immediately | flushed at [__], next lookup already new | [__] | `B-ttl-*.txt` |

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
Mac 1 only (so the record change was the only variable), we changed `app.cnteam.test` on the server at [__]. `dig`,
which asks the server directly, showed the new IP immediately. `dscacheutil`, which is what curl and browsers use,
kept returning the old cached IP for [__] s, and only then switched. When we pointed the record at the standby edge,
the curl loop's `X-Edge` header also stayed `mac2-primary` through the stale window before flipping to
`mac3-standby`, so stale DNS was visible at the application layer, not just as an IP. Repeating the change with a
manual flush (`dscacheutil -flushcache; killall -HUP mDNSResponder`) made it take effect on the very next lookup.
The lesson: an authoritative change is instant, but clients see it only after their cached copy expires, so the
TTL is the upper bound on how long a DNS-based cutover takes to reach everyone. That's why production migrations
lower the TTL hours *before* the move (the old, long TTL has to expire first), cut over, then raise it again.
Even after the TTL expires, existing TCP or keep-alive connections never re-resolve and stay on the old server
until they close. So you keep the old edge running until its traffic drains (Ext E).
