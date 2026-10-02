#!/usr/bin/env bash
# Phase 2, Extension A: primary DNS (Mac 1) dies, clients keep resolving via backup (Mac 4).
# Run on Mac 1 after Anwesha's backup dnsmasq is up. Restarts Mac 1's dnsmasq on exit.
source "$(dirname "$0")/common.sh"
need MAC1_IP MAC2_IP MAC4_IP
f=phase2/A-backup-failover-$STAMP.txt
trap 'note "Restarting primary"; sudo brew services start dnsmasq >/dev/null; sleep 1; ev "$f" dig +short @"$MAC1_IP" "$APP"' EXIT
note "PRECHECK: both servers give identical answers"
ev "$f" dig +short @"$MAC1_IP" "$APP"
ev "$f" dig +short @"$MAC4_IP" "$APP"
"$ROOT/scripts/client-dns.sh" both | tee -a "$ROOT/evidence/$f"
note "KILL PRIMARY DNS on Mac 1"
ev "$f" sudo brew services stop dnsmasq
ev "$f" dig +time=2 +tries=1 @"$MAC1_IP" "$APP"   # primary is gone
flush_cache
ev "$f" dscacheutil -q host -a name "$APP"         # OS falls over to Mac 4
ev "$f" nslookup "$APP"                            # 'Server:' line shows who answered
ev "$f" curl -sS -k -i --max-time 5 "https://$APP:$HTTPS_PORT/api/status"
echo; echo "Saved -> evidence/$f"
