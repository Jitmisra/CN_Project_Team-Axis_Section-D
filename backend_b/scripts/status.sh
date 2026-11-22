#!/usr/bin/env bash
# Check Backend B status
cd "$(dirname "$0")/.."
source team.env

PID=$(pgrep -f "python3.*backend_b.py" || true)
if [ -n "$PID" ]; then
    echo "Backend B running (PID $PID)"
    curl -s http://127.0.0.1:${BACKEND_PORT}/api/status && echo ""
else
    echo "Backend B NOT running."
fi
