#!/usr/bin/env bash
# Task B: install the rendered config into the live dnsmasq and (re)start it.
#   ./install-dns.sh            Phase 1 config (TTL 0)
#   ./install-dns.sh --ttl      also install ttl.conf (Phase 2, Ext B: TTL 30s)
#   ./install-dns.sh --no-ttl   remove ttl.conf again
source "$(dirname "$0")/common.sh"
check_mac1_ip
"$ROOT/scripts/render.sh"
# Retire the earlier placeholder config (zone cn.test, all records -> this Mac).
[[ -f "$DNSMASQ_D/cn.conf" ]] && mv "$DNSMASQ_D/cn.conf" "$DNSMASQ_D/cn.conf.disabled-$STAMP" && echo "Moved old cn.conf aside"
[[ -f "$LIVE_CONF" ]] && cp "$LIVE_CONF" "$ROOT/build/cnteam.conf.prev-$STAMP"
cp "$ROOT/build/cnteam.conf" "$LIVE_CONF"
case "${1:-}" in
  --ttl)    cp "$ROOT/build/ttl.conf" "$DNSMASQ_D/ttl.conf"; echo "TTL 30s enabled" ;;
  --no-ttl) rm -f "$DNSMASQ_D/ttl.conf"; echo "TTL back to 0" ;;
esac
dnsmasq --test -C /opt/homebrew/etc/dnsmasq.conf -7 "$DNSMASQ_D,*.conf"
note "Restarting dnsmasq (needs sudo: port 53 is privileged)"
restart_dns
dns_status
dig +short +time=2 +tries=1 @127.0.0.1 "$APP" | grep -qE '^[0-9.]+$' || { echo "!! dnsmasq is not answering on UDP 53"; exit 1; }
for n in "$APP" "$API"; do
  printf '%-22s via 127.0.0.1 -> %-15s via %s -> %s\n' "$n" "$(dig +short @127.0.0.1 "$n")" "$MAC1_IP" "$(dig +short @"$MAC1_IP" "$n")"
done
printf '%-22s TTL on the wire: %s s   (0 = Phase 1, no caching; 30 = Ext B)\n' "$APP" "$(ttl_on_wire "$APP")"
