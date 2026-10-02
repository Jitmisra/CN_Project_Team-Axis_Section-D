#!/usr/bin/env bash
# scripts/firewall-status.sh — Inspect active PF rules and status
set -euo pipefail

echo "=== PF FIREWALL STATUS ==="
sudo pfctl -si | grep -E "Status|State Table" || echo "pfctl status check failed"

echo ""
echo "=== ACTIVE PF FILTER RULES ==="
sudo pfctl -sr || echo "No active filter rules"
