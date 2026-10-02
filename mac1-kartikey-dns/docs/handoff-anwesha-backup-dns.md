# For Anwesha (Mac 4): Backup DNS, Phase 2 Extension A

The project rules say the backup DNS can't run on Mac 1, so it runs on your Mac.

1. Send Kartikey your IP. He puts it in `team.env` → `./scripts/render.sh` and sends you
   `build/dnsmasq-mac4-backup.conf`. It already has the same records as the primary plus your
   `listen-address`.
2. On Mac 4:
   ```bash
   brew install dnsmasq
   grep -q '^conf-dir=/opt/homebrew/etc/dnsmasq.d' /opt/homebrew/etc/dnsmasq.conf \
     || echo 'conf-dir=/opt/homebrew/etc/dnsmasq.d,*.conf' >> /opt/homebrew/etc/dnsmasq.conf
   mkdir -p /opt/homebrew/etc/dnsmasq.d
   cp dnsmasq-mac4-backup.conf /opt/homebrew/etc/dnsmasq.d/cnteam.conf
   dnsmasq --test && sudo brew services start dnsmasq
   dig @10.7.5.197 app.cnteam.test +short     # must equal Mac 2's IP
   dig @10.7.8.82 app.cnteam.test +short     # must be the same answer
   ```
   (On an Intel Mac, replace `/opt/homebrew` with `/usr/local`.)
3. Set your Mac's DNS to **both**: Mac 1 first, then Mac 4. Kartikey's folder has
   `./scripts/client-dns.sh both` for this. Screenshot the setting.
4. During the demo, Kartikey stops Mac 1's dnsmasq. Run
   `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder; dscacheutil -q host -a name app.cnteam.test`
   and `curl -k https://app.cnteam.test:8443/api/status`. Both should keep working.
5. **Rule:** whenever Mac 1's records change (e.g. a new Mac 2 IP), yours must change the same way.
   Two servers giving different answers is a classic real-world outage cause.
