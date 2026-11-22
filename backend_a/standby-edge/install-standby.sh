#!/usr/bin/env bash
# standby-edge/install-standby.sh — Set up Standby Nginx Edge on Mac 3 (Extension E)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${BASE_DIR}/team.env"

# 1. Check if Homebrew nginx is installed
if ! command -v nginx >/dev/null 2>&1; then
    echo "[!] nginx is not installed via Homebrew. Installing nginx..."
    brew install nginx
fi

BREW_PREFIX="$(brew --prefix)"
NGINX_CONF_DIR="${BREW_PREFIX}/etc/nginx"
SERVERS_DIR="${NGINX_CONF_DIR}/servers"
CERT_DIR="${SCRIPT_DIR}/certs"
mkdir -p "${SERVERS_DIR}" "${CERT_DIR}"

# 2. Check for TLS Certificate and Key
CERT_FILE="${CERT_DIR}/cnteam.test.crt"
KEY_FILE="${CERT_DIR}/cnteam.test.key"

# Copy crt from config if not already in standby-edge/certs
if [[ ! -f "${CERT_FILE}" && -f "${BASE_DIR}/config/app.cnteam.test.crt" ]]; then
    cp "${BASE_DIR}/config/app.cnteam.test.crt" "${CERT_FILE}"
fi

if [[ ! -f "${CERT_FILE}" ]]; then
    echo "[-] Certificate file not found at ${CERT_FILE}"
    exit 1
fi

if [[ ! -f "${KEY_FILE}" ]]; then
    echo "[!] WARNING: Private key not found at ${KEY_FILE}!"
    echo "    Obtain 'cnteam.test.key' from Agnik by AirDrop only, place it in:"
    echo "    ${KEY_FILE}"
    echo "    and run this script again."
    exit 1
fi

chmod 600 "${KEY_FILE}"

# 3. Render Nginx configuration
CONF_DEST="${SERVERS_DIR}/standby-cnteam.conf"
sed -e "s|__MAC4_IP__|${MAC4_IP}|g" \
    -e "s|__CERT_PATH__|${CERT_FILE}|g" \
    -e "s|__KEY_PATH__|${KEY_FILE}|g" \
    "${SCRIPT_DIR}/nginx-standby.conf.tmpl" > "${CONF_DEST}"

echo "[+] Rendered Standby Edge configuration: ${CONF_DEST}"
cat "${CONF_DEST}"
echo ""

# 4. Test configuration and restart nginx
echo "[*] Validating nginx configuration..."
nginx -t

echo "[*] Restarting nginx via Homebrew..."
brew services restart nginx || nginx -s reload

echo ""
echo "[+] SUCCESS: Standby Edge is live on Mac 3!"
echo "    Listening on: 8080 (HTTP) and 8443 (HTTPS)"
echo "    Identity Header: X-Edge: mac3-standby"
echo "    Run ./selftest-standby.sh to verify."
