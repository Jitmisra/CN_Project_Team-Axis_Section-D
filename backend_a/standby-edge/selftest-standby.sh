#!/usr/bin/env bash
# standby-edge/selftest-standby.sh — Self-test Standby Edge on Mac 3
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
EVIDENCE_DIR="${BASE_DIR}/evidence/phase2"
mkdir -p "${EVIDENCE_DIR}"

OUTPUT_FILE="${EVIDENCE_DIR}/E-standby-selftest.txt"

echo "=== STANDBY EDGE SELF-TEST EVIDENCE (MAC 3) ===" | tee "${OUTPUT_FILE}"
echo "Date/Time: $(date)" | tee -a "${OUTPUT_FILE}"
echo "" | tee -a "${OUTPUT_FILE}"

echo "--- 1. Testing Standby Edge over HTTPS (127.0.0.1:8443) ---" | tee -a "${OUTPUT_FILE}"
curl --resolve app.cnteam.test:8443:127.0.0.1 -i -s https://app.cnteam.test:8443/api/status | tee -a "${OUTPUT_FILE}"
echo "" | tee -a "${OUTPUT_FILE}"

echo "--- 2. Checking X-Edge Header (Must be mac3-standby) ---" | tee -a "${OUTPUT_FILE}"
curl --resolve app.cnteam.test:8443:127.0.0.1 -s -D - https://app.cnteam.test:8443/api/status -o /dev/null | grep -i x-edge | tee -a "${OUTPUT_FILE}"
echo "" | tee -a "${OUTPUT_FILE}"

echo "--- 3. Checking Backend Alternation through Standby Edge ---" | tee -a "${OUTPUT_FILE}"
for i in {1..4}; do
    RES=$(curl --resolve app.cnteam.test:8443:127.0.0.1 -s -D - https://app.cnteam.test:8443/api/status -o /dev/null | grep -i x-backend || true)
    echo "Request $i: ${RES}" | tee -a "${OUTPUT_FILE}"
done

echo "" | tee -a "${OUTPUT_FILE}"
echo "[+] Self-test complete. Evidence saved to: ${OUTPUT_FILE}"
