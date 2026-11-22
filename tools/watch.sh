#!/usr/bin/env bash
# tools/watch.sh — Client-side watcher for failover/cutover demos
# Usage: ./tools/watch.sh [duration_secs] [interval_secs] [output_file]
set -euo pipefail
cd "$(dirname "$0")"
source team.env

DURATION="${1:-60}"
INTERVAL="${2:-2}"
OUT="${3:-watch-$(date +%Y%m%d-%H%M%S).txt}"

URL="https://${DOMAIN}:${HTTPS_PORT}/api/status"

echo "Watching $URL every ${INTERVAL}s for ${DURATION}s" | tee "$OUT"
echo "Stop/start backends or change DNS in another terminal." | tee -a "$OUT"
echo "---" | tee -a "$OUT"

END=$((SECONDS + DURATION))
while [ $SECONDS -lt $END ]; do
    TS=$(date +%H:%M:%S)

    # Check DNS cache
    DNS_IP=$(dscacheutil -q host -a name ${DOMAIN} 2>/dev/null \
        | grep 'ip_address' | awk '{print $2}' | head -1)
    [ -z "$DNS_IP" ] && DNS_IP="(uncached)"

    # HTTP request
    RESP=$(curl -sI --max-time 3 "https://${DOMAIN}:${HTTPS_PORT}/api/status" 2>/dev/null || echo "")
    STATUS=$(echo "$RESP" | head -1 | awk '{print $2}' | tr -d '\r')
    BACKEND=$(echo "$RESP" | grep -i 'x-backend' | awk '{print $2}' | tr -d '\r')
    EDGE=$(echo "$RESP" | grep -i 'x-edge' | awk '{print $2}' | tr -d '\r')

    [ -z "$STATUS" ] && STATUS="ERR"
    [ -z "$BACKEND" ] && BACKEND="-"
    [ -z "$EDGE" ] && EDGE="-"

    LINE="$TS  dns=$DNS_IP  http=$STATUS  backend=$BACKEND  edge=$EDGE"
    echo "$LINE" | tee -a "$OUT"

    sleep "$INTERVAL"
done

echo "---" | tee -a "$OUT"
echo "Done. Saved to $OUT" | tee -a "$OUT"
