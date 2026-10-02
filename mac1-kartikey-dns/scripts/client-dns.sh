#!/usr/bin/env bash
# Point THIS Mac's resolver at the project DNS (works on any client Mac -- copy the folder over).
#   ./client-dns.sh show            current resolvers
#   ./client-dns.sh primary         Mac 1 only                     (Phase 1)
#   ./client-dns.sh both            Mac 1 primary + Mac 4 backup    (Phase 2, Ext A)
#   ./client-dns.sh set IP [IP..]   anything else (used by the wrong-resolver demo)
#   ./client-dns.sh revert          restore what was there before the first change
source "$(dirname "$0")/common.sh"
saved="$ROOT/build/original-dns-$(hostname -s).txt"
save_once() {
  [[ -f "$saved" ]] && return
  networksetup -getdnsservers "$NETSVC" > "$saved"
  networksetup -getsearchdomains "$NETSVC" >> "$saved.search"
  echo "Saved original resolvers to $saved"
}
apply() { save_once; sudo networksetup -setdnsservers "$NETSVC" "$@"; flush_cache; }
case "${1:-show}" in
  show)    ;;
  primary) need MAC1_IP; apply "$MAC1_IP" ;;
  both)    need MAC1_IP MAC4_IP; apply "$MAC1_IP" "$MAC4_IP" ;;
  set)     shift; apply "$@" ;;
  revert)  [[ -f "$saved" ]] || { echo "Nothing saved -- nothing to revert"; exit 0; }
           if grep -q "aren't any" "$saved"; then sudo networksetup -setdnsservers "$NETSVC" Empty
           else sudo networksetup -setdnsservers "$NETSVC" $(cat "$saved"); fi
           flush_cache; rm -f "$saved" "$saved.search"; echo "Reverted" ;;
  *) sed -n '2,8p' "$0"; exit 1 ;;
esac
note "Resolvers on $NETSVC:"; networksetup -getdnsservers "$NETSVC"
scutil --dns | awk '/resolver #1/{f=1} f&&/nameserver/{print "  in use:", $3} /resolver #2/{exit}'
