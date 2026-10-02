#!/usr/bin/env bash
# Task D - render the nginx server block from team.env and reload nginx.
set -euo pipefail
cd "$(dirname "$0")/.."
source team.env

if [ -z "$MAC3_BACKEND_A_IP" ] || [ -z "$MAC4_BACKEND_B_IP" ]; then
  echo "team.env is missing MAC3_BACKEND_A_IP and/or MAC4_BACKEND_B_IP."
  echo "Fill those in once Vishuti and Anwesha report their IPs, then re-run this script."
  exit 1
fi

NGINX_PREFIX="$(brew --prefix nginx)"
SERVERS_DIR="$(brew --prefix)/etc/nginx/servers"
CERT_DIR="$(pwd)/certs"
CONF="$SERVERS_DIR/app-${TEAM_DOMAIN}.conf"

mkdir -p "$SERVERS_DIR"

if [ ! -f "$CERT_DIR/${TEAM_DOMAIN}.crt" ]; then
  echo "No TLS cert found. Run ./scripts/e-make-cert.sh first."
  exit 1
fi

cat > "$CONF" <<EOF
upstream backend_pool {
    server ${MAC3_BACKEND_A_IP}:${BACKEND_A_PORT} max_fails=2 fail_timeout=5s;
    server ${MAC4_BACKEND_B_IP}:${BACKEND_B_PORT} max_fails=2 fail_timeout=5s;
    # round-robin (nginx default) across Backend A and Backend B
}

server {
    listen ${EDGE_HTTP_PORT};
    server_name app.${TEAM_DOMAIN} api.${TEAM_DOMAIN};
    return 301 https://\$host:${EDGE_HTTPS_PORT}\$request_uri;
}

server {
    listen ${EDGE_HTTPS_PORT} ssl;
    server_name app.${TEAM_DOMAIN} api.${TEAM_DOMAIN};

    ssl_certificate     ${CERT_DIR}/${TEAM_DOMAIN}.crt;
    ssl_certificate_key ${CERT_DIR}/${TEAM_DOMAIN}.key;

    location / {
        proxy_pass http://backend_pool;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_next_upstream error timeout http_502 http_503 http_504;
    }
}
EOF

echo "Wrote $CONF"
"$NGINX_PREFIX/bin/nginx" -t
brew services restart nginx
sleep 1
brew services info nginx
