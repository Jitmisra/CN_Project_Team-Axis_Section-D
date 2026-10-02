#!/usr/bin/env bash
# scripts/firewall-disable.sh — Restore original PF rules and disable isolation
set -euo pipefail

echo "=== DISABLING PF SERVICE ISOLATION ==="

# Check if default pf.conf exists
if [[ -f "/etc/pf.conf" ]]; then
    echo "[*] Reloading default /etc/pf.conf..."
    sudo pfctl -f /etc/pf.conf 2>/dev/null || true
fi

echo "[*] Disabling pf packet filter..."
sudo pfctl -d 2>/dev/null || true

echo "[+] PF service isolation disabled. Normal firewall state restored."
