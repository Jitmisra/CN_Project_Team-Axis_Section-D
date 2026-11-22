#!/usr/bin/env bash
# scripts/demo-isolation.sh — End-to-end Demonstration Script for Extension C (Service Isolation)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
EVIDENCE_DIR="${BASE_DIR}/evidence/phase2"
mkdir -p "${EVIDENCE_DIR}"

source "${BASE_DIR}/team.env"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
OUTPUT_FILE="${EVIDENCE_DIR}/C-isolation-${TIMESTAMP}.txt"

echo "=== EXTENSION C: SERVICE ISOLATION DEMO RECORD ===" | tee "${OUTPUT_FILE}"
echo "Date/Time: $(date)" | tee -a "${OUTPUT_FILE}"
echo "Backend A IP: ${MAC3_IP}:${MAC3_PORT}" | tee -a "${OUTPUT_FILE}"
echo "Allowed Edge IP: ${MAC2_IP}" | tee -a "${OUTPUT_FILE}"
echo "" | tee -a "${OUTPUT_FILE}"

echo "--- 1. BEFORE ISOLATION: Direct Access Permitted ---" | tee -a "${OUTPUT_FILE}"
echo "[Local Test] curl http://localhost:${MAC3_PORT}/api/status:" | tee -a "${OUTPUT_FILE}"
curl -s -i "http://localhost:${MAC3_PORT}/api/status" | head -n 8 | tee -a "${OUTPUT_FILE}"
echo "" | tee -a "${OUTPUT_FILE}"

echo "[LAN IP Test] curl http://${MAC3_IP}:${MAC3_PORT}/api/status:" | tee -a "${OUTPUT_FILE}"
curl -s -i "http://${MAC3_IP}:${MAC3_PORT}/api/status" | head -n 8 | tee -a "${OUTPUT_FILE}"
echo "" | tee -a "${OUTPUT_FILE}"
echo "Note: Before isolation, any machine on LAN can reach port 3001 directly." | tee -a "${OUTPUT_FILE}"
echo "" | tee -a "${OUTPUT_FILE}"

echo "--- 2. ENABLING PF ANCHOR SERVICE ISOLATION ---" | tee -a "${OUTPUT_FILE}"
"${SCRIPT_DIR}/firewall-enable.sh" return 2>&1 | tee -a "${OUTPUT_FILE}"
echo "" | tee -a "${OUTPUT_FILE}"

echo "--- 3. ACTIVE ISOLATION RULES & HIT COUNTERS ---" | tee -a "${OUTPUT_FILE}"
sudo pfctl -a cnteam -vsr 2>&1 | tee -a "${OUTPUT_FILE}"
echo "" | tee -a "${OUTPUT_FILE}"
echo "Active Edge Table Members:" | tee -a "${OUTPUT_FILE}"
sudo pfctl -a cnteam -t edges -T show 2>&1 | tee -a "${OUTPUT_FILE}"
echo "" | tee -a "${OUTPUT_FILE}"

echo "--- 4. POST-ISOLATION VERIFICATION CHECKS ---" | tee -a "${OUTPUT_FILE}"
echo "[Local Loopback Check (lo0)] — MUST SUCCEED (for local mgmt & standby edge):" | tee -a "${OUTPUT_FILE}"
curl -s -i "http://localhost:${MAC3_PORT}/api/status" | head -n 8 | tee -a "${OUTPUT_FILE}"
echo "" | tee -a "${OUTPUT_FILE}"

echo "Instructions for Teammate Verification:" | tee -a "${OUTPUT_FILE}"
echo "  1. Kartikey (Mac 1: ${MAC1_IP}) runs:" | tee -a "${OUTPUT_FILE}"
echo "     curl -m 3 http://${MAC3_IP}:${MAC3_PORT}/api/status" | tee -a "${OUTPUT_FILE}"
echo "     -> Expected: 'Connection refused' (TCP RST via 'block return in quick')" | tee -a "${OUTPUT_FILE}"
echo "" | tee -a "${OUTPUT_FILE}"
echo "  2. Agnik (Mac 2: ${MAC2_IP}) runs:" | tee -a "${OUTPUT_FILE}"
echo "     nc -vz ${MAC3_IP} ${MAC3_PORT}" | tee -a "${OUTPUT_FILE}"
echo "     curl -s https://${DOMAIN_APP}:${MAC2_HTTPS_PORT}/api/status" | tee -a "${OUTPUT_FILE}"
echo "     -> Expected: Succeeds! Requests arrive from ${MAC2_IP} into Backend A log." | tee -a "${OUTPUT_FILE}"
echo "" | tee -a "${OUTPUT_FILE}"

echo "Evidence successfully recorded to: ${OUTPUT_FILE}"
