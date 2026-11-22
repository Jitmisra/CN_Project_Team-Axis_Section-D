#!/usr/bin/env bash
# Phase 2, Extension A (contrast): DNS SERVICE failure vs APPLICATION failure, back to back.
# Interactive: pauses for teammates. Run on Mac 1 with resolvers = Mac 1 + Mac 4 (client-dns.sh both).
#   Part 1  stop BOTH DNS servers (Mac 1 here, Mac 4 = Anwesha)  -> name resolution fails,
#           but the edge is still reachable by IP  => the network/app are fine, DNS is the broken layer.
#   Part 2  DNS up, BOTH backends stopped (Vishuti + Anwesha)    -> resolves, TCP+TLS OK, 502 from nginx
#           => DNS is fine, the application tier is the broken layer.
# Saves evidence/phase2/A-dns-vs-app-failure.txt (appends if it exists, with a timestamp header).
source "$(dirname "$0")/common.sh"
need MAC1_IP MAC2_IP MAC4_IP
check_mac1_ip
f=phase2/A-dns-vs-app-failure.txt
log() { echo "$*" | tee -a "$ROOT/evidence/$f"; }
wait_for() { echo; read -r -p ">>> $* -- press Enter when done " _; log "[$(date +%T)] (done: $*)"; }
trap 'dns_start || true' EXIT
sudo -v
log ""; log "################ run $STAMP on $(hostname -s) ################"

note "PART 1 -- DNS service failure"
log "== PART 1: both DNS servers stopped =="
ev "$f" dns_stop
wait_for "Anwesha: sudo brew services stop dnsmasq on Mac 4"
flush_cache
ev "$f" dig +time=2 +tries=1 @"$MAC1_IP" "$APP"                       # timeout/refused
ev "$f" dig +time=2 +tries=1 @"$MAC4_IP" "$APP"                       # timeout/refused
ev "$f" curl -sS -i --max-time 8 "https://$APP:$HTTPS_PORT/api/status"  # 'Could not resolve host'
ev "$f" ping -c 2 "$MAC2_IP"                                          # IP layer fine
ev "$f" nc -vz -G 3 "$MAC2_IP" "$HTTPS_PORT"                          # TCP to the edge fine
# -k ONLY here: by IP the cert name can't match; this just proves the edge + backends still serve
ev "$f" curl -sS -k -i --max-time 5 "https://$MAC2_IP:$HTTPS_PORT/api/status"
log "VERDICT 1: lookup fails but the edge answers by IP -> DNS layer failure, app is healthy."
note "Restoring DNS"
ev "$f" dns_start
wait_for "Anwesha: sudo brew services start dnsmasq on Mac 4"
sleep 1; flush_cache
compare_servers "$APP" | tee -a "$ROOT/evidence/$f" || true

note "PART 2 -- application failure"
log "== PART 2: DNS up, both backends stopped =="
wait_for "Vishuti stops Backend A (3001) AND Anwesha stops Backend B (3002)"
ev "$f" dig +noall +answer @"$MAC1_IP" "$APP"                        # resolves fine
ev "$f" dscacheutil -q host -a name "$APP"
ev "$f" nc -vz -G 3 "$APP" "$HTTPS_PORT"                              # TCP to the edge fine
ev "$f" curl -sS -v --max-time 8 "https://$APP:$HTTPS_PORT/api/status"  # TLS verify OK, then 502
log "VERDICT 2: DNS + TCP + TLS succeed, nginx returns 502 -> application (backend) layer failure."
wait_for "Vishuti + Anwesha restart both backends"
ev "$f" curl -sS -i --max-time 5 "https://$APP:$HTTPS_PORT/api/status"
echo; echo "Saved -> evidence/$f"
