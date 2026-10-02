#!/usr/bin/env bash
# Phase 2, Extension B: TTL + controlled record change, observed from a client cache.
# Run on Mac 1 (its resolver must include Mac 1). Requires: ./install-dns.sh --ttl
#   ./demo-ttl.sh [ALT_IP]   (default Mac 4)
# dig asks the server directly (always the newest answer); dscacheutil asks the OS
# resolver, which caches -- that's what browsers/curl see, so that's what we watch.
source "$(dirname "$0")/common.sh"
need MAC1_IP MAC2_IP
alt="${1:-${MAC4_IP:-192.0.2.77}}"
ttl="$(grep -hs '^local-ttl=' "$DNSMASQ_D"/*.conf | cut -d= -f2)"
[[ -n "$ttl" && "$ttl" != 0 ]] || { echo "!! TTL is 0 -- run ./install-dns.sh --ttl first"; exit 1; }
scutil --dns | awk '/resolver #1/{f=1} /resolver #2/{exit} f' | grep -qE "nameserver.*($MAC1_IP|127\.0\.0\.1)\b" \
  || { echo "!! This Mac's resolver is not Mac 1 -- run ./client-dns.sh primary first"; exit 1; }
f=phase2/B-ttl-$STAMP.txt
trap 'set_record "$APP" "$MAC2_IP"' EXIT
watch_both() { local t0=$SECONDS
  while (( SECONDS - t0 <= $1 )); do
    printf '[%s] t=+%02ds  OS cache: %-15s  server (dig): %s\n' "$(date +%T)" $((SECONDS - t0)) \
      "$(os_lookup "$APP")" "$(dig +short @"$MAC1_IP" "$APP")" | tee -a "$ROOT/evidence/$f"
    sleep 5; done; }

note "PART 1 -- wait out the TTL ($ttl s)"
set_record "$APP" "$MAC2_IP"; flush_cache
ev "$f" dig @"$MAC1_IP" "$APP" +noall +answer      # second column = TTL
ev "$f" dscacheutil -q host -a name "$APP"          # client now caches Mac 2 for ${ttl}s
note "CHANGE RECORD: $APP -> $alt"; set_record "$APP" "$alt"
watch_both $((ttl + 10))                            # old answer until expiry, then new

note "PART 2 -- same change, but flush the client cache instead of waiting"
set_record "$APP" "$MAC2_IP"
watch_both 0                                        # still the stale $alt from cache
ev "$f" sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
watch_both 0                                        # immediately Mac 2 again
echo; echo "Saved -> evidence/$f"
