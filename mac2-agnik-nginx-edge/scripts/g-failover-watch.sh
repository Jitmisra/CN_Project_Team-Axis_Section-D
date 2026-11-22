#!/usr/bin/env bash
# Client-side watcher for Ext D (failover) and Ext E (DNS cutover). Runs on ANY teammate's Mac:
# goes through real DNS + the trusted cert (no -k, no --resolve), like a real client.
#   ./scripts/g-failover-watch.sh [seconds=60] [interval=1] [label=D]
#   LOCAL=1 ...  pin the name to Mac 2's IP (still verifies the cert): edge-only check, skips DNS
# Each line: time | IP the OS resolver returns (cached answer) | HTTP status | X-Backend | X-Edge | latency
# Ends with a summary (requests per backend/edge, non-200 count) for the evidence file.
set -uo pipefail
cd "$(dirname "$0")/.."
[ -f team.env ] && source team.env
DOMAIN="${TEAM_DOMAIN:-cnteam.test}"; PORT="${EDGE_HTTPS_PORT:-8443}"
DURATION="${1:-60}"; INTERVAL="${2:-1}"; LABEL="${3:-D}"
HOST="app.$DOMAIN"; URL="https://$HOST:$PORT/api/status"
PIN=(); [ "${LOCAL:-0}" = 1 ] && PIN=(--resolve "$HOST:$PORT:${MAC2_EDGE_IP:?}")

mkdir -p evidence/phase2
OUT="evidence/phase2/${LABEL}-watch-$(hostname -s)-$(date +%Y%m%d-%H%M%S).txt"
{
  echo "# watcher on $(hostname -s) ($(ipconfig getifaddr en0 2>/dev/null)), $URL every ${INTERVAL}s for ${DURATION}s"
  echo "# resolvers: $(scutil --dns | awk '/nameserver\[/{print $3}' | sort -u | tr '\n' ' ')"
  [ "${LOCAL:-0}" = 1 ] && echo "# LOCAL=1: name pinned to $MAC2_EDGE_IP (DNS skipped, cert still verified)"
  printf '%-8s  %-15s  %-4s  %-9s  %-14s  %s\n' TIME OS-DNS HTTP X-BACKEND X-EDGE SECS
} | tee "$OUT"

END=$((SECONDS + DURATION))
while [ $SECONDS -lt $END ]; do
  TS="$(date +%H:%M:%S)"
  IP="$(dscacheutil -q host -a name "$HOST" 2>/dev/null | awk '/ip_address/{print $2; exit}')"
  HDRS="$(curl -s --max-time 4 ${PIN[@]+"${PIN[@]}"} -D - -o /dev/null -w 'CODE=%{http_code} TIME=%{time_total}\n' "$URL" 2>/dev/null)"
  CODE="$(sed -n 's/^CODE=\([0-9]*\).*/\1/p' <<<"$HDRS")"
  SECS="$(sed -n 's/.*TIME=\([0-9.]*\).*/\1/p' <<<"$HDRS")"
  BE="$(awk 'tolower($1)=="x-backend:"{print $2}' <<<"$HDRS" | tr -d '\r')"
  EDGE="$(awk 'tolower($1)=="x-edge:"{print $2}' <<<"$HDRS" | tr -d '\r"')"
  printf '%-8s  %-15s  %-4s  %-9s  %-14s  %s\n' "$TS" "${IP:--}" "${CODE:-000}" "${BE:--}" "${EDGE:--}" "${SECS:--}" | tee -a "$OUT"
  sleep "$INTERVAL"
done

{
  echo "# SUMMARY"
  awk '!/^#/ && NR>1 && $1!="TIME" {n++; code[$3]++; be[$4]++; edge[$5]++}
       END {printf "# requests=%d\n", n
            for (c in code) printf "#   HTTP %s: %d\n", c, code[c]
            for (b in be)   printf "#   X-Backend %s: %d\n", b, be[b]
            for (e in edge) printf "#   X-Edge %s: %d\n", e, edge[e]}' "$OUT"
} | tee -a "$OUT"
echo "Saved to $OUT"
