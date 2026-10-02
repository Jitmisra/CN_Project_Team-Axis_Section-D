#!/usr/bin/env bash
# No-sudo dry run: start the rendered config on 127.0.0.1:5300 and query it.
source "$(dirname "$0")/common.sh"
"$ROOT/scripts/render.sh" >/dev/null
tmp="$(mktemp -d)"
sed -E -e 's/^listen-address=.*/listen-address=127.0.0.1/' -e "s|^log-facility=.*|log-facility=$tmp/q.log|" \
  "$ROOT/build/cnteam.conf" > "$tmp/t.conf"
printf 'port=5300\npid-file=\n' >> "$tmp/t.conf"
dnsmasq -k -C "$tmp/t.conf" & pid=$!; trap 'kill $pid 2>/dev/null; rm -rf "$tmp"' EXIT; sleep 1
fail=0
for n in "$APP" "$API"; do
  got="$(dig @127.0.0.1 -p 5300 +short "$n")"
  [[ "$got" == "$MAC2_IP" ]] && echo "PASS $n -> $got" || { echo "FAIL $n -> '$got' (want $MAC2_IP)"; fail=1; }
done
up="$(dig @127.0.0.1 -p 5300 +short example.com | head -1)"
[[ -n "$up" ]] && echo "PASS upstream forwarding (example.com -> $up)" || { echo "FAIL upstream forwarding"; fail=1; }
exit $fail
