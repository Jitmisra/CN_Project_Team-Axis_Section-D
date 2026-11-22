#!/usr/bin/env bash
# Phase 2, Extension E: DNS-based edge migration (standby nginx on Mac 3).
#   ./cutover.sh STANDBY_IP | standby   point app.<team>.test at the standby edge (standby = MAC3_IP)
#   ./cutover.sh back                   point it back at Mac 2
# BOTH DNS servers must change: Anwesha runs, at the same moment, on Mac 4:
#   backend_b/scripts/dns-backup.sh set-record app.cnteam.test <same IP>
# Two servers giving different answers makes clients flip randomly between edges.
# With TTL 30 on both, clients that cached the old answer keep hitting the old edge for up to 30 s;
# fresh lookups go to the new one. Watch it with ./scripts/watch-edge.sh (or tools/watch.sh).
#   NO_MIRROR_WAIT=1 ./cutover.sh ...   don't wait for Mac 4 to match
source "$(dirname "$0")/common.sh"
need MAC1_IP MAC2_IP MAC4_IP
check_mac1_ip
target="${1:?usage: cutover.sh STANDBY_IP | standby | back}"
case "$target" in back) target="$MAC2_IP" ;; standby) need MAC3_IP; target="$MAC3_IP" ;; esac
f=phase2/E-cutover-$STAMP.txt
ttl="$(ttl_on_wire "$APP")"
[[ "$ttl" == 30 ]] || echo "!! Mac 1 TTL on the wire is '$ttl', expected 30 -- run ./install-dns.sh --ttl (the TTL story needs it)"
ev "$f" dig +noall +answer @"$MAC1_IP" "$APP"
ev "$f" dig +noall +answer @"$MAC4_IP" "$APP"
set_record "$APP" "$target"
t0="$(date +%T)"
ev "$f" grep "^address=" "$LIVE_CONF"
ev "$f" dig +noall +answer @"$MAC1_IP" "$APP"
echo "Cut over $APP -> $target on Mac 1 at $t0. Note the time for the TTL story." | tee -a "$ROOT/evidence/$f"

cat <<EOF

  ############################################################################
  #  MIRROR NOW on Mac 4 (Anwesha):                                          #
     backend_b/scripts/dns-backup.sh set-record $APP $target
  ############################################################################
EOF
if [[ -z "${NO_MIRROR_WAIT:-}" ]]; then
  echo "Waiting up to 60 s for Mac 4 to give the same answer..."
  for _ in $(seq 1 30); do
    [[ "$(ask "$MAC4_IP" "$APP")" == "$target" ]] && break; sleep 2
  done
fi
compare_servers "$APP" | tee -a "$ROOT/evidence/$f" \
  && echo "[$(date +%T)] both DNS servers agree: $APP -> $target" | tee -a "$ROOT/evidence/$f" \
  || echo "!! Mac 4 still differs -- clients may flip randomly until Anwesha mirrors it" | tee -a "$ROOT/evidence/$f"
echo; echo "Saved -> evidence/$f"
