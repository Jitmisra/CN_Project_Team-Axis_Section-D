#!/usr/bin/env bash
# Ext E: install/refresh the STANDBY nginx edge on Mac 3 from the SAME template as Mac 2's
# primary (../config/edge.conf.tmpl). Needs certs/cnteam.test.key from Agnik (AirDrop only).
#   ./install-standby.sh
set -euo pipefail
cd "$(dirname "$0")"
HERE="$(pwd)"
source standby.env
TEMPLATE="$HERE/../config/edge.conf.tmpl"
CRT="$HERE/certs/${TEAM_DOMAIN}.crt"
KEY="$HERE/certs/${TEAM_DOMAIN}.key"
EVID="$HERE/../../backend_a/evidence/phase2"; [ -d "$HERE/../../backend_a" ] || EVID="$HERE/evidence"
mkdir -p certs "$EVID"
OUT="$EVID/E-standby-selftest-$(hostname -s)-$(date +%Y%m%d-%H%M%S).txt"

[ -f "$TEMPLATE" ] || { echo "!! $TEMPLATE missing: use the whole mac2-agnik-nginx-edge folder from the repo"; exit 1; }
[ -f "$CRT" ] || cp "$HERE/../certs/${TEAM_DOMAIN}.crt" "$CRT"
[ -f "$KEY" ] || { echo "!! Missing $KEY. Get cnteam.test.key from Agnik by AirDrop, put it in $HERE/certs/. Never commit it."; exit 1; }
chmod 600 "$KEY"

# The key must belong to the cert clients already trust, or every client gets a TLS error.
if [ "$(openssl x509 -noout -pubkey -in "$CRT" | openssl sha256)" != "$(openssl pkey -pubout -in "$KEY" | openssl sha256)" ]; then
  echo "!! $KEY does not match $CRT"; exit 1
fi
echo "[ok] cert and key match"

command -v nginx >/dev/null || { echo "[..] installing nginx"; brew install nginx; }
BREW_PREFIX="$(brew --prefix)"                   # NOT $(brew --prefix nginx)
SERVERS_DIR="$BREW_PREFIX/etc/nginx/servers"
CONF="$SERVERS_DIR/app-${TEAM_DOMAIN}.conf"
ACCESS_LOG="$BREW_PREFIX/var/log/nginx/edge-access.log"
mkdir -p "$SERVERS_DIR" "$(dirname "$ACCESS_LOG")" "$HERE/backups"
[ -f "$CONF" ] && cp "$CONF" "$HERE/backups/app-${TEAM_DOMAIN}.conf.$(date +%Y%m%d-%H%M%S)"

if lsof -nP -iTCP:"$EDGE_HTTPS_PORT" -sTCP:LISTEN 2>/dev/null | grep -v '^COMMAND' | grep -vq nginx; then
  echo "!! something other than nginx already listens on $EDGE_HTTPS_PORT:"; lsof -nP -iTCP:"$EDGE_HTTPS_PORT" -sTCP:LISTEN; exit 1
fi

sed -e "s|@EDGE_NAME@|$EDGE_NAME|g" \
    -e "s|@BACKEND_A@|$BACKEND_A|g" \
    -e "s|@BACKEND_B@|${MAC4_BACKEND_B_IP}:${BACKEND_B_PORT}|g" \
    -e "s|@HTTP_PORT@|$EDGE_HTTP_PORT|g" \
    -e "s|@HTTPS_PORT@|$EDGE_HTTPS_PORT|g" \
    -e "s|@DOMAIN@|$TEAM_DOMAIN|g" \
    -e "s|@CERT@|$CRT|g" \
    -e "s|@KEY@|$KEY|g" \
    -e "s|@ACCESS_LOG@|$ACCESS_LOG|g" \
    "$TEMPLATE" > "$CONF"
echo "[ok] wrote $CONF (edge=$EDGE_NAME, A=$BACKEND_A, B=${MAC4_BACKEND_B_IP}:${BACKEND_B_PORT})"

nginx -t
# nginx retitles its processes ("nginx: master process ..."), so `pgrep -x nginx` never matches.
# Use the master PID file instead.
PIDFILE="$(brew --prefix)/var/run/nginx.pid"
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  nginx -s reload && echo "nginx reloaded (graceful: existing connections finish on old workers)"
else
  brew services start nginx
fi
sleep 2

# Self-test on this Mac. --cacert = verify against our cert (this is NOT -k).
H="app.${TEAM_DOMAIN}"; P="$EDGE_HTTPS_PORT"
{
  echo "# standby self-test on $(hostname -s) ($(ipconfig getifaddr en0)) at $(date)"
  curl -sv --cacert "$CRT" --resolve "$H:$P:127.0.0.1" "https://$H:$P/api/status" -o /dev/null 2>&1 \
    | grep -E "SSL certificate verify|ALPN|^< HTTP|^< x-edge|^< x-backend" | tr -d '\r'
  echo "# 6 requests (expect X-Backend A and B alternating):"
  for i in 1 2 3 4 5 6; do
    curl -s --cacert "$CRT" --resolve "$H:$P:127.0.0.1" -D - -o /dev/null "https://$H:$P/api/status" \
      | awk 'NR==1{printf "%s ", $2} tolower($1)=="x-backend:"||tolower($1)=="x-edge:"{printf "%s %s ", $1, $2} END{print ""}' | tr -d '\r'
  done
} | tee "$OUT"
grep -qi "x-backend: B" "$OUT" || echo "!! Backend B never answered: check MAC4_BACKEND_B_IP in standby.env and that Mac 4's pf allows this Mac ($(ipconfig getifaddr en0))."
grep -qi "x-backend: A" "$OUT" || echo "!! Backend A never answered: is backend_a.py running on :3001?"
echo
echo "From another Mac:  curl --resolve $H:$P:$(ipconfig getifaddr en0) https://$H:$P/api/status -D - -o /dev/null"
echo "Saved to $OUT"
