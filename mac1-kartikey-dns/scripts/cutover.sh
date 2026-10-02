#!/usr/bin/env bash
# Phase 2, Extension E: DNS-based edge migration (Agnik's standby nginx on Mac 3/4).
#   ./cutover.sh STANDBY_IP   point app.<team>.test at the standby edge
#   ./cutover.sh back         point it back at Mac 2
# With TTL 30 (./install-dns.sh --ttl), clients that cached the old answer keep hitting
# the old edge for up to 30s; fresh lookups go to the standby. Watch it with:
#   while true; do date +%T; dscacheutil -q host -a name app.cnteam.test | grep ip_; sleep 3; done
source "$(dirname "$0")/common.sh"
need MAC2_IP
target="${1:?usage: cutover.sh STANDBY_IP | back}"; [[ "$target" == back ]] && target="$MAC2_IP"
f=phase2/E-cutover-$STAMP.txt
ev "$f" dig +noall +answer @"$MAC1_IP" "$APP"
set_record "$APP" "$target"
ev "$f" grep "^address=" "$LIVE_CONF"
ev "$f" dig +noall +answer @"$MAC1_IP" "$APP"
echo; echo "Cut over $APP -> $target at $(date +%T). Note the time for the TTL story."
