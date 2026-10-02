# Architecture Document: DNS Layer (Mac 1, Kartikey)

## 1. Role
Mac 1 runs **dnsmasq** as the team's private DNS server. It is the **Route 53 equivalent**:
it hosts the project zone (`*.cnteam.test`) and forwards every other name upstream.
Mac 1 also acts as a **test client** to prove the whole chain end to end.

DNS has a single job here: **turn a name into Mac 2's IP**. It never carries application
traffic. After the answer comes back, the client opens a separate TCP/TLS connection to Mac 2.

## 2. Record table

| Name | Type | Value | TTL, Phase 1 | TTL, Phase 2 | Served by |
|---|---|---|---|---|---|
| `app.cnteam.test` | A | Mac 2 IP (`10.7.14.242`) | 0 s | 30 s | Mac 1 (primary), Mac 4 (backup) |
| `api.cnteam.test` | A | Mac 2 IP (`10.7.14.242`) | 0 s | 30 s | Mac 1 (primary), Mac 4 (backup) |
| everything else | — | forwarded to `1.1.1.1` | upstream TTL | upstream TTL | Mac 1, Mac 4 |

- Both names point at the **edge (Mac 2)**, never at the backends. Backend IPs (Mac 3,
  Mac 4) are not published in DNS, so clients can't bypass the load balancer.
- `.test` is reserved for testing (RFC 6761), so it never collides with real domains.
  `.local` is avoided because macOS sends `.local` to mDNS/Bonjour, not to our server.
- `address=/app.cnteam.test/IP` also matches sub-names (e.g. `x.app.cnteam.test`) and returns
  NOERROR with no data for AAAA queries, so clients use IPv4 cleanly.
- A TTL of 0 is dnsmasq's default for locally configured records ("don't cache"). Phase 2 sets
  `local-ttl=30` so caching becomes visible (Extension B).

## 3. Server configuration (Configuration Bundle)
File: `/opt/homebrew/etc/dnsmasq.d/cnteam.conf`. The main `dnsmasq.conf` only includes that directory.

```conf
address=/app.cnteam.test/10.7.14.242
address=/api.cnteam.test/10.7.14.242
listen-address=127.0.0.1,10.7.8.82   # loopback (Mac 1 as client) + LAN (teammates)
bind-interfaces                      # bind only those addresses, not 0.0.0.0
no-resolv                            # don't read /etc/resolv.conf ...
server=1.1.1.1                       # ... forward non-project names here instead
no-hosts                             # don't serve this laptop's /etc/hosts to the team
log-queries                          # per-query log = live evidence
log-facility=/opt/homebrew/var/log/dnsmasq-cnteam.log
# Phase 2 (ttl.conf): local-ttl=30
```

Why `no-resolv` matters: once Mac 1 uses itself as its resolver, `/etc/resolv.conf`
points back at Mac 1. Without `no-resolv`, dnsmasq would forward unknown names to itself in a loop.

The service runs as root through `sudo brew services start dnsmasq`, because port 53 is below 1024
(a privileged port). Listening sockets are UDP 53 and TCP 53 on 127.0.0.1 and `10.7.8.82`.

The backup (Phase 2) is on **Mac 4** with identical `address=` records and its own
`listen-address`. See `config/dnsmasq-mac4-backup.conf.tmpl`.

## 4. Client resolver setup

| Phase | Client DNS servers (System Settings → Network → Wi-Fi → Details → DNS) |
|---|---|
| Original (Mac 1) | `8.8.8.8` (saved by `client-dns.sh`, restored by `client-dns.sh revert`) |
| Phase 1 | `10.7.8.82` |
| Phase 2 | `10.7.8.82` (primary), `10.7.5.197` (backup) |

macOS's resolver (mDNSResponder) caches answers for their TTL. Browsers, curl and ping all go
through it. `dig` and `nslookup` query the server directly and **bypass that cache**. This
difference is the key to reading the TTL demo correctly. With two servers listed, macOS prefers the
first and moves to the second when the first stops answering (after a short timeout). It is not strict
round-robin.

## 5. Request flow at the DNS layer

```
 Client (Mac 1 / Mac 4)                Mac 1 dnsmasq              Mac 2 nginx
 ──────────────────────                ─────────────              ───────────
 1. UDP  <ephemeral> → 10.7.8.82:53    "A? app.cnteam.test"
 2.                  ← 10.7.8.82:53    "A 10.7.14.242, TTL 0|30"
 3. TCP SYN  <ephemeral> → 10.7.14.242:8443───────────────────────────►  (DNS is no longer involved)
 4. TLS ClientHello (SNI app.cnteam.test) → HTTP GET → proxied to Mac 3:3001 / Mac 4:3002
```

Steps 1–2 are the only part this machine owns. If they fail, nothing after them starts.
If they succeed with a wrong value, everything after them goes to the wrong place.

## 6. DNS failure modes (demonstrated)

| Scenario | Name resolution | Raw-IP connectivity | What the user sees | Script |
|---|---|---|---|---|
| Client uses a wrong DNS server | **fails** (timeout) for every name | works | "server not found" | `demo-wrong-resolver.sh` |
| A record holds a wrong IP | **succeeds** (NOERROR) with the wrong IP | — | connection refused / wrong site | `demo-wrong-record.sh` |
| Primary DNS down, backup up | succeeds via Mac 4 | works | nothing (short delay) | `demo-backup-failover.sh` |
| DNS fine, both backends down | succeeds | TCP+TLS to Mac 2 work | `502 Bad Gateway` from nginx | (Agnik/Vishuti/Anwesha) |
| Record changed, TTL 30 | old cached IP until expiry | — | old edge for up to 30 s, or flush the cache | `demo-ttl.sh`, `cutover.sh` |

## 7. Cloud analogy

| This project | AWS |
|---|---|
| dnsmasq on Mac 1 with `address=` records | Route 53 private hosted zone + A records |
| `server=1.1.1.1` forwarding | Route 53 Resolver forwarding rules |
| Backup dnsmasq on Mac 4 | Route 53's multiple anycast name servers (4 NS per zone) |
| `local-ttl=30` + record change | Lower TTL before a migration, then change the record (blue/green or weighted cutover) |
| Clients pointed at Mac 1/Mac 4 | VPC DHCP options set / AmazonProvidedDNS |
