#!/usr/bin/env bash
# Phase 2, Extension C: Mac 1 is the "outside client". Backend ports must be blocked for us,
# while the app through the edge (by name, TLS) still works. No sudo.
#   ./c-client-blocked.sh [before|after|restored]   (label only; default after)
# Run 'before' before pf is enabled (bypass works = the problem), 'after' with pf on, 'restored' after rollback.
source "$(dirname "$0")/common.sh"
need MAC3_IP MAC4_IP
phase="${1:-after}"; f=phase2/C-client-blocked.txt
echo -e "\n######## $phase -- $(date '+%F %T') on $(hostname -s) ($MAC1_IP) ########" | tee -a "$ROOT/evidence/$f"
ev "$f" nc -vz -G 3 "$MAC3_IP" 3001
ev "$f" nc -vz -G 3 "$MAC4_IP" 3002
ev "$f" curl -sS -i -m 5 "http://$MAC3_IP:3001/api/status"
ev "$f" curl -sS -i -m 5 "http://$MAC4_IP:3002/api/status"
note "The supported path (edge) must still work"
for i in 1 2; do ev "$f" curl -sS -i -m 5 "https://$APP:$HTTPS_PORT/api/status"; done
echo "Expected '$phase': $([[ $phase == after ]] && echo 'direct = refused/timeout, edge = 200 alternating A/B' || echo 'direct = 200, edge = 200')" | tee -a "$ROOT/evidence/$f"
echo "  (refused = pf 'block return' sends RST; timeout = 'block drop' silently discards)" | tee -a "$ROOT/evidence/$f"
