#!/usr/bin/env bash
# a-ping.sh — Ping all team machines
set -euo pipefail
cd "$(dirname "$0")/.."
source team.env

echo "=== Pinging all team machines from Mac 4 ==="
for PAIR in "Mac1:${MAC1_IP}" "Mac2:${MAC2_IP}" "Mac3:${MAC3_IP}" "Mac4:${MAC4_IP}"; do
    NAME="${PAIR%%:*}"
    IP="${PAIR##*:}"
    echo -n "$NAME ($IP): "
    if ping -c1 -W2 "$IP" >/dev/null 2>&1; then
        echo "OK"
    else
        echo "UNREACHABLE"
    fi
done
