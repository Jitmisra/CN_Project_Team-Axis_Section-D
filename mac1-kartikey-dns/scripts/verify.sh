#!/usr/bin/env bash
# Task B step 6-7: prove the name resolves to Mac 2 and the app is reached BY NAME.
#   ./verify.sh [evidence-subdir]   (default phase1)
source "$(dirname "$0")/common.sh"
need MAC1_IP MAC2_IP
f="${1:-phase1}/B-verify-$(hostname -s)-$STAMP.txt"
ev "$f" networksetup -getdnsservers "$NETSVC"
ev "$f" dig "$APP"                         # uses the resolver from /etc/resolv.conf
ev "$f" dig @"$MAC1_IP" "$API" +noall +answer +comments
ev "$f" nslookup "$APP"
ev "$f" dscacheutil -q host -a name "$APP"  # what the OS (browser, curl) actually uses
ev "$f" dig +short @"$MAC1_IP" example.com  # upstream forwarding still works
note "End-to-end by name (needs Mac 2 + backends up)"
url="https://$APP"; [[ "$HTTPS_PORT" == 443 ]] || url="$url:$HTTPS_PORT"
for i in 1 2 3 4; do ev "$f" curl -sS -i --max-time 5 "$url/api/status"; done   # no -k: Mac 2 cert trusted (certs/)
echo; echo "Saved -> evidence/$f"
