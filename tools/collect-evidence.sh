#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p backend_b/evidence/phase1 backend_b/evidence/phase2

echo "=== 1. Capturing Backup DNS Dig ==="
dig @10.7.19.42 app.cnteam.test +noall +answer > backend_b/evidence/phase2/A-backup-dns-dig.txt 2>&1 || true
cat backend_b/evidence/phase2/A-backup-dns-dig.txt

echo "=== 2. Capturing ETag & 304 on Backend B ==="
{
  echo "=== Backend B ETag & 304 Verification ==="
  curl -sI http://127.0.0.1:3002/api/info
  echo ""
  curl -sI -H 'If-None-Match: "39464b4ed106dad1"' http://127.0.0.1:3002/api/info
} > backend_b/evidence/phase2/F-caching-304-B.txt 2>&1
cat backend_b/evidence/phase2/F-caching-304-B.txt

echo "=== 3. Capturing Phase 1 Demo #5 (Wrong Port) ==="
{
  echo "=== Phase 1 Demo #5: Wrong Destination Port ==="
  echo "--- Ping Mac 2 (10.7.3.251) ---"
  ping -c 2 10.7.3.251 2>&1 || echo "Ping failed (check if Mac 2 is on)"
  echo ""
  echo "--- Try wrong port 9999 (Connection refused) ---"
  nc -vz -G 2 10.7.3.251 9999 2>&1 || true
  echo ""
  echo "--- Try correct port 8443 (Succeeded) ---"
  nc -vz -G 2 10.7.3.251 8443 2>&1 || true
} > backend_b/evidence/phase1/F5-wrong-port.txt 2>&1
cat backend_b/evidence/phase1/F5-wrong-port.txt

echo ""
echo "=== 4. Running System Diagnosis (Ext F) ==="
./tools/diagnose.sh > backend_b/evidence/phase2/F-diagnose-healthy.txt 2>&1 || true
tail -n 12 backend_b/evidence/phase2/F-diagnose-healthy.txt || true

echo ""
echo "All evidence captured successfully in backend_b/evidence/!"
