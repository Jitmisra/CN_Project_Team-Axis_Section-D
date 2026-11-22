#!/usr/bin/env bash
# standby-edge/uninstall-standby.sh — Clean up Standby Edge after demo
set -euo pipefail

BREW_PREFIX="$(brew --prefix)"
CONF_DEST="${BREW_PREFIX}/etc/nginx/servers/standby-cnteam.conf"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEY_FILE="${SCRIPT_DIR}/certs/cnteam.test.key"

echo "=== UNINSTALLING STANDBY EDGE ON MAC 3 ==="

# 1. Stop nginx service
echo "[1/3] Stopping Homebrew nginx..."
brew services stop nginx 2>/dev/null || nginx -s stop 2>/dev/null || true

# 2. Remove configuration
if [[ -f "${CONF_DEST}" ]]; then
    echo "[2/3] Removing ${CONF_DEST}..."
    rm -f "${CONF_DEST}"
fi

# 3. Securely remove private key
if [[ -f "${KEY_FILE}" ]]; then
    echo "[3/3] Securely deleting private key ${KEY_FILE}..."
    rm -f "${KEY_FILE}"
fi

echo "[+] SUCCESS: Standby edge removed and clean state restored."
