#!/usr/bin/env bash
# Ext D / Ext E: follow the edge access log (which backend served each request, retries) and the
# nginx error log (passive health-check events) live, saving both to an evidence file.
#   ./scripts/edge-logs.sh [label=D]      Ctrl-C to stop; a per-backend / per-5s summary is appended
# Ext D: look for  upstream=A_IP:3001, B_IP:3002  (retry inside one request) and
#        "connect() failed (61: Connection refused)" / "upstream server temporarily disabled".
# Ext E: watch requests on THIS edge taper off after the DNS cutover (cached clients only, ~TTL).
set -uo pipefail
cd "$(dirname "$0")/.."
LOGDIR="$(brew --prefix)/var/log/nginx"
LABEL="${1:-D}"; mkdir -p evidence/phase2
OUT="evidence/phase2/${LABEL}-edge-logs-$(date +%Y%m%d-%H%M%S).txt"
echo "# edge logs on $(hostname -s) from $(date)  (Ctrl-C to stop)" | tee "$OUT"
summary() {
  echo "# SUMMARY (requests per upstream used, then per 5-second bucket)" | tee -a "$OUT"
  grep -o 'upstream=[^ ]*\( [0-9.:]*\)\{0,1\}' "$OUT" | sort | uniq -c | sed 's/^/#  /' | tee -a "$OUT"
  grep -E '^ACCESS ' "$OUT" | awk '{split($2,t,"T"); s=substr(t[2],1,8); split(s,h,":"); b=h[1]":"h[2]":"sprintf("%02d",int(h[3]/5)*5); c[b]++}
       END{for (k in c) print "#   " k "  " c[k] " req"}' | sort | tee -a "$OUT"
  echo "Saved to $OUT"; exit 0
}
trap summary INT TERM
tail -n0 -F "$LOGDIR/edge-access.log" 2>/dev/null | sed -u 's/^/ACCESS /' | tee -a "$OUT" &
tail -n0 -F "$LOGDIR/error.log" 2>/dev/null | grep --line-buffered -E "upstream|connect\(\) failed|disabled|timed out" \
  | sed -u 's/^/ERROR  /' | tee -a "$OUT" &
wait
