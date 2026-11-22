#!/usr/bin/env bash
# Phase 2, Extension B: TTL + controlled record change, observed from a client cache.
# Run on Mac 1 (its resolver must be Mac 1 ONLY). Requires: ./install-dns.sh --ttl
#   ./demo-ttl.sh [ALT_IP|standby]   default Mac 4; 'standby' = Mac 3's standby edge (best demo:
#                                    the X-Edge column flips mac2-primary -> mac3-standby)
# dig asks the server directly (always the newest answer); dscacheutil asks the OS
# resolver, which caches -- that's what browsers/curl see, so that's what we watch.
# Each curl is a NEW process = new TCP connection, so it re-resolves every time (no keep-alive).
source "$(dirname "$0")/common.sh"
need MAC1_IP MAC2_IP
check_mac1_ip
alt="${1:-${MAC4_IP:-192.0.2.77}}"; [[ "$alt" == standby ]] && { need MAC3_IP; alt="$MAC3_IP"; }
ttl="$(grep -hs '^local-ttl=' "$DNSMASQ_D"/*.conf | cut -d= -f2)"
[[ -n "$ttl" && "$ttl" != 0 ]] || { echo "!! TTL is 0 -- run ./install-dns.sh --ttl first"; exit 1; }
scutil --dns | awk '/resolver #1/{f=1} /resolver #2/{exit} f' | grep -qE "nameserver.*($MAC1_IP|127\.0\.0\.1)\b" \
  || { echo "!! This Mac's resolver is not Mac 1 -- run ./client-dns.sh primary first"; exit 1; }
scutil --dns | awk '/resolver #1/{f=1} /resolver #2/{exit} f' | grep -q "$MAC4_IP" \
  && { echo "!! Mac 4 is still in the resolver list -- its unchanged record would mask the TTL. ./client-dns.sh primary"; exit 1; }
f=phase2/B-ttl-$STAMP.txt
trap 'set_record "$APP" "$MAC2_IP"; echo "Record restored: $APP -> $MAC2_IP"' EXIT
sudo -v

edge() { # which edge answered (X-Edge header), or why nothing did
  local h; h="$(curl -sS -o /dev/null -D - --connect-timeout 2 --max-time 3 "https://$APP:$HTTPS_PORT/api/status" 2>&1 || true)"
  grep -i '^x-edge:' <<<"$h" | tr -d '\r' | awk '{print $2}' | grep . || { grep -o 'Failed to connect\|timed out\|Could not resolve' <<<"$h" | head -1 || echo '-'; }
}
watch_both() { local t0=$SECONDS
  while :; do
    printf '[%s] t=+%02ds  OS cache: %-15s  server (dig): %-15s  X-Edge: %s\n' "$(date +%T)" $((SECONDS - t0)) \
      "$(os_lookup "$APP")" "$(ask "$MAC1_IP" "$APP")" "$(edge)" | tee -a "$ROOT/evidence/$f"
    (( SECONDS - t0 >= $1 )) && break; sleep 3; done; }
mark() { echo "---- [$(date +%T)] $*" | tee -a "$ROOT/evidence/$f"; }

note "PART 1 -- change the record and WAIT out the TTL ($ttl s)"
set_record "$APP" "$MAC2_IP"; flush_cache
ev "$f" dig @"$MAC1_IP" "$APP" +noall +answer      # second column = TTL
ev "$f" dscacheutil -q host -a name "$APP"          # client now caches Mac 2 for ${ttl}s
watch_both 0
mark "CHANGE RECORD on the server: $APP -> $alt"; set_record "$APP" "$alt"
watch_both $((ttl + 10))                            # old answer until expiry, then new

note "PART 2 -- same change back, but FLUSH the client cache instead of waiting"
mark "CHANGE RECORD on the server: $APP -> $MAC2_IP"; set_record "$APP" "$MAC2_IP"
watch_both 0                                        # still the stale $alt from cache
mark "MANUAL FLUSH: dscacheutil -flushcache; killall -HUP mDNSResponder"; flush_cache
watch_both 0                                        # immediately Mac 2 again
echo; echo "Saved -> evidence/$f"
