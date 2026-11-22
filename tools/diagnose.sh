#!/usr/bin/env bash
# tools/diagnose.sh — Layer-by-layer diagnosis for the faculty fault (Ext F)
# Usage: ./tools/diagnose.sh
# Checks each layer in order, stops at the first failure.
set -euo pipefail
cd "$(dirname "$0")"
source team.env

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

echo "===== CN Team Diagnosis Tool ====="
echo "Time: $(date)"
echo ""

# --- Layer 0: Local link ---
echo "--- Layer 0: Local network link ---"
MY_IP=$(ipconfig getifaddr en0 2>/dev/null || echo "")
if [ -z "$MY_IP" ]; then
    fail "No IP on en0 — Wi-Fi down or disconnected"
    echo "FIRST FAILING LAYER: 0 (Local link)"
    echo "Likely cause: Wi-Fi not connected or wrong network"
    exit 1
fi
pass "Local IP: $MY_IP"

GW=$(netstat -rn | awk '/^default.*en0/{print $2; exit}')
if [ -n "$GW" ] && ping -c1 -W1 "$GW" >/dev/null 2>&1; then
    pass "Gateway $GW reachable"
else
    warn "Gateway ping failed (may be filtered — not fatal)"
fi
echo ""

# --- Layer 1: Resolver config ---
echo "--- Layer 1: Resolver configuration ---"
DNS_SERVERS=$(scutil --dns | grep 'nameserver\[' | awk '{print $3}' | sort -u | tr '\n' ' ')
echo "    Configured resolvers: $DNS_SERVERS"
if echo "$DNS_SERVERS" | grep -q "$MAC1_IP\|$MAC4_IP"; then
    pass "At least one team DNS server configured"
else
    fail "No team DNS server in resolver list (need $MAC1_IP or $MAC4_IP)"
    echo "FIRST FAILING LAYER: 1 (Resolver config)"
    echo "Likely cause: DNS resolver not set to team servers"
    exit 1
fi

# Check /etc/hosts override
if grep -q "$DOMAIN" /etc/hosts 2>/dev/null; then
    warn "/etc/hosts has an entry for $DOMAIN — may override DNS"
fi
echo ""

# --- Layer 2: DNS resolution ---
echo "--- Layer 2: DNS resolution ---"
EXPECTED_IP="$MAC2_IP"
DNS_OK=0

A1=$(dig +short @${MAC1_IP} ${DOMAIN} 2>/dev/null || echo "TIMEOUT")
echo "    dig @Mac1 ($MAC1_IP): $A1"
[ "$A1" = "$EXPECTED_IP" ] && DNS_OK=1 || warn "Mac1 DNS: expected $EXPECTED_IP, got $A1"

A4=$(dig +short @${MAC4_IP} ${DOMAIN} 2>/dev/null || echo "TIMEOUT")
echo "    dig @Mac4 ($MAC4_IP): $A4"
[ "$A4" = "$EXPECTED_IP" ] && DNS_OK=1 || warn "Mac4 DNS: expected $EXPECTED_IP, got $A4"

CACHED=$(dscacheutil -q host -a name ${DOMAIN} 2>/dev/null | grep 'ip_address' | awk '{print $2}')
echo "    dscacheutil cache: ${CACHED:-empty}"

if [ $DNS_OK -eq 0 ]; then
    fail "Neither DNS server returned $EXPECTED_IP for $DOMAIN"
    echo "FIRST FAILING LAYER: 2 (DNS)"
    echo "Likely causes: dnsmasq down, wrong record, stale cache"
    echo "Try: sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder"
    exit 1
fi
RESOLVED="${A1}"
[ "$RESOLVED" = "TIMEOUT" ] && RESOLVED="${A4}"
pass "DNS resolves $DOMAIN -> $RESOLVED"
echo ""

# --- Layer 3: IP reachability ---
echo "--- Layer 3: IP reachability ---"
if ping -c2 -W2 "$RESOLVED" >/dev/null 2>&1; then
    pass "Host $RESOLVED is reachable"
else
    fail "Cannot ping $RESOLVED"
    echo "FIRST FAILING LAYER: 3 (IP reachability)"
    echo "Likely cause: host down or wrong IP in DNS record"
    exit 1
fi
echo ""

# --- Layer 4: TCP connection ---
echo "--- Layer 4: TCP to port $HTTPS_PORT ---"
if nc -vz -G 3 "$RESOLVED" "$HTTPS_PORT" 2>&1 | grep -q 'succeeded\|open'; then
    pass "TCP port $HTTPS_PORT open on $RESOLVED"
