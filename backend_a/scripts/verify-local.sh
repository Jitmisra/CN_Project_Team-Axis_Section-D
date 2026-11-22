#!/usr/bin/env bash
# scripts/verify-local.sh — Verify Backend A endpoints, headers, and save evidence
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
EVIDENCE_DIR="${BASE_DIR}/evidence"
mkdir -p "${EVIDENCE_DIR}"

source "${BASE_DIR}/team.env"
OUTPUT_FILE="${EVIDENCE_DIR}/task-c-local-verify.txt"

echo "=== BACKEND A VERIFICATION EVIDENCE ===" | tee "${OUTPUT_FILE}"
echo "Date/Time: $(date)" | tee -a "${OUTPUT_FILE}"
echo "" | tee -a "${OUTPUT_FILE}"

echo "--- 1. Testing GET / (Root Endpoint) ---" | tee -a "${OUTPUT_FILE}"
curl -i -s "http://localhost:${MAC3_PORT}/" | tee -a "${OUTPUT_FILE}"
echo "" | tee -a "${OUTPUT_FILE}"

echo "--- 2. Testing GET /api/status (JSON Status Endpoint) ---" | tee -a "${OUTPUT_FILE}"
curl -i -s "http://localhost:${MAC3_PORT}/api/status" | tee -a "${OUTPUT_FILE}"
echo "" | tee -a "${OUTPUT_FILE}"

echo "--- 3. Testing GET /api/info (Shared Info + ETag) ---" | tee -a "${OUTPUT_FILE}"
curl -i -s "http://localhost:${MAC3_PORT}/api/info" | tee -a "${OUTPUT_FILE}"
echo "" | tee -a "${OUTPUT_FILE}"

echo "--- 4. Testing LAN IP Reachability (http://${MAC3_IP}:${MAC3_PORT}/api/status) ---" | tee -a "${OUTPUT_FILE}"
curl -i -s "http://${MAC3_IP}:${MAC3_PORT}/api/status" | tee -a "${OUTPUT_FILE}"
echo "" | tee -a "${OUTPUT_FILE}"

echo "--- 5. Testing 404 Handler (http://localhost:${MAC3_PORT}/invalid-path) ---" | tee -a "${OUTPUT_FILE}"
curl -i -s "http://localhost:${MAC3_PORT}/invalid-path" | tee -a "${OUTPUT_FILE}"
echo "" | tee -a "${OUTPUT_FILE}"

echo "--- 6. Specific Header Checks ---" | tee -a "${OUTPUT_FILE}"
echo -n "X-Backend Header: " | tee -a "${OUTPUT_FILE}"
curl -s -D - "http://localhost:${MAC3_PORT}/api/status" -o /dev/null | grep -i "x-backend" | tee -a "${OUTPUT_FILE}"

echo -n "Cache-Control Header: " | tee -a "${OUTPUT_FILE}"
curl -s -D - "http://localhost:${MAC3_PORT}/api/status" -o /dev/null | grep -i "cache-control" | tee -a "${OUTPUT_FILE}"

echo -n "ETag Header: " | tee -a "${OUTPUT_FILE}"
curl -s -D - "http://localhost:${MAC3_PORT}/api/info" -o /dev/null | grep -i "etag" | tee -a "${OUTPUT_FILE}"

echo "--- 7. Conditional Request Check (304 Not Modified) ---" | tee -a "${OUTPUT_FILE}"
ETAG=$(curl -sI "http://localhost:${MAC3_PORT}/api/info" | grep -i etag | tr -d '\r' | awk '{print $2}')
curl -i -s -H "If-None-Match: ${ETAG}" "http://localhost:${MAC3_PORT}/api/info" | head -n 5 | tee -a "${OUTPUT_FILE}"

echo "" | tee -a "${OUTPUT_FILE}"
echo "Local verification complete. Evidence saved to: ${OUTPUT_FILE}"
