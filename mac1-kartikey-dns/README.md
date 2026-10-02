# Mac 1 (Kartikey): Private DNS + Test Client, Runbook

All of Kartikey's work for Mac 1 (private DNS + test client). Every step is a script, and each
script writes its own evidence into `evidence/`.

```
team.env                  <- fill teammates' IPs here (only MAC2_IP is needed to go live)
config/                   <- Configuration Bundle: dnsmasq templates (primary, backup, TTL)
build/                    <- rendered configs (made by scripts/render.sh)
scripts/                  <- one script per task / demo (run with ./scripts/<name>.sh)
docs/architecture-dns.md  <- DNS section of the team Architecture Document
docs/viva-prep.md         <- individual viva answers + whole-system notes
docs/handoff-anwesha-backup-dns.md <- what Mac 4 needs for Extension A
evidence/phase1, phase2   <- outputs, pcaps (add screenshots here too)
```

## Status

| Item | Status |
|---|---|
| Mac 1 network identity captured (Task A) | Done: `evidence/phase1/A-netinfo-*.txt` |
| dnsmasq installed | Done: v2.93 (Homebrew, Apple Silicon) |
| Primary config, backup config, TTL config | Written and syntax-checked |
| Team IPs in `team.env` | Done: see `docs/ip-table.md` (edge on 8443) |
| Ping Mac 2/3/4 | Done: all pass with 0% loss |
| Config dry-run with real IPs (port 5300) | Passes: both names resolve to 10.7.14.242 |
| Backends reachable from Mac 1 | A (3001) and B (3002) answer; nginx 8443 is open but returns 502 (upstreams not configured yet) |
| Go live on port 53 | Done 12:24: both names -> 10.7.14.242, via 127.0.0.1 and 10.7.8.82 |
| Mac 1 resolver -> Mac 1 | Done (original 8.8.8.8 saved; `client-dns.sh revert` restores it) |
| End-to-end by name over HTTPS | Done: `https://app.cnteam.test:8443` alternates Backend B / A |
| Failure demo 1 (wrong resolver) | Done: `evidence/phase1/F1-*` |
| Failure demo 2 (wrong record) | Done: `evidence/phase1/F2-*` (record reverted) |
| DNS packet capture | Done: `evidence/phase1/dns-*.pcap` (lo0). Ask Anwesha for a Wi-Fi (en0) capture from Mac 4 too |
| Trust Mac 2's TLS cert | Done: `certs/cnteam.test.crt` (fingerprint matches the live server) trusted in the login keychain. curl works without `-k`: `evidence/phase1/C-tls-trusted-*` |
| Screenshots (resolver settings, Wireshark) | Still to do (manual) |

**Mac 1 row for the shared IP table:**

| Machine | Role | Private IPv4 | Subnet/Prefix | Gateway | Interface | MAC |
|---|---|---|---|---|---|---|
| Mac 1 | DNS | 10.7.8.82 | 255.255.224.0 (/19) | 10.7.0.1 | en0 | ee:03:6e:af:2b:e7 |

> The MAC shown is macOS's *private Wi-Fi address* for this network. That's fine to report. Just
> say so if asked.

### Things found on this Mac
- dnsmasq was **already running** with an older placeholder file `dnsmasq.d/cn.conf`
  (zone `cn.test`, every record pointing at this Mac). `install-dns.sh` moves it aside
  (renamed `cn.conf.disabled-<time>`). It does not delete it.
- Wi-Fi currently has DNS server `8.8.8.8`, and **`8.8.4.4` set as a *search domain***. That
  looks like a typo for a second DNS server. It's harmless, but tidy it in System Settings, because a
  search domain gets appended to short names.
- The LAN is a large /19 (campus-style Wi-Fi with many clients). Networks like this often have
  **client isolation**, which blocks laptop-to-laptop traffic. If `a-ping.sh` fails, have all 4 Macs
  join one phone hotspot, then re-run `a-netinfo.sh` and update `team.env`.

