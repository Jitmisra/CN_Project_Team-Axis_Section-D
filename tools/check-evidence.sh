#!/usr/bin/env bash
# tools/check-evidence.sh — Verify every file listed in EVIDENCE_INDEX.md exists
set -euo pipefail
cd "$(dirname "$0")/.."

echo "=== Checking evidence paths from EVIDENCE_INDEX.md ==="
MISSING=0
FOUND=0

grep -oE '[a-zA-Z0-9_/-]+\.(txt|pcap|pcapng|png|jpg|md)' EVIDENCE_INDEX.md | sort -u | while read -r F; do
    if [ -f "$F" ]; then
        echo "  [OK] $F"
        FOUND=$((FOUND+1))
    else
        echo "  [!!] MISSING: $F"
        MISSING=$((MISSING+1))
    fi
done

echo ""
echo "Done."
