#!/usr/bin/env bash
# Run this WHILE a teammate stops/restarts a backend, to capture before/during/after
# evidence for the "one backend down" and "both backends down" demos.
# Usage: ./scripts/g-failover-watch.sh [seconds] [interval]
set -euo pipefail
cd "$(dirname "$0")/.."
source team.env
mkdir -p evidence

DURATION="${1:-30}"
INTERVAL="${2:-1}"
HOST="app.${TEAM_DOMAIN}"
URL="https://${HOST}:${EDGE_HTTPS_PORT}/api/status"
OUT="evidence/failover-watch-$(date +%Y%m%d-%H%M%S).txt"

echo "Watching $URL every ${INTERVAL}s for ${DURATION}s. Stop/restart backends on" \
     "Mac 3 / Mac 4 now in a separate terminal." | tee "$OUT"

END=$((SECONDS + DURATION))
while [ $SECONDS -lt $END ]; do
  TS="$(date +%H:%M:%S)"
  RESP="$(curl -s -k --max-time 2 --resolve "${HOST}:${EDGE_HTTPS_PORT}:${MAC2_EDGE_IP}" \
          -D - "$URL" -o /tmp/body.$$ 2>&1 || true)"
  STATUS="$(echo "$RESP" | head -1 | tr -d '\r')"
  BACKEND="$(echo "$RESP" | grep -i x-backend | tr -d '\r' || echo 'x-backend: (none - likely 502)')"
  echo "$TS  $STATUS  $BACKEND" | tee -a "$OUT"
  rm -f /tmp/body.$$
  sleep "$INTERVAL"
done

echo "Saved to $OUT"
