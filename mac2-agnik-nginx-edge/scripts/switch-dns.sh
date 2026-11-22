#!/usr/bin/env bash
# Point this Mac's Wi-Fi DNS at the team DNS servers, keeping the ORIGINAL setting for revert.
#   ./scripts/switch-dns.sh set       -> Mac 1 only           (Ext B TTL demo: one variable)
#   ./scripts/switch-dns.sh both      -> Mac 1, then Mac 4    (Ext A backup DNS, normal Phase 2)
#   ./scripts/switch-dns.sh revert    -> restore the setting from before Phase 1
#   ./scripts/switch-dns.sh show
# The backup is written only ONCE (first run), so repeated set/both calls never overwrite the
# true original with a team setting.
set -euo pipefail
cd "$(dirname "$0")/.."
source team.env
mkdir -p evidence
SERVICE="Wi-Fi"
BACKUP="evidence/mac2-dns-original.txt"

flush() { sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder || true; }
save_original() {
  if [ -f "$BACKUP" ]; then echo "Original already saved in $BACKUP: $(tr '\n' ' ' < "$BACKUP")"
  else networksetup -getdnsservers "$SERVICE" > "$BACKUP"; echo "Saved original to $BACKUP"; fi
}
show() { echo "DNS on $SERVICE: $(networksetup -getdnsservers "$SERVICE" | tr '\n' ' ')"; scutil --dns | awk '/resolver #1/{f=1} /resolver #2/{exit} f && /nameserver/'; }

case "${1:-}" in
  set)
    : "${MAC1_DNS_IP:?MAC1_DNS_IP is empty in team.env}"
    save_original
    sudo networksetup -setdnsservers "$SERVICE" "$MAC1_DNS_IP"; flush; show ;;
  both)
    : "${MAC1_DNS_IP:?MAC1_DNS_IP is empty in team.env}"; : "${MAC4_BACKEND_B_IP:?MAC4_BACKEND_B_IP is empty}"
    save_original
    sudo networksetup -setdnsservers "$SERVICE" "$MAC1_DNS_IP" "$MAC4_BACKEND_B_IP"; flush; show ;;
  revert)
    [ -f "$BACKUP" ] || { echo "No backup at $BACKUP - nothing to revert."; exit 1; }
    ORIGINAL="$(cat "$BACKUP")"
    if [[ "$ORIGINAL" == "There aren't any DNS Servers set on"* ]]; then
      sudo networksetup -setdnsservers "$SERVICE" "Empty"
    else
      # shellcheck disable=SC2086
      sudo networksetup -setdnsservers "$SERVICE" $ORIGINAL
    fi
    flush; show ;;
  show) show ;;
  *) echo "Usage: $0 {set|both|revert|show}"; exit 1 ;;
esac
