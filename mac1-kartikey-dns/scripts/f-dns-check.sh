#!/usr/bin/env bash
# Phase 2, Extension F: DNS-layer checklist for a faculty-injected fault. No sudo. Read top to bottom, out loud.
#   ./f-dns-check.sh [NAME]   default app.<team>.test   -> evidence/phase2/F-dns-check-<time>.txt
source "$(dirname "$0")/common.sh"
n="${1:-$APP}"; f=phase2/F-dns-check-$STAMP.txt
note "1. Is dnsmasq running on Mac 1, and is the config valid?"
ev "$f" pgrep -lf dnsmasq
ev "$f" dnsmasq --test -C /opt/homebrew/etc/dnsmasq.conf -7 "$DNSMASQ_D,*.conf"
ev "$f" grep -h -E '^(address|listen-address|interface|bind-interfaces|local-ttl|server)=?' "$DNSMASQ_D"/*.conf
note "2. Does the IP in team.env still match en0? (DHCP drift)"
ev "$f" ipconfig getifaddr "$IFACE"; echo "   team.env MAC1_IP=$MAC1_IP"
note "3. Ask each server directly (status, ANSWER, SERVER:). Expected: NOERROR, $n -> $MAC2_IP"
ev "$f" dig +time=2 +tries=1 @"$MAC1_IP" "$n"
ev "$f" dig +time=2 +tries=1 +short @"$MAC4_IP" "$n"
compare_servers "$n" | tee -a "$ROOT/evidence/$f" || true
note "4. What is THIS client actually using? (scutil = truth; System Settings can lie)"
ev "$f" scutil --dns
note "5. /etc/hosts override? dig skips it, curl/browser do NOT -> they disagree"
ev "$f" grep -n -v -E '^\s*(#|$)' /etc/hosts
printf 'dig: %s   OS (dscacheutil): %s\n' "$(dig +short +time=2 +tries=1 "$n" | grep -E '^[0-9.]+$' | tail -1 || true)" "$(os_lookup "$n")" | tee -a "$ROOT/evidence/$f"
note "6. Did the client's query even reach Mac 1? (last log lines)"
ev "$f" tail -n 15 /opt/homebrew/var/log/dnsmasq-cnteam.log
cat <<TXT | tee -a "$ROOT/evidence/$f"

How to read it:
  no dnsmasq / dig timeout on both   -> DNS SERVICE down            (fix: dns_start)
  NXDOMAIN from Mac 1                -> record deleted or name typo  (query went upstream to $UPSTREAM_DNS)
  NOERROR but wrong IP               -> wrong A record               (fix in $LIVE_CONF, restart)
  Mac 1 != Mac 4                     -> servers out of sync, clients flip randomly (sync-check.sh)
  scutil shows 8.8.8.8 etc.          -> client resolver misconfigured (client-dns.sh both)
  dig != dscacheutil                 -> /etc/hosts override or stale OS cache (flush)
  en0 IP != team.env                 -> DHCP drift; listen config / clients point at the old IP
  all OK                             -> DNS is NOT the broken layer: move on to ping -> nc -vz -> TLS -> HTTP
TXT
