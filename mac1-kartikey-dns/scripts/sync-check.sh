#!/usr/bin/env bash
# Are Mac 1 (primary) and Mac 4 (backup) giving IDENTICAL answers? Run before every demo. No sudo.
#   ./sync-check.sh            exit 0 = in sync, 1 = mismatch
source "$(dirname "$0")/common.sh"
need MAC1_IP MAC4_IP
rc=0
for n in "$APP" "$API"; do compare_servers "$n" || rc=1; done
printf '%-18s Mac1 TTL=%s  Mac4 TTL=%s\n' "TTL" "$(ttl_on_wire "$APP")" \
  "$(ttl_on_wire "$APP" "$MAC4_IP")"
((rc)) && echo "!! MISMATCH: fix it before the demo (Mac 2's IP changed? cutover not mirrored?)" || echo "In sync."
exit $rc
