#!/usr/bin/env bash
# Phase 2, Extension B step 1: prove the TTL dnsmasq puts ON THE WIRE, before vs after.
# Installs the Phase 1 config (TTL 0), records the answer, installs --ttl (TTL 30), records again.
# Leaves TTL 30 enabled. Saves evidence/phase2/B-ttl-onwire-<time>.txt
source "$(dirname "$0")/common.sh"
need MAC1_IP MAC2_IP
check_mac1_ip
f=phase2/B-ttl-onwire-$STAMP.txt
"$ROOT/scripts/install-dns.sh" --no-ttl >/dev/null
note "BEFORE (Phase 1, local-ttl unset = 0): second column is the TTL"
ev "$f" dig @"$MAC1_IP" "$APP" +noall +answer
"$ROOT/scripts/install-dns.sh" --ttl >/dev/null
note "AFTER (Phase 2, local-ttl=30)"
ev "$f" dig @"$MAC1_IP" "$APP" +noall +answer
ev "$f" grep -h '^local-ttl' "$DNSMASQ_D"/ttl.conf
printf '\n%-10s %s\n%-10s %s\n' "TTL 0  :" "clients may NOT cache -> every lookup hits the server, changes visible instantly" \
                                  "TTL 30 :" "clients MAY cache 30 s -> a record change is invisible to them until expiry" | tee -a "$ROOT/evidence/$f"
echo; echo "Saved -> evidence/$f"
