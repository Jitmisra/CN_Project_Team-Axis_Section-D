#!/usr/bin/env bash
# scripts/firewall-enable.sh — Enable PF Service Isolation on Port 3001 using Anchor
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_DIR="${BASE_DIR}/config"
EVIDENCE_DIR="${BASE_DIR}/evidence/phase2"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="${EVIDENCE_DIR}/C-pf-backup-${TIMESTAMP}"

source "${BASE_DIR}/team.env"

# Action: 'return' (default, sends TCP RST) or 'drop' (silent drop / timeout)
BLOCK_MODE="${1:-return}"
if [[ "${BLOCK_MODE}" == "drop" ]]; then
    BLOCK_ACTION="block drop"
    echo "[*] Using BLOCK DROP mode (silent timeout for unauthorized clients)."
else
    BLOCK_ACTION="block return"
    echo "[*] Using BLOCK RETURN mode (TCP RST / instant Connection Refused)."
fi

echo "=== ENABLING PF SERVICE ISOLATION (PHASE 2 - EXTENSION C) ==="
echo "Edge IP allowed in <edges> table: ${MAC2_IP}"
echo ""

# 1. Create rollback backup
mkdir -p "${BACKUP_DIR}"
echo "[1/5] Backing up current PF state and configuration to ${BACKUP_DIR}..."
sudo pfctl -sr > "${BACKUP_DIR}/pf-rules-before.txt" 2>/dev/null || echo "# No prior rules" > "${BACKUP_DIR}/pf-rules-before.txt"
sudo pfctl -s info > "${BACKUP_DIR}/pf-info-before.txt" 2>/dev/null || echo "# No prior info" > "${BACKUP_DIR}/pf-info-before.txt"
if [[ -f "/etc/pf.conf" ]]; then
    sudo cp /etc/pf.conf "${BACKUP_DIR}/etc-pf.conf.bak"
fi
echo "[+] Rollback backup complete."

# 2. Render anchor config with current Mac 2 IP and block action
ANCHOR_FILE="${CONFIG_DIR}/pf.cnteam.anchor"
sed -e "s/__MAC2_IP__/${MAC2_IP}/g" \
    -e "s/__BLOCK_ACTION__/${BLOCK_ACTION}/g" \
    "${CONFIG_DIR}/pf.cnteam.anchor.tmpl" > "${ANCHOR_FILE}"

echo "[2/5] Generated anchor file: ${ANCHOR_FILE}"
cat "${ANCHOR_FILE}"
echo ""

# 3. Render root pf config with absolute path to anchor
ROOT_CONF="${CONFIG_DIR}/pf.root.conf"
sed "s|__ANCHOR_PATH__|${ANCHOR_FILE}|g" "${CONFIG_DIR}/pf.root.conf.tmpl" > "${ROOT_CONF}"

# 4. Syntax check
echo "[3/5] Validating PF configuration syntax..."
sudo pfctl -vnf "${ROOT_CONF}"

# 5. Enable PF and save reference token
echo "[4/5] Enabling PF and capturing token..."
# Enable PF if not already enabled; capture token
ENABLE_OUT=$(sudo pfctl -E 2>&1 || true)
echo "${ENABLE_OUT}"
TOKEN=$(echo "${ENABLE_OUT}" | grep -oE 'Token : [0-9]+' | awk '{print $3}' || true)
if [[ -n "${TOKEN}" ]]; then
    echo "${TOKEN}" > "${CONFIG_DIR}/pf.token"
    echo "[+] PF reference token saved: ${TOKEN}"
fi

# Load root ruleset including the cnteam anchor
echo "[5/5] Loading PF ruleset into Darwin kernel..."
sudo pfctl -f "${ROOT_CONF}"

echo ""
echo "=== ACTIVE CNTEAM ANCHOR RULES ==="
sudo pfctl -a cnteam -sr
echo ""
echo "=== ACTIVE <edges> TABLE ENTRIES ==="
sudo pfctl -a cnteam -t edges -T show
echo ""
echo "[+] SUCCESS: Port 3001 is now ISOLATED to Mac 2 (${MAC2_IP}) and localhost (lo0)!"
