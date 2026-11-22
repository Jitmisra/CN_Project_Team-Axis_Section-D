#!/usr/bin/env bash
# Ext D (HA failover) in ONE command on Mac 2: records the client-side watcher AND the edge logs.
#   ./scripts/d-demo.sh [seconds=75]
# Cue Vishuti:  ~15 s in -> ./scripts/stop-backend.sh   (watch: only X-Backend B, zero errors)
#               ~40 s in -> ./scripts/start-backend.sh  (watch: A/B alternate again after ~10-15 s)
set -uo pipefail
cd "$(dirname "$0")/.."
source team.env
DUR="${1:-75}"
# Use real DNS if this Mac already resolves the name to Mac 2, else pin the name (cert still verified).
if [ "$(dscacheutil -q host -a name "app.$TEAM_DOMAIN" | awk '/ip_address/{print $2; exit}')" = "$MAC2_EDGE_IP" ]; then
  MODE=""; echo "Using real DNS."
else
  MODE="LOCAL=1"; echo "This Mac's DNS doesn't resolve app.$TEAM_DOMAIN yet: pinning the name to $MAC2_EDGE_IP (cert still verified)."
fi
./scripts/edge-logs.sh D >/dev/null 2>&1 &
LOGPID=$!
sleep 1
echo ">>> NOW tell Vishuti: stop Backend A at ~15 s, start it again at ~40 s <<<"
env $MODE ./scripts/g-failover-watch.sh "$DUR" 1 D
kill -TERM "$LOGPID" 2>/dev/null; sleep 1
echo "Edge log saved: $(ls -t evidence/phase2/D-edge-logs-*.txt | head -1)"
{ grep -c 'upstream=[^ ]*, ' "$(ls -t evidence/phase2/D-edge-logs-*.txt | head -1)" || true; } | xargs -I{} echo "requests that failed over inside one request (retry A->B): {}"
