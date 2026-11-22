#!/usr/bin/env bash
# Phase 2, Extension A: primary DNS (Mac 1) dies, clients keep resolving via backup (Mac 4).
# Run on Mac 1 after Anwesha's backup dnsmasq is up. Restarts Mac 1's dnsmasq on exit.
#   ./demo-backup-failover.sh            (captures port 53 + ICMP into evidence/phase2/A-failover-*.pcap)
#   NO_PCAP=1 ./demo-backup-failover.sh  (skip the capture)
# Ask Anwesha to run   tail -f /opt/homebrew/var/log/dnsmasq-cnteam.log   on Mac 4 during this
# and screenshot it: her log showing our query is the proof the BACKUP answered.
source "$(dirname "$0")/common.sh"
need MAC1_IP MAC2_IP MAC4_IP
check_mac1_ip
f=phase2/A-backup-failover-$STAMP.txt
pcap="$ROOT/evidence/phase2/A-failover-$STAMP"
caps=()
cleanup() {
  note "Restarting primary"
  dns_start; sleep 1
  ev "$f" dig +short @"$MAC1_IP" "$APP"
  if ((${#caps[@]})); then
    kill "${caps[@]}" 2>/dev/null; wait "${caps[@]}" 2>/dev/null || true
    for i in lo0 en0; do tcpdump -nn -r "$pcap-$i.pcap" 2>/dev/null > "$pcap-$i.txt" || true; done
    echo "Captures: $pcap-lo0.pcap (Mac 1 asking itself -> ICMP port unreachable)"
    echo "          $pcap-en0.pcap (queries + answers from Mac 4 over Wi-Fi)"
  fi
}
trap cleanup EXIT
sudo -v

note "PRECHECK: both servers give identical answers"
compare_servers "$APP" | tee -a "$ROOT/evidence/$f" || { echo "!! fix the mismatch first (Anwesha: dns-backup.sh sync-check)"; exit 1; }
compare_servers "$API" | tee -a "$ROOT/evidence/$f" || exit 1
"$ROOT/scripts/client-dns.sh" both | tee -a "$ROOT/evidence/$f"

if [[ -z "${NO_PCAP:-}" ]]; then
  # Mac 1 querying its own IP goes over lo0; queries to Mac 4 go over en0. Capture both.
  for i in lo0 en0; do
    tcpdump -i "$i" -U -w "$pcap-$i.pcap" "port 53 or icmp" 2>/dev/null & caps+=($!)
  done
  sleep 1
fi

note "KILL PRIMARY DNS on Mac 1"
ev "$f" dns_stop
ev "$f" dig +time=2 +tries=1 @"$MAC1_IP" "$APP"    # primary is gone: timeout / refused
ev "$f" dig +time=2 +tries=1 @"$MAC4_IP" "$APP"    # backup still answers
flush_cache
ev "$f" scutil --dns                               # client still lists both resolvers
ev "$f" dscacheutil -q host -a name "$APP"         # OS falls over to Mac 4
ev "$f" nslookup "$APP"                            # 'Server:' line shows who answered
# End to end by name: DNS (via backup) -> TCP -> TLS (trusted cert, NO -k) -> HTTP -> backend
for i in 1 2 3; do ev "$f" curl -sS -i --max-time 5 "https://$APP:$HTTPS_PORT/api/status"; done
note "Now: Anwesha screenshots her dnsmasq query log showing 'query[A] $APP from $MAC1_IP' -> evidence/phase2/A-mac4-querylog.png"
echo; echo "Saved -> evidence/$f"
