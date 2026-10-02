#!/usr/bin/env bash
# scripts/firewall-enable.sh — Enable PF Service Isolation on Port 3001
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
EVIDENCE_DIR="${BASE_DIR}/evidence"
mkdir -p "${EVIDENCE_DIR}"

source "${BASE_DIR}/team.env"

BACKUP_FILE="${EVIDENCE_DIR}/pf_rules_backup_$(date +%Y%m%d_%H%M%S).txt"
HOME_BACKUP="${HOME}/pf_rules_backup.txt"
ACTIVE_RULES="${BASE_DIR}/config/pf_rules_isolation.conf"

echo "=== ENABLING PF SERVICE ISOLATION (PHASE 2 - EXTENSION C) ==="

# 1. Back up current rules
echo "[1/4] Backing up current PF rules..."
sudo pfctl -sr > "${BACKUP_FILE}" 2>/dev/null || echo "# No prior custom rules" > "${BACKUP_FILE}"
cp "${BACKUP_FILE}" "${HOME_BACKUP}"
echo "[+] Backup saved to: ${BACKUP_FILE} and ${HOME_BACKUP}"

# 2. Update config with MAC2_IP if changed
sed "s/__MAC2_IP__/${MAC2_IP}/g" "${BASE_DIR}/config/pf_rules_template.conf" > "${ACTIVE_RULES}"
echo "[2/4] Generated rules in: ${ACTIVE_RULES}"
cat "${ACTIVE_RULES}"

# 3. Test rule syntax
echo "[3/4] Validating rule syntax with pfctl -vnf..."
sudo pfctl -vnf "${ACTIVE_RULES}"

# 4. Load rules and enable pf
echo "[4/4] Loading rules and enabling pf..."
sudo pfctl -f "${ACTIVE_RULES}" -e

echo ""
echo "[+] SUCCESS: PF Service Isolation active on port 3001."
echo "[+] Allowed remote client: Mac 2 (${MAC2_IP})"
echo "[+] Blocked: All other clients"
