# Viva Prep: Kartikey (Mac 1, DNS)

Learn the reasoning, not the wording. The examiners want answers from your own understanding.

## Your four questions

### 1. Why does DNS use UDP port 53, and when does it fall back to TCP?
- A lookup is one small question and one small answer. UDP needs **no handshake**, so a query
  costs 1 round trip. TCP would need 3 packets of setup first. For millions of tiny lookups,
  that overhead matters, and if a UDP packet is lost the client simply asks again (timeout + retry).
- Port 53 is the well-known port for DNS (both UDP and TCP). The client uses a random high
  (ephemeral) source port, which you can see in the pcap: `52xxx → 53`.
- **TCP fallback:** when an answer is too big for a UDP reply (classically 512 bytes, or the
  EDNS0 size, ~1232 bytes today), the server sets the **TC (truncated) flag**, and the client retries
  over TCP 53. TCP is also used for **zone transfers (AXFR/IXFR)** between servers and for
  DNS-over-TLS (port 853). Demo: `dig +tcp @10.7.8.82 app.cnteam.test` (dnsmasq listens on TCP 53 too).

### 2. A record pointing to the wrong IP vs. a resolver pointing to the wrong DNS server
- **Wrong resolver** = asking the wrong directory. The query goes to a host that isn't a DNS
  server, so there's **no answer at all** (timeout) for *every* name, even google.com. The network
  itself is fine: `ping 10.7.14.242` still works. Fix: client settings.
- **Wrong A record** = the right directory with a wrong entry. Resolution **succeeds** (NOERROR,
  an answer comes back quickly), but it's the wrong address, so the TCP connection is refused or
  reaches the wrong machine. Only that one name is affected. Fix: server config.
- Lesson: DNS and IP connectivity are independent layers, and DNS is a lookup, not a
  connection. Debug them separately: `dig` first, then `nc -vz <ip> 443` / `curl`.

### 3. What does TTL control, and what did you observe?
- TTL (seconds, in every answer) tells **resolvers and clients how long they may cache** the
  answer before asking again. It does not control the server, and it does not expire the record itself.
- Phase 1: dnsmasq gives local records TTL **0**, so nobody caches, and a record change shows up instantly.
- Phase 2 with `local-ttl=30`: after the record changed, `dig @Mac1` showed the **new** IP
  immediately, but the OS cache (`dscacheutil`, which is what browsers use) kept returning the
  **old** IP until ~30 s had passed. Then it switched. Flushing the client cache
  (`dscacheutil -flushcache; killall -HUP mDNSResponder`) made it switch immediately.
- Trade-off: a low TTL means fast changes but more queries and load. A high TTL means fewer queries
  but slow migrations and slow recovery from a bad record.

### 4. How is this analogous to AWS Route 53?
- dnsmasq + `address=` records ≈ a **Route 53 private hosted zone** with A records.
  `server=1.1.1.1` ≈ **Resolver forwarding rules**. The backup on Mac 4 ≈ Route 53 running
  4 name servers per zone across separate networks.
- The TTL/cutover demo is how real migrations work: **lower the TTL days before**, change the
  record (or shift weights with weighted routing), wait one old-TTL period, then decommission.
  Route 53 adds health-check-based **failover routing**, which we do manually.

## Likely follow-ups about DNS
- **Recursive vs authoritative:** Mac 1 is *authoritative-ish* for `cnteam.test` (answers
  from its config) and a *forwarder* for everything else (asks 1.1.1.1). Real recursion
  walks root → TLD → authoritative.
- **Why not `.local`?** macOS sends `.local` to multicast DNS (224.0.0.251:5353), so it never
  reaches our server.
- **Why does nslookup work but the browser doesn't** (or the reverse)? nslookup/dig bypass the OS
  cache and use `/etc/resolv.conf`. The browser uses mDNSResponder, which has its own cache and,
  in Chrome, sometimes secure DNS (DoH). Check `dscacheutil -q host -a name …`.
