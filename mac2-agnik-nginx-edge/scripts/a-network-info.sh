#!/usr/bin/env bash
# Task A - record this Mac's network details as evidence.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p evidence
OUT="evidence/mac2-network-info.txt"

{
  echo "=== $(date) ==="
  echo "--- ipconfig getifaddr en0 ---"
  ipconfig getifaddr en0
  echo "--- ifconfig en0 ---"
  ifconfig en0
  echo "--- default route ---"
  netstat -nr | grep default
} > "$OUT"

echo "Saved to $OUT"
cat "$OUT"
