#!/usr/bin/env bash
# scripts/firewall-status.sh — Inspect active PF rules, anchor, and hit counters
set -euo pipefail

echo "=== PF GENERAL STATUS ==="
sudo pfctl -s info | grep -E "Status:|State Table" || echo "PF not active"

echo ""
echo "=== CNTEAM ANCHOR RULES ==="
sudo pfctl -a cnteam -sr 2>/dev/null || echo "No active cnteam anchor rules"

echo ""
echo "=== CNTEAM ANCHOR RULES WITH PACKET/BYTE HIT COUNTERS (-vsr) ==="
sudo pfctl -a cnteam -vsr 2>/dev/null || echo "No active cnteam anchor rules"

echo ""
echo "=== CNTEAM <edges> TABLE MEMBERS ==="
sudo pfctl -a cnteam -t edges -T show 2>/dev/null || echo "No active <edges> table"
