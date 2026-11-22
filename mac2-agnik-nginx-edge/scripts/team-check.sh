#!/usr/bin/env bash
# One-shot status of all 4 machines' Phase 2 pieces, run from Mac 2. Re-run any time.
#   ./scripts/team-check.sh        (uses team.env IPs, saves to evidence/phase2/team-check-*.txt)
set -uo pipefail
cd "$(dirname "$0")/.."
source team.env
M1="$MAC1_DNS_IP"; M3="$MAC3_BACKEND_A_IP"; M4="$MAC4_BACKEND_B_IP"; D="$TEAM_DOMAIN"
WANT_ETAG='"39464b4ed106dad1"'      # /api/info ETag from the shared code: identical on A and B
mkdir -p evidence/phase2; OUT="evidence/phase2/team-check-$(date +%Y%m%d-%H%M%S).txt"
ok()  { printf '  [ OK ] %s\n' "$*"; }
bad() { printf '  [FAIL] %s\n' "$*"; }
todo(){ printf '  [TODO] %s\n' "$*"; }
ping1() { ping -c2 -t3 "$1" >/dev/null 2>&1; }
dns()  { dig +time=2 +tries=1 +short @"$1" "$2" 2>/dev/null | grep -E '^[0-9.]+$' | head -1; }
ttl()  { dig +time=2 +tries=1 +noall +answer @"$1" "$2" 2>/dev/null | awk '{print $2; exit}'; }
hdr()  { awk -v h="$2" 'tolower($1)==h":"{print $2; exit}' <<<"$1" | tr -d '\r'; }

dns_server() { # name ip
  local a; a="$(dns "$2" "app.$D")"
  if [ -z "$a" ]; then bad "$1 DNS @$2: no answer (dnsmasq not running / not listening on this IP)"
  elif [ "$a" = "$MAC2_EDGE_IP" ]; then ok "$1 DNS @$2: app.$D -> $a, TTL $(ttl "$2" "app.$D")  (api -> $(dns "$2" "api.$D"))"
  else bad "$1 DNS @$2: app.$D -> $a, but Mac 2 is $MAC2_EDGE_IP (stale record)"; fi
}
backend() { # name ip port id
  if ! nc -z -G 3 "$2" "$3" 2>/dev/null; then bad "Backend $4 $2:$3: connection refused/timeout (not running, or pf blocks Mac 2)"; return; fi
  local s i h; s="$(curl -s -m 4 -D - -o /dev/null "http://$2:$3/api/status")"
  [ "$(hdr "$s" x-backend)" = "$4" ] && ok "Backend $4 $2:$3 up, X-Backend: $4, $(hdr "$s" cache-control)" || bad "Backend $4: unexpected response: $(head -1 <<<"$s")"
  h="$(curl -s -m 4 -I "http://$2:$3/" | head -1 | tr -d '\r')"
  [[ "$h" == *" 200"* ]] && ok "Backend $4 HEAD / -> $h" || bad "Backend $4 HEAD / -> ${h:-no answer} (needs do_HEAD)"
  i="$(curl -s -m 4 -I "http://$2:$3/api/info")"
  if [ "$(hdr "$i" etag)" = "$WANT_ETAG" ]; then ok "Backend $4 /api/info ETag $WANT_ETAG (matches shared code)"
  elif [ -n "$(hdr "$i" etag)" ]; then bad "Backend $4 /api/info ETag $(hdr "$i" etag) != $WANT_ETAG (SHARED_INFO differs)"
  else todo "Backend $4 /api/info + ETag not added yet"; fi
}

{
echo "# team check from Mac 2 ($(ipconfig getifaddr en0)) at $(date '+%F %T')"
echo "== LAN"
for p in "Mac1 Kartikey:$M1" "Mac3 Vishuti:$M3" "Mac4 Anwesha:$M4"; do
  ping1 "${p#*:}" && ok "${p%%:*} ${p#*:} reachable" || bad "${p%%:*} ${p#*:} NOT reachable (IP changed? off Wi-Fi?)"
done
echo "== DNS (Ext A: both must answer identically)"
dns_server "Mac1 primary" "$M1"
dns_server "Mac4 backup " "$M4"
a1="$(dns "$M1" "app.$D")"; a4="$(dns "$M4" "app.$D")"
[ -n "$a1" ] && [ -n "$a4" ] && { [ "$a1" = "$a4" ] && ok "primary and backup agree" || bad "primary ($a1) and backup ($a4) DISAGREE"; }
echo "== Backends"
backend "Mac3" "$M3" "$BACKEND_A_PORT" A
backend "Mac4" "$M4" "$BACKEND_B_PORT" B
echo "== Edge (Mac 2), name pinned to $MAC2_EDGE_IP, cert verified"
seq_be=""; for i in 1 2 3 4 5 6; do
  r="$(curl -s -m 5 --resolve "app.$D:$EDGE_HTTPS_PORT:$MAC2_EDGE_IP" -D - -o /dev/null "https://app.$D:$EDGE_HTTPS_PORT/api/status")"
  seq_be+="$(head -1 <<<"$r" | awk '{print $2}' | tr -d '\r')/$(hdr "$r" x-backend) "; done
[[ "$seq_be" == *"/A"* && "$seq_be" == *"/B"* ]] && ok "load balancing A+B: $seq_be" || bad "not balancing across both: $seq_be"
echo "== Standby edge on Mac 3 (Ext E)"
if nc -z -G 2 "$M3" "$EDGE_HTTPS_PORT" 2>/dev/null; then
  e="$(curl -s -m 5 --resolve "app.$D:$EDGE_HTTPS_PORT:$M3" -D - -o /dev/null "https://app.$D:$EDGE_HTTPS_PORT/api/status")"
  ok "standby answers: $(head -1 <<<"$e" | tr -d '\r'), X-Edge: $(hdr "$e" x-edge), X-Backend: $(hdr "$e" x-backend)"
else todo "standby nginx not running on $M3:$EDGE_HTTPS_PORT yet"; fi
echo "== This Mac's resolvers"
r="$(networksetup -getdnsservers Wi-Fi | tr '\n' ' ')"
[[ "$r" == *"$M1"* && "$r" == *"$M4"* ]] && ok "Wi-Fi DNS: $r" || todo "Wi-Fi DNS is '$r' -> run ./scripts/switch-dns.sh both once Mac 1 + Mac 4 DNS answer"
} 2>&1 | tee "$OUT"
echo "Saved to $OUT"
