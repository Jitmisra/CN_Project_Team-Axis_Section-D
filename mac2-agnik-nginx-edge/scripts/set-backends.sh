#!/usr/bin/env bash
# Update the backend IPs nginx uses, then re-render and restart nginx.
# Usage: ./scripts/set-backends.sh <BACKEND_A_IP> <BACKEND_B_IP>
set -euo pipefail
cd "$(dirname "$0")/.."
[ $# -eq 2 ] || { echo "Usage: $0 <BACKEND_A_IP> <BACKEND_B_IP>"; exit 1; }
sed -i '' -E "s/^MAC3_BACKEND_A_IP=\"[^\"]*\"/MAC3_BACKEND_A_IP=\"$1\"/; s/^MAC4_BACKEND_B_IP=\"[^\"]*\"/MAC4_BACKEND_B_IP=\"$2\"/" team.env
grep -E "^MAC[34]_" team.env
./scripts/d-install-nginx.sh