else
    fail "TCP connection to $RESOLVED:$HTTPS_PORT failed"
    echo "FIRST FAILING LAYER: 4 (TCP)"
    echo "Likely causes: nginx down, wrong port, firewall blocking"
    exit 1
fi
echo ""

# --- Layer 5: TLS handshake ---
echo "--- Layer 5: TLS handshake ---"
TLS_OUT=$(echo | openssl s_client -connect "${RESOLVED}:${HTTPS_PORT}" \
    -servername ${DOMAIN} -verify_return_error 2>&1 || true)
VERIFY=$(echo "$TLS_OUT" | grep 'Verify return code' || echo "unknown")
echo "    $VERIFY"

if echo "$VERIFY" | grep -q '0 (ok)'; then
    pass "TLS handshake valid, cert trusted"
else
    SUBJ=$(echo "$TLS_OUT" | grep 'subject=' || echo "")
    echo "    Subject: $SUBJ"
    fail "TLS verification failed"
    echo "FIRST FAILING LAYER: 5 (TLS)"
    echo "Likely causes: wrong/expired/untrusted cert, SAN mismatch"
    exit 1
fi
echo ""

# --- Layer 6: HTTP response ---
echo "--- Layer 6: HTTP response ---"
HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' \
    "https://${DOMAIN}:${HTTPS_PORT}/api/status" 2>/dev/null || echo "000")
HEADERS=$(curl -sI "https://${DOMAIN}:${HTTPS_PORT}/api/status" 2>/dev/null || echo "")
XBACKEND=$(echo "$HEADERS" | grep -i 'x-backend' | tr -d '\r' || echo "")
XEDGE=$(echo "$HEADERS" | grep -i 'x-edge' | tr -d '\r' || echo "")
echo "    HTTP status: $HTTP_CODE"
echo "    $XBACKEND"
echo "    $XEDGE"

if [ "$HTTP_CODE" = "502" ]; then
    fail "502 Bad Gateway — all backends refused"
    echo "FIRST FAILING LAYER: 6 (HTTP)"
    echo "Likely cause: both backends down or pf blocking edge"
    exit 1
elif [ "$HTTP_CODE" = "504" ]; then
    fail "504 Gateway Timeout — upstream timeout"
    echo "FIRST FAILING LAYER: 6 (HTTP)"
    exit 1
elif [ "$HTTP_CODE" != "200" ]; then
    fail "HTTP $HTTP_CODE — unexpected status"
    echo "FIRST FAILING LAYER: 6 (HTTP)"
    exit 1
fi
pass "HTTP 200 from edge"
echo ""

# --- Layer 7: Load balancing ---
echo "--- Layer 7: Load balancing (6 requests) ---"
A_COUNT=0; B_COUNT=0
for i in $(seq 1 6); do
    B=$(curl -sI "https://${DOMAIN}:${HTTPS_PORT}/api/status" 2>/dev/null \
        | grep -i 'x-backend' | awk '{print $2}' | tr -d '\r')
    echo "    Request $i: Backend $B"
    [ "$B" = "A" ] && A_COUNT=$((A_COUNT+1))
    [ "$B" = "B" ] && B_COUNT=$((B_COUNT+1))
done
echo "    A=$A_COUNT  B=$B_COUNT"
if [ $A_COUNT -gt 0 ] && [ $B_COUNT -gt 0 ]; then
    pass "Both backends responding — load balancing OK"
elif [ $A_COUNT -eq 0 ]; then
    warn "Backend A not responding — may be down or blocked by pf"
elif [ $B_COUNT -eq 0 ]; then
    warn "Backend B not responding — may be down or blocked by pf"
fi
echo ""

# --- Layer 8: Direct backend reachability (from edge only) ---
echo "--- Layer 8: Direct backend ports (run from Mac 2 for best info) ---"
echo "    nc -vz ${MAC3_IP} 3001 ..."
nc -vz -G 3 "${MAC3_IP}" 3001 2>&1 | head -1 || true
echo "    nc -vz ${MAC4_IP} 3002 ..."
nc -vz -G 3 "${MAC4_IP}" 3002 2>&1 | head -1 || true
echo ""

echo -e "${GREEN}===== ALL LAYERS PASSED =====${NC}"
echo "System appears healthy end-to-end."
