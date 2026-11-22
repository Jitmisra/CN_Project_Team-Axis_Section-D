# For Anwesha (Mac 4): Backup DNS, Phase 2 Extension A

The project rules say the backup DNS can't run on Mac 1, so it runs on your Mac.

1. Send Kartikey your IP (`ipconfig getifaddr en0`). He puts it in `team.env`, runs `./scripts/render.sh`, and sends you
   `build/dnsmasq-mac4-backup.conf`. It has the same records as the primary, `local-ttl=30`, and
   **interface-based listening** (`interface=en0` + `listen-address=127.0.0.1`, no `bind-interfaces`).
   Because of that, a new DHCP lease no longer stops your dnsmasq, but **clients' resolver lists still
   need your new IP**.
2. On Mac 4:
   ```bash
   brew install dnsmasq
   grep -q '^conf-dir=/opt/homebrew/etc/dnsmasq.d' /opt/homebrew/etc/dnsmasq.conf \
     || echo 'conf-dir=/opt/homebrew/etc/dnsmasq.d,*.conf' >> /opt/homebrew/etc/dnsmasq.conf
   mkdir -p /opt/homebrew/etc/dnsmasq.d
   cp dnsmasq-mac4-backup.conf /opt/homebrew/etc/dnsmasq.d/cnteam.conf
   dnsmasq --test && sudo brew services restart dnsmasq
   dig @<MAC4_IP> app.cnteam.test +short     # must equal Mac 2's IP
   dig @<MAC1_IP> app.cnteam.test +short     # must be the same answer
   ```
   (On an Intel Mac, replace `/opt/homebrew` with `/usr/local`.) Kartikey's `./scripts/sync-check.sh` compares
   both servers for `app` and `api` and exits 1 on any mismatch (including "a server didn't answer").
3. Set your Mac's DNS to **both**: Mac 1 first, then Mac 4 (`./scripts/client-dns.sh both` from Kartikey's folder).
   Screenshot the setting. **Exception, Ext B:** use `client-dns.sh primary` (Mac 1 only) during the TTL demo,
   or your own backup will answer with the unchanged record and hide the TTL effect.
4. During the Ext A demo Kartikey stops Mac 1's dnsmasq. Keep
   `tail -f /opt/homebrew/var/log/dnsmasq-cnteam.log` open and **screenshot your log showing his query
   arriving** (save as `A-mac4-querylog.png`). Then run
   `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder; dscacheutil -q host -a name app.cnteam.test`
   and `curl -i https://app.cnteam.test:8443/api/status` (**no `-k`**: the cert is trusted). Both should keep working.
5. During the Ext A contrast (`demo-dns-vs-app.sh`) he asks you to stop and restart your dnsmasq, and to stop/start Backend B.
6. Ext E: when Kartikey runs `cutover.sh <IP>`, run `dns-backup.sh set-record app.cnteam.test <IP>` at the same moment.
   His script waits until your server gives the same answer and logs the time it did.
7. **Rule:** whenever Mac 1's records change (a new Mac 2 IP, a cutover), yours must change the same way.
   Two servers giving different answers is a classic real-world outage cause.
