#!/usr/bin/env bash
# Task A: record this Mac's network identity + print its row for the shared IP table.
source "$(dirname "$0")/common.sh"
f=phase1/A-netinfo-$(hostname -s).txt
ev "$f" ipconfig getifaddr "$IFACE"
ev "$f" ifconfig "$IFACE"
ev "$f" netstat -nr -f inet
ev "$f" networksetup -getdnsservers "$NETSVC"
ev "$f" networksetup -getsearchdomains "$NETSVC"
ip=$(ipconfig getifaddr "$IFACE")
mask=$(ipconfig getoption "$IFACE" subnet_mask)
prefix=$(awk -F. '{n=0; for(i=1;i<=4;i++){x=$i; while(x){n+=x%2; x=int(x/2)}} print n}' <<<"$mask")
gw=$(route -n get default | awk '/gateway/{print $2}')
mac=$(ifconfig "$IFACE" | awk '/ether/{print $2}')
note "Shared IP table row:"
echo "| Mac 1 | DNS | $ip | $mask (/$prefix) | $gw | $IFACE | $mac |" | tee -a "$ROOT/evidence/$f"
