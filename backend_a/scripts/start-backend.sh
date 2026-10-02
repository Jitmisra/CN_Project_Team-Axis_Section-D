#!/usr/bin/env bash
# scripts/start-backend.sh — Start Backend A in background
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${BASE_DIR}/logs"
PID_FILE="${BASE_DIR}/backend_a.pid"
LOG_FILE="${LOG_DIR}/backend_a.log"

mkdir -p "${LOG_DIR}"

if [[ -f "${PID_FILE}" ]]; then
    PID=$(cat "${PID_FILE}")
    if ps -p "${PID}" > /dev/null 2>&1; then
        echo "[!] Backend A is already running with PID ${PID}."
        exit 0
    else
        echo "[*] Removing stale PID file (${PID})."
        rm -f "${PID_FILE}"
    fi
fi

# Check if port 3001 is already occupied
if lsof -i :3001 > /dev/null 2>&1; then
    echo "[!] Port 3001 is already in use by another process:"
    lsof -i :3001
    exit 1
fi

echo "[*] Starting Backend A on 0.0.0.0:3001..."
nohup python3 "${BASE_DIR}/backend_a.py" >> "${LOG_FILE}" 2>&1 &
BACKEND_PID=$!
echo "${BACKEND_PID}" > "${PID_FILE}"

sleep 1

if ps -p "${BACKEND_PID}" > /dev/null 2>&1; then
    echo "[+] Backend A started successfully (PID: ${BACKEND_PID})."
    echo "[+] Logs: ${LOG_FILE}"
    echo "[+] Port: 3001"
else
    echo "[-] Failed to start Backend A. Check ${LOG_FILE}."
    exit 1
fi
