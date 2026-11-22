#!/usr/bin/env bash
# Task D/E + Phase 2 Ext D: render the PRIMARY edge config from config/edge.conf.tmpl and
# reload nginx. The standby edge (Ext E) renders the same template via standby-edge/.
#   ./scripts/d-install-nginx.sh            render + test + reload/start
#   DRY_RUN=1 ./scripts/d-install-nginx.sh  render to stdout only
set -euo pipefail
cd "$(dirname "$0")/.."
source team.env

: "${MAC3_BACKEND_A_IP:?fill MAC3_BACKEND_A_IP in team.env}"
: "${MAC4_BACKEND_B_IP:?fill MAC4_BACKEND_B_IP in team.env}"
EDGE_NAME="${EDGE_NAME:-mac2-primary}"

BREW_PREFIX="$(brew --prefix)"                    # NOT $(brew --prefix nginx): that is the Cellar
SERVERS_DIR="$BREW_PREFIX/etc/nginx/servers"      # nginx.conf does `include servers/*;`
CONF="$SERVERS_DIR/app-${TEAM_DOMAIN}.conf"
CERT_DIR="$(pwd)/certs"
ACCESS_LOG="$BREW_PREFIX/var/log/nginx/edge-access.log"

[ -f "$CERT_DIR/${TEAM_DOMAIN}.crt" ] && [ -f "$CERT_DIR/${TEAM_DOMAIN}.key" ] \
  || { echo "No TLS cert/key in $CERT_DIR. Run ./scripts/e-make-cert.sh first."; exit 1; }

render() {
  sed -e "s|@EDGE_NAME@|$EDGE_NAME|g" \
      -e "s|@BACKEND_A@|${MAC3_BACKEND_A_IP}:${BACKEND_A_PORT}|g" \
      -e "s|@BACKEND_B@|${MAC4_BACKEND_B_IP}:${BACKEND_B_PORT}|g" \
      -e "s|@HTTP_PORT@|$EDGE_HTTP_PORT|g" \
      -e "s|@HTTPS_PORT@|$EDGE_HTTPS_PORT|g" \
      -e "s|@DOMAIN@|$TEAM_DOMAIN|g" \
      -e "s|@CERT@|$CERT_DIR/${TEAM_DOMAIN}.crt|g" \
      -e "s|@KEY@|$CERT_DIR/${TEAM_DOMAIN}.key|g" \
      -e "s|@ACCESS_LOG@|$ACCESS_LOG|g" \
      config/edge.conf.tmpl
}

if [ "${DRY_RUN:-0}" = 1 ]; then render; exit 0; fi

mkdir -p "$SERVERS_DIR" "$(dirname "$ACCESS_LOG")" config/backups
# Back up the live file OUTSIDE servers/ (anything in servers/ gets loaded by nginx).
[ -f "$CONF" ] && cp "$CONF" "config/backups/app-${TEAM_DOMAIN}.conf.$(date +%Y%m%d-%H%M%S)"

render > "$CONF.new"
mv "$CONF.new" "$CONF"
cp "$CONF" "config/app-${TEAM_DOMAIN}.conf"       # repo copy of what is live (no secrets inside)
echo "Wrote $CONF  (edge=$EDGE_NAME, A=${MAC3_BACKEND_A_IP}:${BACKEND_A_PORT}, B=${MAC4_BACKEND_B_IP}:${BACKEND_B_PORT})"

if ! nginx -t; then
  echo "!! nginx -t failed. Restoring the previous config."
  last="$(ls -t config/backups/app-${TEAM_DOMAIN}.conf.* 2>/dev/null | head -1 || true)"
  [ -n "$last" ] && cp "$last" "$CONF"
  exit 1
fi

# nginx retitles its processes ("nginx: master process ..."), so `pgrep -x nginx` never matches.
# Use the master PID file instead.
PIDFILE="$(brew --prefix)/var/run/nginx.pid"
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  nginx -s reload && echo "nginx reloaded (graceful: existing connections finish on old workers)"
else
  brew services start nginx
fi
sleep 1
lsof -nP -iTCP:"$EDGE_HTTPS_PORT" -sTCP:LISTEN | head -3
