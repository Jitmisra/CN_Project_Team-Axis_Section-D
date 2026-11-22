#!/usr/bin/env bash
# Start Backend B
set -euo pipefail
cd "$(dirname "$0")/.."
source team.env

# Kill existing if running
pkill -f "python3.*backend_b.py" 2>/dev/null || true
sleep 1

nohup python3 backend_b.py > /tmp/backend_b.log 2>&1 &
echo "Backend B started on 0.0.0.0:${BACKEND_PORT} (PID $!)"
echo "Log: /tmp/backend_b.log"
sleep 1
curl -s http://127.0.0.1:${BACKEND_PORT}/api/status && echo ""
