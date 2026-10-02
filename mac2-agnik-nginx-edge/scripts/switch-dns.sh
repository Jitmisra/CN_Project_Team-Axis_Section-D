#!/usr/bin/env bash
# Point this Mac's Wi-Fi DNS resolver at Kartikey's DNS server, saving the
# original setting first so it can be restored. Usage:
#   ./scripts/switch-dns.sh set       -> point DNS at team.env's MAC1_DNS_IP
#   ./scripts/switch-dns.sh revert    -> restore whatever was configured before
set -euo pipefail
cd "$(dirname "$0")/.."
source team.env
mkdir -p evidence
SERVICE="Wi-Fi"
BACKUP="evidence/mac2-dns-original.txt"

case "${1:-}" in
  set)
    if [ -z "$MAC1_DNS_IP" ]; then
      echo "MAC1_DNS_IP is empty in team.env"; exit 1
    fi
    CURRENT="$(networksetup -getdnsservers "$SERVICE")"
    echo "$CURRENT" > "$BACKUP"
    echo "Saved original DNS setting to $BACKUP: $CURRENT"
    sudo networksetup -setdnsservers "$SERVICE" "$MAC1_DNS_IP"
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder || true
    echo "DNS on $SERVICE set to $MAC1_DNS_IP, cache flushed."
    networksetup -getdnsservers "$SERVICE"
    ;;
  revert)
    if [ ! -f "$BACKUP" ]; then
      echo "No backup found at $BACKUP - nothing to revert."; exit 1
    fi
    ORIGINAL="$(cat "$BACKUP")"
    if [ "$ORIGINAL" = "There aren't any DNS Servers set on $SERVICE." ]; then
      sudo networksetup -setdnsservers "$SERVICE" "Empty"
    else
      sudo networksetup -setdnsservers "$SERVICE" $ORIGINAL
    fi
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder || true
    echo "DNS on $SERVICE reverted."
    networksetup -getdnsservers "$SERVICE"
    ;;
  *)
    echo "Usage: $0 {set|revert}"; exit 1
    ;;
esac
