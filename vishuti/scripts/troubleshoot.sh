#!/usr/bin/env bash
# scripts/troubleshoot.sh — Step-by-step layer diagnostic for Mac 3 (Vishuti)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${BASE_DIR}/team.env"

echo "============================================================"
echo "    MAC 3 (BACKEND A) LAYER-BY-LAYER DIAGNOSTIC TOOL"
echo "============================================================"
echo "Time: $(date)"
echo ""

echo "[LAYER 1-3: PHYSICAL, DATA LINK, & NETWORK]"
echo "Checking interface en0..."
ACTUAL_IP=$(ipconfig getifaddr en0 || ipconfig getifaddr en1 || echo "NO_IP")
if [[ "${ACTUAL_IP}" == "NO_IP" ]]; then
    echo "  [FAIL] No IP address assigned on en0. Check Wi-Fi connection."
else
    echo "  [PASS] IP Address: ${ACTUAL_IP}"
fi

echo "Checking Default Gateway ping (${DEFAULT_GATEWAY})..."
if ping -c 1 -W 1000 "${DEFAULT_GATEWAY}" > /dev/null 2>&1; then
    echo "  [PASS] Gateway is reachable."
else
    echo "  [FAIL] Gateway unreachable. Check LAN/Wi-Fi connection."
fi

echo "Checking Edge / Load Balancer ping (Mac 2: ${MAC2_IP})..."
if ping -c 1 -W 1000 "${MAC2_IP}" > /dev/null 2>&1; then
    echo "  [PASS] Mac 2 (Nginx Edge) is reachable."
else
    echo "  [FAIL] Mac 2 (${MAC2_IP}) is unreachable. Check if Mac 2 is on LAN."
fi

echo ""
echo "[LAYER 4: TRANSPORT / PORT BINDING]"
echo "Checking port 3001..."
PORT_OUTPUT=$(lsof -i :3001 2>/dev/null || true)
if [[ -z "${PORT_OUTPUT}" ]]; then
    echo "  [FAIL] Nothing is listening on port 3001!"
    echo "         Remediation: Run ./scripts/start-backend.sh"
else
    echo "  [PASS] Port 3001 is active:"
    echo "${PORT_OUTPUT}" | sed 's/^/         /'
    
    # Check if bound to 0.0.0.0 or 127.0.0.1
    if echo "${PORT_OUTPUT}" | grep -q "127.0.0.1:3001"; then
        echo "  [WARN] Bound ONLY to 127.0.0.1! External machines (Mac 2) cannot connect!"
        echo "         Remediation: Edit backend_a.py to bind to ('0.0.0.0', 3001)."
    elif echo "${PORT_OUTPUT}" | grep -E -q "\*:3001|0.0.0.0:3001"; then
        echo "  [PASS] Server is correctly bound to 0.0.0.0 (all interfaces)."
    fi
fi

echo ""
echo "[SECURITY / FIREWALL LAYER (PF)]"
PF_STATUS=$(sudo -n pfctl -si 2>/dev/null | grep -i "Status:" || echo "Requires sudo or not enabled")
echo "PF Status: ${PF_STATUS}"
ACTIVE_RULES=$(sudo -n pfctl -sr 2>/dev/null || echo "Unable to read pf rules without sudo")
if echo "${ACTIVE_RULES}" | grep -q "port 3001"; then
    echo "  Active rules affecting port 3001:"
    echo "${ACTIVE_RULES}" | grep "port 3001" | sed 's/^/    /'
    if echo "${ACTIVE_RULES}" | grep -q "from ${MAC2_IP} to any port 3001"; then
        echo "  [PASS] Mac 2 (${MAC2_IP}) is explicitly allowed to port 3001."
    else
        echo "  [WARN] Mac 2 (${MAC2_IP}) might NOT be allowed! Verify pf rules."
    fi
else
    echo "  [INFO] No custom pf blocking rules for port 3001 currently active."
fi

echo ""
echo "[LAYER 7: APPLICATION / HTTP RESPONSE]"
echo "Testing local loopback HTTP request..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 "http://localhost:3001/api/status" 2>/dev/null || echo "000")
if [[ "${HTTP_CODE}" == "200" ]]; then
    echo "  [PASS] Local HTTP GET /api/status returned 200 OK."
    BACKEND_HDR=$(curl -s -I "http://localhost:3001/api/status" | grep -i "x-backend" | tr -d '\r' || echo "None")
    echo "         ${BACKEND_HDR}"
else
    echo "  [FAIL] Local HTTP request failed with code ${HTTP_CODE}."
fi

echo ""
echo "Testing LAN IP HTTP request (http://${ACTUAL_IP}:3001/api/status)..."
LAN_HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 "http://${ACTUAL_IP}:3001/api/status" 2>/dev/null || echo "000")
if [[ "${LAN_HTTP_CODE}" == "200" ]]; then
    echo "  [PASS] LAN IP HTTP request succeeded (code 200)."
else
    echo "  [FAIL] LAN IP HTTP request failed (code ${LAN_HTTP_CODE})."
fi

echo ""
echo "============================================================"
echo "Diagnostic complete."
echo "============================================================"
