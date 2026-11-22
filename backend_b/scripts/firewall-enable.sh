#!/usr/bin/env bash
# scripts/firewall-enable.sh — Enable PF Service Isolation on Port 3002
set -euo pipefail
cd "$(dirname "$0")/.."
source team.env

RULES="config/pf_rules_isolation.conf"
BACKUP="evidence/phase2/C-pf-backup-$(date +%Y%m%d_%H%M%S).txt"
mkdir -p evidence/phase2

echo "=== ENABLING PF SERVICE ISOLATION (PHASE 2 - EXTENSION C) ==="

# 1. Back up current rules
echo "[1/4] Backing up current PF rules..."
sudo pfctl -sr > "$BACKUP" 2>/dev/null || echo "# No prior custom rules" > "$BACKUP"
echo "[+] Backup saved to: $BACKUP"

# 2. Update config with current MAC2_IP and MAC3_IP (safely allowing outgoing state)
cat > "$RULES" <<EOF
# PF Firewall Rules for Service Isolation (Mac 4 - Port 3002)
pass out quick all keep state
pass in quick on lo0 proto tcp from any to any port 3002
pass in quick proto tcp from ${MAC2_IP} to any port 3002
pass in quick proto tcp from ${MAC3_IP} to any port 3002
block in quick proto tcp from any to any port 3002
pass in quick all keep state
EOF

echo "[2/4] Generated rules in: $RULES"
cat "$RULES"
echo ""

# 3. Test rule syntax
echo "[3/4] Validating rule syntax with pfctl -vnf..."
sudo pfctl -vnf "$RULES"

# 4. Load rules and enable pf
echo "[4/4] Loading rules and enabling pf..."
sudo pfctl -f "$RULES" -e

echo ""
echo "[+] SUCCESS: PF Service Isolation active on port 3002."
echo "[+] Allowed: Mac 2 (${MAC2_IP}), Mac 3 (${MAC3_IP})"
echo "[+] Blocked: All other clients (including Mac 1 ${MAC1_IP})"
echo "[+] Outgoing traffic: Explicitly preserved via 'pass out quick all keep state'"
