#!/usr/bin/env bash
# Phase 2, Extension A (contrast): DNS SERVICE failure vs APPLICATION failure, back to back.
# Waits for teammates (polls the real condition; posts requests to ~/board.sh if set up). Run on Mac 1 with resolvers = Mac 1 + Mac 4 (client-dns.sh both).
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
# Each pause waits for the CONDITION itself (no Enter key needed, so it also works unattended):
#   wait_until "<what we asked for>" <check-function>   polls every 2 s, gives up after WAIT_MAX s (default 300)
# If ~/board.sh is set up, each request is also posted to the team board.
tell() { [[ -x "$HOME/board.sh" ]] && "$HOME/board.sh" say all "Ext A contrast (Kartikey): $*" >/dev/null 2>&1; echo ">>> $*"; }
wait_until() { local what="$1" t0=$SECONDS; shift
  until "$@"; do (( SECONDS - t0 > ${WAIT_MAX:-300} )) && { log "!! gave up waiting for: $what"; exit 1; }; sleep 2; done
  log "[$(date +%T)] (observed after $((SECONDS - t0)) s: $what)"; }
mac4_down() { local i; for i in 1 2 3; do [[ -z "$(ask "$MAC4_IP" "$APP")" ]] || return 1; sleep 1; done; }  # 3 misses in a row, not one
mac4_up()   { [[ -n "$(ask "$MAC4_IP" "$APP")" ]]; }
edge_code() { curl -s -o /dev/null -w '%{http_code}' --max-time 5 "https://$APP:$HTTPS_PORT/api/status" || true; }
edge_502()  { [[ "$(edge_code)" == 502 ]]; }
edge_200()  { [[ "$(edge_code)" == 200 ]]; }
trap 'dns_start || true' EXIT
sudo -v
log ""; log "################ run $STAMP on $(hostname -s) ################"

note "PART 1 -- DNS service failure"
log "== PART 1: both DNS servers stopped =="
ev "$f" dns_stop
tell "@anwesha STOP your DNS now: sudo brew services stop dnsmasq (Mac 1 is already stopped)"
wait_until "Mac 4 DNS stopped (no answer)" mac4_down
flush_cache
ev "$f" dig +time=2 +tries=1 @"$MAC1_IP" "$APP"                       # timeout/refused
ev "$f" dig +time=2 +tries=1 @"$MAC4_IP" "$APP"                       # timeout/refused
ev "$f" curl -sS -i --max-time 8 "https://$APP:$HTTPS_PORT/api/status"  # 'Could not resolve host'
ev "$f" ping -c 2 "$MAC2_IP"                                          # IP layer fine
ev "$f" nc -vz -G 3 "$MAC2_IP" "$HTTPS_PORT"                          # TCP to the edge fine
# -k ONLY here: by IP the cert name can't match; this just proves the edge + backends still serve
ev "$f" curl -sS -k -i --max-time 5 "https://$MAC2_IP:$HTTPS_PORT/api/status"
# Verdict is COMPUTED from what actually happened, never just printed.
byname="$(edge_code)"; byip="$(curl -sk -o /dev/null -w '%{http_code}' --max-time 5 "https://$MAC2_IP:$HTTPS_PORT/api/status" || true)"
if [[ "$byname" == 000 && "$byip" == 200 ]]; then
  log "VERDICT 1 (PASS): by name = no response (lookup failed), by IP = 200 -> DNS layer failure, app is healthy."
else
  log "VERDICT 1 (FAIL): by name = $byname, by IP = $byip -> DNS was NOT fully down (is Mac 4 still answering?). Not valid evidence."; exit 1
fi
note "Restoring DNS"
ev "$f" dns_start
tell "@anwesha START your DNS again: sudo brew services start dnsmasq (Mac 1 is back)"
wait_until "Mac 4 DNS answering again" mac4_up
sleep 1; flush_cache
compare_servers "$APP" | tee -a "$ROOT/evidence/$f" || true

note "PART 2 -- application failure"
log "== PART 2: DNS up, both backends stopped =="
tell "@vishuti STOP Backend A (3001) and @anwesha STOP Backend B (3002) now; DNS stays up. I'll call restart."
wait_until "edge returns 502 (both backends down)" edge_502
ev "$f" dig +noall +answer @"$MAC1_IP" "$APP"                        # resolves fine
ev "$f" dscacheutil -q host -a name "$APP"
ev "$f" nc -vz -G 3 "$APP" "$HTTPS_PORT"                              # TCP to the edge fine
ev "$f" curl -sS -v --max-time 8 "https://$APP:$HTTPS_PORT/api/status"  # TLS verify OK, then 502
c="$(edge_code)"; [[ "$c" == 502 ]] \
  && log "VERDICT 2 (PASS): resolves, TCP + TLS OK, nginx returns 502 -> application (backend) layer failure." \
  || log "VERDICT 2 (FAIL): edge returned $c, not 502 -> not valid evidence."
tell "@vishuti START Backend A and @anwesha START Backend B again. Part 2 captured."
wait_until "edge returns 200 again (backends back)" edge_200
ev "$f" curl -sS -i --max-time 5 "https://$APP:$HTTPS_PORT/api/status"
tell "done, everything restored (DNS both up, backends up). Evidence: mac1-kartikey-dns/evidence/phase2/A-dns-vs-app-failure.txt"
echo; echo "Saved -> evidence/$f"
