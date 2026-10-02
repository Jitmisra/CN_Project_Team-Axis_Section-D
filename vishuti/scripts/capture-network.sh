#!/usr/bin/env bash
# scripts/capture-network.sh — Capture Mac 3 (Vishuti) Network Details for Task A Evidence
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
EVIDENCE_DIR="${BASE_DIR}/evidence"
mkdir -p "${EVIDENCE_DIR}"

source "${BASE_DIR}/team.env"

OUTPUT_FILE="${EVIDENCE_DIR}/task-a-network.txt"
echo "=== MAC 3 (VISHUTI) NETWORK CONFIGURATION EVIDENCE ===" | tee "${OUTPUT_FILE}"
echo "Date/Time: $(date)" | tee -a "${OUTPUT_FILE}"
echo "" | tee -a "${OUTPUT_FILE}"

echo "--- 1. IPv4 Address (en0) ---" | tee -a "${OUTPUT_FILE}"
MAC3_ACTUAL_IP=$(ipconfig getifaddr en0 || ipconfig getifaddr en1)
echo "IP: ${MAC3_ACTUAL_IP}" | tee -a "${OUTPUT_FILE}"
echo "" | tee -a "${OUTPUT_FILE}"

echo "--- 2. Default Gateway ---" | tee -a "${OUTPUT_FILE}"
netstat -nr | grep default | tee -a "${OUTPUT_FILE}"
echo "" | tee -a "${OUTPUT_FILE}"

echo "--- 3. Interface Details (en0) ---" | tee -a "${OUTPUT_FILE}"
ifconfig en0 | tee -a "${OUTPUT_FILE}"
echo "" | tee -a "${OUTPUT_FILE}"

echo "--- 4. MAC Address (Hardware Address) ---" | tee -a "${OUTPUT_FILE}"
ifconfig en0 | grep ether | awk '{print $2}' | tee -a "${OUTPUT_FILE}"
echo "" | tee -a "${OUTPUT_FILE}"

echo "--- 5. Summary Row for Shared IP Table ---" | tee -a "${OUTPUT_FILE}"
MAC_ADDR=$(ifconfig en0 | grep ether | awk '{print $2}')
echo "| Mac 3 | Backend A | ${MAC3_ACTUAL_IP} | ${SUBNET_MASK} (${SUBNET_CIDR}) | ${DEFAULT_GATEWAY} | en0 | ${MAC_ADDR} |" | tee -a "${OUTPUT_FILE}"
echo "" | tee -a "${OUTPUT_FILE}"
echo "Evidence successfully saved to: ${OUTPUT_FILE}"
