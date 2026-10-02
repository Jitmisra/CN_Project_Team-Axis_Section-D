#!/usr/bin/env bash
# Verify edge is up, TLS works, and load balancing alternates backends.
set -euo pipefail
cd "$(dirname "$0")/.."
source team.env
mkdir -p evidence
OUT="evidence/verify.txt"
: > "$OUT"

HOST="app.${TEAM_DOMAIN}"
URL="https://${HOST}:${EDGE_HTTPS_PORT}/api/status"

echo "Resolving via dig/nslookup (requires client DNS pointed at Mac 1 or /etc/hosts override):" | tee -a "$OUT"
dig +short "$HOST" | tee -a "$OUT" || true

echo | tee -a "$OUT"
echo "=== curl -v (TLS handshake + headers) - local sanity check, -k because the" \
     "self-signed cert isn't trusted on THIS Mac's keychain yet ===" | tee -a "$OUT"
curl -v -k --resolve "${HOST}:${EDGE_HTTPS_PORT}:${MAC2_EDGE_IP}" "$URL" 2>&1 | tee -a "$OUT" || true

echo | tee -a "$OUT"
echo "=== Load balancing: 10 requests, X-Backend header ===" | tee -a "$OUT"
for i in $(seq 1 10); do
  curl -s -k --resolve "${HOST}:${EDGE_HTTPS_PORT}:${MAC2_EDGE_IP}" -D - "$URL" -o /dev/null \
    | grep -i x-backend | tee -a "$OUT"
done

echo | tee -a "$OUT"
echo "=== Cache-Control header check ===" | tee -a "$OUT"
curl -sI -k --resolve "${HOST}:${EDGE_HTTPS_PORT}:${MAC2_EDGE_IP}" "$URL" | tee -a "$OUT"

echo
echo "Saved to $OUT"
echo "NOTE: this script uses --resolve + -k as a LOCAL sanity check before the cert is"
echo "trusted on client machines. The final demo must use real DNS resolution and no -k."
