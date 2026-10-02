#!/usr/bin/env bash
# scripts/stop-backend.sh — Stop Backend A cleanly
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PID_FILE="${BASE_DIR}/backend_a.pid"

STOPPED=0

if [[ -f "${PID_FILE}" ]]; then
    PID=$(cat "${PID_FILE}")
    if ps -p "${PID}" > /dev/null 2>&1; then
        echo "[*] Stopping Backend A (PID: ${PID})..."
        kill -TERM "${PID}" 2>/dev/null || true
        for i in {1..5}; do
            if ! ps -p "${PID}" > /dev/null 2>&1; then
                break
            fi
            sleep 0.5
        done
        if ps -p "${PID}" > /dev/null 2>&1; then
            echo "[!] Graceful shutdown timed out, force killing ${PID}..."
            kill -9 "${PID}" 2>/dev/null || true
        fi
        STOPPED=1
    fi
    rm -f "${PID_FILE}"
fi

# Fallback check if any process is still listening on 3001
REMAINING_PID=$(lsof -ti :3001 || true)
if [[ -n "${REMAINING_PID}" ]]; then
    echo "[*] Killing remaining process on port 3001 (PID: ${REMAINING_PID})..."
    kill -9 ${REMAINING_PID} 2>/dev/null || true
    STOPPED=1
fi

if [[ ${STOPPED} -eq 1 ]]; then
    echo "[+] Backend A stopped."
else
    echo "[*] Backend A was not running."
fi
