#!/usr/bin/env bash
# Verify the edge the way a real client sees it: real DNS, trusted cert (no -k).
#   ./scripts/verify.sh            full client path (needs this Mac's DNS -> Mac 1/Mac 4)
#   LOCAL=1 ./scripts/verify.sh    pin the name to Mac 2's IP (skips DNS, still verifies the cert)
set -uo pipefail
cd "$(dirname "$0")/.."
source team.env
mkdir -p evidence/phase2
OUT="evidence/phase2/verify-$(date +%Y%m%d-%H%M%S).txt"
HOST="app.${TEAM_DOMAIN}"; PORT="$EDGE_HTTPS_PORT"; BASE="https://${HOST}:${PORT}"
PIN=(); [ "${LOCAL:-0}" = 1 ] && PIN=(--resolve "${HOST}:${PORT}:${MAC2_EDGE_IP}")
c() { curl ${PIN[@]+"${PIN[@]}"} "$@"; }
say() { echo; echo "=== $* ===" | tee -a "$OUT"; }
: > "$OUT"

say "DNS: dig (server answer) vs dscacheutil (what curl/browsers use)"
dig +noall +answer +stats "$HOST" 2>&1 | grep -E "IN|SERVER" | tee -a "$OUT"
dscacheutil -q host -a name "$HOST" | tee -a "$OUT"

say "TLS + headers: curl -v (must say 'SSL certificate verify ok', no -k)"
c -sv "$BASE/api/status" -o /dev/null 2>&1 | grep -E "Connected to|SSL connection|ALPN|subject:|issuer:|SSL certificate verify|^< |^> GET" | tee -a "$OUT"

say "HTTP/2 negotiated via ALPN"
c -sI --http2 "$BASE/" | head -1 | tee -a "$OUT"

say "Load balancing: 10 requests"
for i in $(seq 1 10); do
  c -s -D - -o /dev/null "$BASE/api/status" | awk 'tolower($1)=="x-backend:"||tolower($1)=="x-edge:"{printf "%s %s  ", $1, $2} END{print ""}' | tr -d '\r' | tee -a "$OUT"
done

say "Caching: Cache-Control / ETag on /api/info, then conditional request"
H="$(c -sI "$BASE/api/info")"; echo "$H" | tr -d '\r' | tee -a "$OUT"
ETAG="$(echo "$H" | awk 'tolower($1)=="etag:"{print $2}' | tr -d '\r')"
if [ -n "$ETAG" ]; then
  for i in 1 2 3 4; do c -sI -H "If-None-Match: $ETAG" "$BASE/api/info" | head -1 | tr -d '\r' | tee -a "$OUT"; done
else
  echo "(no ETag yet: backends still need the /api/info + ETag update from Vishuti/Anwesha)" | tee -a "$OUT"
fi
echo; echo "Saved to $OUT"
