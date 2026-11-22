#!/usr/bin/env bash
# firewall-status.sh — Show current pf state and cnteam anchor rules
echo "=== PF Status ==="
sudo pfctl -si 2>/dev/null | head -5
echo ""
echo "=== Anchor 'cnteam' rules ==="
sudo pfctl -a cnteam -sr 2>/dev/null || echo "(no anchor rules loaded)"
