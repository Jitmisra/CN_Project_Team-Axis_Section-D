#!/usr/bin/env bash
# scripts/status.sh — Inspect status of Backend A
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PID_FILE="${BASE_DIR}/backend_a.pid"
LOG_FILE="${BASE_DIR}/logs/backend_a.log"

echo "=== BACKEND A SERVICE STATUS ==="
if [[ -f "${PID_FILE}" ]]; then
    PID=$(cat "${PID_FILE}")
    if ps -p "${PID}" > /dev/null 2>&1; then
        echo "[STATUS] RUNNING (PID: ${PID})"
    else
        echo "[STATUS] STOPPED (Stale PID: ${PID})"
    fi
else
    echo "[STATUS] STOPPED (No PID file)"
fi

echo ""
echo "=== PORT 3001 BINDING ==="
if lsof -i :3001 > /dev/null 2>&1; then
    lsof -i :3001
else
    echo "No process listening on port 3001."
fi

echo ""
echo "=== RECENT LOGS (Last 15 lines) ==="
if [[ -f "${LOG_FILE}" ]]; then
    tail -n 15 "${LOG_FILE}"
else
    echo "No log file found at ${LOG_FILE}."
fi