## Run order

Scripts that touch port 53, resolver settings or captures will ask for your sudo password.

### Phase 1
```bash
cd mac1-kartikey-dns
# 0. Get IPs from the team -> edit team.env (MAC2_IP at minimum, ideally all)
./scripts/a-netinfo.sh          # Task A: your row (already done once; re-run if network changes)
./scripts/a-ping.sh             # Task A: ping Mac 2/3/4, saved as evidence
./scripts/selftest.sh           # dry run of the real config on port 5300 (no sudo)
./scripts/install-dns.sh        # Task B: go live on UDP 53 and verify via 127.0.0.1 + LAN IP
./scripts/client-dns.sh primary # Task B.5: this Mac uses Mac 1 (original setting saved)
#    -> screenshot System Settings > Network > Wi-Fi > Details > DNS (before AND after)
#    -> copy this folder to Anwesha's Mac 4 and run ./scripts/client-dns.sh primary there too
./scripts/verify.sh             # Task B.6-7: dig, nslookup, OS lookup, curl BY NAME
./scripts/capture-dns.sh        # DNS pcap + decoded text (best also run on Mac 4)
./scripts/demo-wrong-resolver.sh        # failure demo 1 (auto-reverts)
./scripts/demo-wrong-record.sh          # failure demo 2 (auto-reverts the record)
```

### Phase 2 (after Phase 1 is approved)
```bash
# Ext A: send docs/handoff-anwesha-backup-dns.md + build/dnsmasq-mac4-backup.conf to Anwesha
./scripts/render.sh                     # re-render once MAC4_IP is in team.env
./scripts/client-dns.sh both            # Mac 1 primary + Mac 4 backup (screenshot it)
./scripts/demo-backup-failover.sh       # stops Mac 1's dnsmasq, resolves via Mac 4, restarts

# Ext B: TTL
./scripts/install-dns.sh --ttl          # TTL 0 -> 30 s
./scripts/client-dns.sh primary         # only Mac 1, so the record change is the only variable
./scripts/demo-ttl.sh                   # stale-until-expiry, then flush = instant

# Ext E: edge cutover (when Agnik's standby nginx is up)
./scripts/cutover.sh <STANDBY_IP>       # ...observe TTL effect...
./scripts/cutover.sh back
```

### Cleanup after the demo
```bash
./scripts/client-dns.sh revert          # restore the original DNS servers on each client
sudo brew services stop dnsmasq         # if you don't want it running afterwards
security remove-trusted-cert certs/cnteam.test.crt   # stop trusting Agnik's self-signed CA
security delete-certificate -c app.cnteam.test ~/Library/Keychains/login.keychain-db
```

## Screenshots to take manually (scripts can't take these)
- Resolver config, before and after, on Mac 1 and on one other client (System Settings → Wi-Fi → Details → DNS).
- Wireshark: open `evidence/*/dns-*.pcap` (`brew install --cask wireshark`) with display filter
  `dns`. Highlight the UDP ports (client ephemeral → 53) and the Answer section showing Mac 2's IP.
- A terminal screenshot of each demo next to its saved `.txt`.
- Live query log during demos: `tail -f /opt/homebrew/var/log/dnsmasq-cnteam.log`. It shows which
  client asked what, and what Mac 1 answered.

## Gotchas
- **`dig` bypasses the macOS cache. Browsers and curl don't.** For anything about caching or TTL,
  look at `dscacheutil -q host -a name app.cnteam.test`, not `dig`.
- If Mac 1's IP changes (new DHCP lease), dnsmasq can't bind (`bind-interfaces`). Update
  `MAC1_IP` and re-run `install-dns.sh`. Clients also need the new resolver IP.
- If the team changes `cnteam` to a real team name, change `TEAM=` in `team.env` and re-run
  `install-dns.sh`. Agnik's TLS cert SANs must match the same names.
- If Agnik falls back to port 8443, set `HTTPS_PORT=8443` in `team.env`.
