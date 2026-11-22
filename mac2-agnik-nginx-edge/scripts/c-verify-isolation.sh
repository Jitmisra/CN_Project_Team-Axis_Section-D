#!/usr/bin/env bash
# Ext C (verify from the edge): AFTER Vishuti (3001) and Anwesha (3002) enable pf, Mac 2 must still
# reach both backends directly AND the load balancer must still alternate A/B through the domain.
# Pair this file with Kartikey's C-client-blocked.txt (same checks from Mac 1 fail).
set -uo pipefail
cd "$(dirname "$0")/.."
source team.env
mkdir -p evidence/phase2
OUT="evidence/phase2/C-edge-still-allowed-$(date +%Y%m%d-%H%M%S).txt"
PIN=(); NOTE="real DNS"
if [ "$(dscacheutil -q host -a name "app.${TEAM_DOMAIN}" | awk '/ip_address/{print $2; exit}')" != "$MAC2_EDGE_IP" ]; then
  PIN=(--resolve "app.${TEAM_DOMAIN}:${EDGE_HTTPS_PORT}:${MAC2_EDGE_IP}"); NOTE="name pinned to $MAC2_EDGE_IP (this Mac's DNS not switched yet), cert still verified"
fi
{
  echo "# from Mac 2 (edge, $(ipconfig getifaddr en0)) at $(date)"
  echo "## TCP to backends directly (edge is in the pf <edges> table, so these should be OPEN)"
  nc -vz -G 3 "$MAC3_BACKEND_A_IP" "$BACKEND_A_PORT" 2>&1
  nc -vz -G 3 "$MAC4_BACKEND_B_IP" "$BACKEND_B_PORT" 2>&1
  echo "## HTTP to backends directly from the edge"
  curl -s -m 4 -D - -o /dev/null "http://$MAC3_BACKEND_A_IP:$BACKEND_A_PORT/api/status" | head -1
  curl -s -m 4 -D - -o /dev/null "http://$MAC4_BACKEND_B_IP:$BACKEND_B_PORT/api/status" | head -1
  echo "## Through the edge by name (expect A/B alternating, no -k), $NOTE"
  for i in 1 2 3 4 5 6; do
    curl -s -m 5 ${PIN[@]+"${PIN[@]}"} -D - -o /dev/null "https://app.${TEAM_DOMAIN}:${EDGE_HTTPS_PORT}/api/status" \
      | awk 'NR==1{printf "%s ", $2} tolower($1)=="x-backend:"{printf "x-backend %s", $2} END{print ""}' | tr -d '\r'
  done
} 2>&1 | tee "$OUT"
echo "Saved to $OUT"
