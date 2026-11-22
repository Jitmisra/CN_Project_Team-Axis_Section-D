#!/usr/bin/env bash
# Client-side watcher for Ext B / Ext E: time, OS-cache IP (dscacheutil), HTTP status, X-Edge, X-Backend.
#   ./watch-edge.sh [SECONDS=120] [INTERVAL=2] [LABEL=E]   -> evidence/phase2/<LABEL>-watch-<host>-<time>.txt
# No sudo. Works on any client Mac. (Team version: tools/watch.sh by Anwesha -- prefer it once it exists.)
source "$(dirname "$0")/common.sh"
dur="${1:-120}"; iv="${2:-2}"; f="$ROOT/evidence/phase2/${3:-E}-watch-$(hostname -s)-$STAMP.txt"
mkdir -p "$(dirname "$f")"; t0=$SECONDS
echo "# watcher on $(hostname -s), resolvers: $(networksetup -getdnsservers "$NETSVC" | tr '\n' ' ')" | tee "$f"
while (( SECONDS - t0 <= dur )); do
  h="$(curl -sS -o /dev/null -D - -w 'HTTP %{http_code} via %{remote_ip}\n' --connect-timeout 2 --max-time 3 \
        "https://$APP:$HTTPS_PORT/api/status" 2>&1 | tr -d '\r' || true)"
  printf '[%s] t=+%03ds  cache=%-15s  %-28s  X-Edge=%-13s  X-Backend=%s\n' "$(date +%T)" $((SECONDS - t0)) \
    "$(os_lookup "$APP")" "$(grep -m1 -oE '^HTTP [0-9]+ via [0-9.]+|curl: \([0-9]+\).*' <<<"$h" | cut -c1-28)" \
    "$(awk -F': ' 'tolower($1)=="x-edge"{print $2}' <<<"$h")" "$(awk -F': ' 'tolower($1)=="x-backend"{print $2}' <<<"$h")" | tee -a "$f"
  sleep "$iv"
done
echo "Saved -> $f"
