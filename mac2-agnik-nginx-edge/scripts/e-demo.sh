#!/usr/bin/env bash
# Ext E (DNS cutover) on Mac 2: records requests reaching the PRIMARY edge for N seconds.
# After Kartikey's cutover, requests here should taper to zero within ~TTL (30 s) as client
# caches expire and they move to the standby on Mac 3. Per-5-second counts land in the summary.
#   ./scripts/e-demo.sh [seconds=360]
set -uo pipefail
cd "$(dirname "$0")/.."
DUR="${1:-360}"
./scripts/edge-logs.sh E >/dev/null 2>&1 &
PID=$!
echo "Recording primary-edge traffic for ${DUR}s (started $(date +%T))."
sleep "$DUR"
kill -TERM "$PID" 2>/dev/null; sleep 1
F="$(ls -t evidence/phase2/E-edge-logs-*.txt | head -1)"
echo "Saved: $F"
grep '^#' "$F" | tail -40
