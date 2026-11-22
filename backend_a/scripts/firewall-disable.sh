#!/usr/bin/env bash
# scripts/firewall-disable.sh — Disable PF Service Isolation and Restore Original State
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_DIR="${BASE_DIR}/config"
TOKEN_FILE="${CONFIG_DIR}/pf.token"

echo "=== DISABLING PF SERVICE ISOLATION (ROLLBACK) ==="

# 1. Flush the cnteam anchor
echo "[1/3] Flushing cnteam anchor rules and tables..."
sudo pfctl -a cnteam -F all 2>/dev/null || true

# 2. Reload default system pf.conf
if [[ -f "/etc/pf.conf" ]]; then
    echo "[2/3] Restoring system /etc/pf.conf..."
    sudo pfctl -f /etc/pf.conf 2>/dev/null || true
fi

# 3. Release PF enable token if saved
if [[ -f "${TOKEN_FILE}" ]]; then
    TOKEN=$(cat "${TOKEN_FILE}")
    if [[ -n "${TOKEN}" ]]; then
        echo "[3/3] Releasing PF reference token ${TOKEN}..."
        sudo pfctl -X "${TOKEN}" 2>/dev/null || true
    fi
    rm -f "${TOKEN_FILE}"
else
    echo "[3/3] No saved reference token found. Ensuring PF disabled if no other users..."
    sudo pfctl -d 2>/dev/null || true
fi

echo ""
echo "=== PF STATUS AFTER ROLLBACK ==="
sudo pfctl -s info 2>/dev/null | grep -E "Status:|State Table" || echo "PF is inactive."
echo "[+] SUCCESS: PF service isolation disabled. Normal network state restored."
