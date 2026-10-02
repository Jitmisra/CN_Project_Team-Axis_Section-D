#!/usr/bin/env bash
# scripts/restart-backend.sh — Restart Backend A
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/stop-backend.sh"
sleep 1
"${SCRIPT_DIR}/start-backend.sh"
