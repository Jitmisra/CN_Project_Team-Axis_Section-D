#!/usr/bin/env bash
# Phase 1 failure demo 2: the A record points at the WRONG IP.
# Expect: resolution SUCCEEDS (NOERROR, an answer), but the client lands on the wrong host
# => DNS is a directory lookup, not a connection; it happily returns a wrong address.
#   ./demo-wrong-record.sh [WRONG_IP]   (default: Mac 3 -- a real host that is not the edge)
source "$(dirname "$0")/common.sh"
need MAC2_IP
wrong="${1:-${MAC3_IP:-192.0.2.99}}"
f=phase1/F2-wrong-record-$STAMP.txt
url="https://$APP:$HTTPS_PORT/api/status"
trap 'note "REVERT $APP -> $MAC2_IP"; set_record "$APP" "$MAC2_IP"; flush_cache; ev "$f" dig +short @"$MAC1_IP" "$APP"' EXIT
note "BEFORE"; ev "$f" dig @"$MAC1_IP" "$APP" +noall +answer +comments
ev "$f" curl -sS -k -i --max-time 5 "$url"
note "BREAK: $APP -> $wrong"; set_record "$APP" "$wrong"; flush_cache
ev "$f" grep "^address=" "$LIVE_CONF"
ev "$f" dig @"$MAC1_IP" "$APP" +noall +answer +comments   # status: NOERROR, wrong IP
ev "$f" curl -sS -k -i --max-time 5 "$url"                # refused / timeout / wrong service
ev "$f" dig +short @"$MAC1_IP" "$API"                     # untouched record still fine
echo; echo "Saved -> evidence/$f"
