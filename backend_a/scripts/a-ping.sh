#!/usr/bin/env bash
# scripts/a-ping.sh — Ping test all team nodes and gateway for Task A
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
EVIDENCE_DIR="${BASE_DIR}/evidence"
mkdir -p "${EVIDENCE_DIR}"

source "${BASE_DIR}/team.env"

OUTPUT_FILE="${EVIDENCE_DIR}/task-a-ping.txt"
echo "=== MAC 3 (VISHUTI) PING TEST EVIDENCE ===" | tee "${OUTPUT_FILE}"
echo "Date/Time: $(date)" | tee -a "${OUTPUT_FILE}"
echo "" | tee -a "${OUTPUT_FILE}"

echo "--- 1. Ping Default Gateway (${DEFAULT_GATEWAY}) ---" | tee -a "${OUTPUT_FILE}"
ping -c 3 "${DEFAULT_GATEWAY}" | tee -a "${OUTPUT_FILE}" || echo "Gateway ping failed" | tee -a "${OUTPUT_FILE}"
echo "" | tee -a "${OUTPUT_FILE}"

echo "--- 2. Ping Mac 1 (Kartikey - DNS: ${MAC1_IP}) ---" | tee -a "${OUTPUT_FILE}"
ping -c 3 -W 1000 "${MAC1_IP}" | tee -a "${OUTPUT_FILE}" || echo "Mac 1 ping failed" | tee -a "${OUTPUT_FILE}"
echo "" | tee -a "${OUTPUT_FILE}"

echo "--- 3. Ping Mac 2 (Agnik - Edge/Nginx: ${MAC2_IP}) ---" | tee -a "${OUTPUT_FILE}"
ping -c 3 -W 1000 "${MAC2_IP}" | tee -a "${OUTPUT_FILE}" || echo "Mac 2 ping failed" | tee -a "${OUTPUT_FILE}"
echo "" | tee -a "${OUTPUT_FILE}"

if [[ "${MAC4_IP}" != "10.7.0.0" && -n "${MAC4_IP}" ]]; then
    echo "--- 4. Ping Mac 4 (Anwesha - Backend B: ${MAC4_IP}) ---" | tee -a "${OUTPUT_FILE}"
    ping -c 3 -W 1000 "${MAC4_IP}" | tee -a "${OUTPUT_FILE}" || echo "Mac 4 ping failed" | tee -a "${OUTPUT_FILE}"
else
    echo "--- 4. Mac 4 (Anwesha) IP not yet configured in team.env (Skipping ping) ---" | tee -a "${OUTPUT_FILE}"
fi
echo "" | tee -a "${OUTPUT_FILE}"
echo "Evidence successfully saved to: ${OUTPUT_FILE}"
