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

VERDICT="PASS"
FAILING_LAYER=""
FAILING_REASON=""

# LAYER 1-3: PHYSICAL, DATA LINK, & NETWORK
echo "[LAYER 1-3: PHYSICAL, DATA LINK, & NETWORK]"
ACTUAL_IP=$(ipconfig getifaddr en0 || ipconfig getifaddr en1 || echo "NO_IP")
if [[ "${ACTUAL_IP}" == "NO_IP" ]]; then
    echo "  [FAIL] No IP address assigned on en0. Wi-Fi disconnected."
    VERDICT="FAIL"
    FAILING_LAYER="Layer 2/3 (IP Assignment)"
    FAILING_REASON="No IP address on en0"
else
    echo "  [PASS] IP Address on en0: ${ACTUAL_IP}"
fi

echo -n "Checking Gateway reachability (${DEFAULT_GATEWAY})... "
if ping -c 1 -W 1000 "${DEFAULT_GATEWAY}" > /dev/null 2>&1; then
    echo "[PASS]"
else
    echo "[WARN] Gateway unreachable (ICMP ping filtered or gateway down)."
fi

echo -n "Checking Edge / Load Balancer reachability (Mac 2: ${MAC2_IP})... "
if ping -c 1 -W 1000 "${MAC2_IP}" > /dev/null 2>&1; then
    echo "[PASS] Reachable"
else
    echo "[WARN] Mac 2 (${MAC2_IP}) not responding to ping (ICMP may be blocked or IP changed)."
fi

# LAYER 4: TRANSPORT / PORT BINDING
echo ""
echo "[LAYER 4: TRANSPORT / PORT BINDING]"
PORT_OUTPUT=$(lsof -nP -iTCP:3001 -sTCP:LISTEN 2>/dev/null || true)
if [[ -z "${PORT_OUTPUT}" ]]; then
    echo "  [FAIL] Nothing is listening on port 3001!"
    echo "         Remediation: Run ./scripts/start-backend.sh"
    if [[ "${VERDICT}" == "PASS" ]]; then
        VERDICT="FAIL"
        FAILING_LAYER="Layer 4 (Transport / Process Down)"
        FAILING_REASON="backend_a.py is not running on port 3001"
    fi
else
    echo "  [PASS] Port 3001 is active:"
    echo "${PORT_OUTPUT}" | sed 's/^/         /'
    
    if echo "${PORT_OUTPUT}" | grep -q "127.0.0.1:3001"; then
        echo "  [FAIL] Bound ONLY to 127.0.0.1! External Edge (Mac 2) cannot connect!"
        echo "         Remediation: Bind to 0.0.0.0:3001 in backend_a.py."
        if [[ "${VERDICT}" == "PASS" ]]; then
            VERDICT="FAIL"
            FAILING_LAYER="Layer 4 (Socket Binding)"
            FAILING_REASON="Server bound to loopback 127.0.0.1 instead of 0.0.0.0"
        fi
    else
        echo "  [PASS] Server is correctly bound to 0.0.0.0 (all interfaces)."
    fi
fi

# SECURITY / FIREWALL LAYER (PF ANCHOR)
echo ""
echo "[SECURITY / FIREWALL LAYER (PF ANCHOR: cnteam)]"
PF_STATUS=$(sudo -n pfctl -s info 2>/dev/null | grep -i "Status:" || echo "Requires sudo or inactive")
echo "  PF Global Status: ${PF_STATUS}"

ANCHOR_RULES=$(sudo -n pfctl -a cnteam -sr 2>/dev/null || echo "")
if [[ -n "${ANCHOR_RULES}" ]]; then
    echo "  Active cnteam anchor rules:"
    echo "${ANCHOR_RULES}" | sed 's/^/    /'
    
    EDGE_TABLE=$(sudo -n pfctl -a cnteam -t edges -T show 2>/dev/null || echo "")
    echo "  Allowed <edges> table members: ${EDGE_TABLE}"
    if echo "${EDGE_TABLE}" | grep -q "${MAC2_IP}"; then
        echo "  [PASS] Current Mac 2 IP (${MAC2_IP}) is present in <edges> allow-list."
    else
        echo "  [FAIL] Stale Mac 2 IP! Current Mac 2 (${MAC2_IP}) is NOT in <edges> table!"
        echo "         Remediation: Run ./scripts/firewall-enable.sh to re-render with today's IP."
        if [[ "${VERDICT}" == "PASS" ]]; then
            VERDICT="FAIL"
            FAILING_LAYER="Firewall / PF Anchor"
            FAILING_REASON="Mac 2 IP (${MAC2_IP}) not in <edges> table"
        fi
    fi
else
    echo "  [INFO] No custom cnteam anchor rules currently loaded (Direct access unblocked)."
fi

# LAYER 7: APPLICATION / HTTP RESPONSE
echo ""
echo "[LAYER 7: APPLICATION / HTTP RESPONSE]"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 "http://localhost:3001/api/status" 2>/dev/null || echo "000")
if [[ "${HTTP_CODE}" == "200" ]]; then
    echo "  [PASS] Local HTTP GET /api/status returned 200 OK."
    BACKEND_HDR=$(curl -s -I "http://localhost:3001/api/status" | grep -i "x-backend" | tr -d '\r' || echo "")
    echo "         Header: ${BACKEND_HDR}"
else
    echo "  [FAIL] Local HTTP request to /api/status failed with code ${HTTP_CODE}."
    if [[ "${VERDICT}" == "PASS" ]]; then
        VERDICT="FAIL"
        FAILING_LAYER="Layer 7 (Application Response)"
        FAILING_REASON="/api/status returned HTTP ${HTTP_CODE}"
    fi
fi

# Check /api/info and ETag
INFO_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 "http://localhost:3001/api/info" 2>/dev/null || echo "000")
if [[ "${INFO_CODE}" == "200" ]]; then
    ETAG_HDR=$(curl -s -I "http://localhost:3001/api/info" | grep -i "etag" | tr -d '\r' || echo "")
    echo "  [PASS] Local HTTP GET /api/info returned 200 OK. (${ETAG_HDR})"
else
    echo "  [FAIL] Local HTTP request to /api/info failed with code ${INFO_CODE}."
fi

echo ""
echo "============================================================"
if [[ "${VERDICT}" == "PASS" ]]; then
    echo "VERDICT: [PASS] All layers healthy on Mac 3 (Backend A)!"
else
    echo "VERDICT: [FAIL] First failing layer: ${FAILING_LAYER} (${FAILING_REASON})"
fi
echo "============================================================"