- **What breaks if Mac 1's IP changes?** dnsmasq can't bind (`bind-interfaces` + fixed
  `listen-address`), and clients point at a dead resolver. In production, DNS servers have static IPs.
- **DNS failure vs application failure:** DNS down means `dig` fails and you never even reach
  nginx. Backends down means `dig` works, TCP+TLS to Mac 2 work, and nginx returns **502**. Different
  layers, different owners, different fixes.
- **Packet fields in your capture:** Ethernet → IPv4 (src client, dst Mac 1) → UDP (src
  ephemeral, dst 53) → DNS (transaction ID, flags QR/RD/RA, Question `app.cnteam.test A IN`,
  Answer `A 10.7.14.242 TTL`). The response's transaction ID matches the query's ID.

## The rest of the system (you'll be quizzed on all of it)
- **Mac 2 (nginx):** a single entry point. It **terminates TLS** (holds the cert and key, decrypts),
  then proxies plain HTTP to backends in an `upstream` block. Default **round-robin**, so responses
  alternate A/B (visible in the `X-Backend` header). `max_fails`/`fail_timeout` take a dead backend
  out of rotation. Self-signed cert with SAN `app.cnteam.test, api.cnteam.test`. The browser warns
  unless the cert is trusted in Keychain.
- **TLS handshake:** ClientHello (with **SNI** = hostname, versions, ciphers) → ServerHello +
  Certificate → key exchange → Finished. Then encrypted application data. The cert must match the
  name the client used, which is why we connect **by name**, not by IP.
- **TCP handshake:** SYN → SYN-ACK → ACK to port 443 (or 8443) before any TLS byte.
- **Mac 3 / Mac 4 backends:** identical simple REST APIs on 3001/3002. They're interchangeable, which
  is what makes load balancing and failover possible. They identify themselves so we can prove
  which one answered.
- **Caching (HTTP layer, not DNS):** `Cache-Control`/`ETag` headers, and `304 Not Modified` on a
  conditional request. Don't confuse this with DNS TTL caching.
- **HA:** both backends up means alternation. One down means nginx routes all traffic to the
  other (no user-visible error). Both down means 502. DNS backup protects the name lookup, not the app.

## Troubleshooting order (for the live challenge, say it out loud)
1. **DNS:** `dig app.cnteam.test`, and `dig @10.7.8.82 app.cnteam.test`. Does it answer, and with Mac 2's IP?
2. **Reachability/TCP:** `ping 10.7.14.242`, `nc -vz 10.7.14.242 8443`. Refused means nothing is listening. Timeout means firewall or routing.
3. **TLS:** `openssl s_client -connect 10.7.14.242:8443 -servername app.cnteam.test`. Check the cert, SAN and expiry.
4. **HTTP/app:** `curl -vk https://app.cnteam.test:8443/api/status`. A 502 means nginx is up but a backend is down, so check `curl http://10.7.18.246:3001/...` directly from Mac 2.
5. **Then logs:** `tail -f /opt/homebrew/var/log/dnsmasq-cnteam.log` (Mac 1), the nginx error.log (Mac 2).

## About your own capture (`evidence/phase1/dns-*.pcap`)
- Query `10.7.8.82.60061 → 10.7.8.82.53  A? app.cnteam.test` → reply `A 10.7.14.242`. The
  transaction ID is the same in both (32217). The `*` in tcpdump means the **AA (authoritative)**
  flag: dnsmasq answers from its own records instead of asking upstream.
- The same lookup also sends an `AAAA?` query, which gets **0 answers** plus an SOA. That's
  `address=` saying "this name exists, but has no IPv6 address".
- **"bad udp cksum" is expected, not an error.** The capture was taken on loopback (lo0), and macOS
  leaves checksums for the network card to fill in (checksum offload). Loopback traffic never reaches a
  card, so tcpdump sees the empty placeholder.
- Mac 1 querying itself goes over lo0, not Wi-Fi. That's why a capture on Mac 4 (en0) shows the
  real network path with two different IPs.
