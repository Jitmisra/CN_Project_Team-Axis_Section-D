#!/usr/bin/env bash
# Phase 1 failure demo 1: client points at a WRONG DNS server.
# Expect: every name lookup fails, but raw-IP connectivity to Mac 2 still works
# => DNS (name -> IP) and IP reachability are independent layers.
source "$(dirname "$0")/common.sh"
need MAC2_IP BOGUS_DNS
f=phase1/F1-wrong-resolver-$STAMP.txt
before="$(networksetup -getdnsservers "$NETSVC" | tr '\n' ' ')"
restore() { note "Restoring resolvers: $before"
  if [[ "$before" == *"aren't any"* ]]; then sudo networksetup -setdnsservers "$NETSVC" Empty
  else sudo networksetup -setdnsservers "$NETSVC" $before; fi; flush_cache; }
trap restore EXIT
note "BEFORE"; ev "$f" networksetup -getdnsservers "$NETSVC"; ev "$f" dig +short "$APP"
note "BREAK: resolver -> $BOGUS_DNS (not a DNS server)"
sudo networksetup -setdnsservers "$NETSVC" "$BOGUS_DNS"; flush_cache
ev "$f" networksetup -getdnsservers "$NETSVC"
ev "$f" dig +time=2 +tries=1 "$APP"           # ;; connection timed out; no servers could be reached
ev "$f" nslookup -timeout=2 "$APP"
ev "$f" dig +time=2 +tries=1 +short google.com # ALL names fail, not just ours
note "But the IP layer is fine:"
ev "$f" ping -c 3 "$MAC2_IP"
ev "$f" curl -sS -k -o /dev/null -w 'HTTPS to raw IP: %{http_code}\n' --max-time 5 "https://$MAC2_IP:$HTTPS_PORT/"
echo; echo "Saved -> evidence/$f   (screenshot this terminal too)"
