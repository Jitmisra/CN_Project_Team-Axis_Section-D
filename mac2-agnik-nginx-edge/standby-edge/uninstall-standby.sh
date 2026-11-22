#!/usr/bin/env bash
# Ext E cleanup on Mac 3: stop the standby edge, remove its config, DELETE the private key copy.
set -euo pipefail
cd "$(dirname "$0")"
source standby.env
CONF="$(brew --prefix)/etc/nginx/servers/app-${TEAM_DOMAIN}.conf"
brew services stop nginx 2>/dev/null || nginx -s stop 2>/dev/null || true
rm -f "$CONF" && echo "[ok] removed $CONF"
rm -f "certs/${TEAM_DOMAIN}.key" && echo "[ok] deleted certs/${TEAM_DOMAIN}.key (tell Agnik it's gone)"
lsof -nP -iTCP:8443 -sTCP:LISTEN || echo "[ok] nothing listening on 8443 any more"
