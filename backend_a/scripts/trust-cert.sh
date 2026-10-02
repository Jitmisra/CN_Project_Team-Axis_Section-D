#!/usr/bin/env bash
# scripts/trust-cert.sh — Install and trust Agnik's self-signed TLS certificate
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CERT_FILE="${BASE_DIR}/config/app.cnteam.test.crt"

if [[ ! -f "${CERT_FILE}" ]]; then
    echo "[-] Certificate file not found at ${CERT_FILE}"
    exit 1
fi

echo "=== INSTALLING AND TRUSTING TLS CERTIFICATE ==="
echo "Target: ${CERT_FILE}"
echo "Common Name: app.cnteam.test"
echo "SANs: app.cnteam.test, api.cnteam.test"
echo ""
echo "[*] Adding certificate to System Keychain as trusted root..."
echo "[*] (This requires sudo permissions)"

sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "${CERT_FILE}"

echo ""
echo "[+] Certificate successfully trusted in System Keychain!"
echo "[+] You can now run curl commands without '-k':"
echo "    curl https://app.cnteam.test/api/status"
echo ""
echo "[*] To remove certificate after the course project is complete, run:"
echo "    sudo security delete-certificate -c \"app.cnteam.test\" /Library/Keychains/System.keychain"
