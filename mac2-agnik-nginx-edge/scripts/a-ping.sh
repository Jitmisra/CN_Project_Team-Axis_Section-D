#!/usr/bin/env bash
# Task A - ping teammates once their IPs are in team.env.
set -euo pipefail
cd "$(dirname "$0")/.."
source team.env
mkdir -p evidence
OUT="evidence/ping-results.txt"
: > "$OUT"

check() {
  local name="$1" ip="$2"
  if [ -z "$ip" ]; then
    echo "[$name] SKIPPED - no IP in team.env yet" | tee -a "$OUT"
    return
  fi
  echo "=== $name ($ip) ===" | tee -a "$OUT"
  if ping -c 3 -t 3 "$ip" >> "$OUT" 2>&1; then
    echo "[$name] OK" | tee -a "$OUT"
  else
    echo "[$name] FAILED - unreachable. If this is a campus Wi-Fi, laptop-to-laptop" \
         "traffic may be blocked; switch all 4 Macs to a phone hotspot." | tee -a "$OUT"
  fi
}

check "Mac1 (Kartikey/DNS)"      "$MAC1_DNS_IP"
check "Mac3 (Vishuti/Backend A)" "$MAC3_BACKEND_A_IP"
check "Mac4 (Anwesha/Backend B)" "$MAC4_BACKEND_B_IP"

echo "Results saved to $OUT"
