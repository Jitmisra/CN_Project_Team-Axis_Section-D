#!/usr/bin/env bash
# Evidence: packet capture of a DNS query/response (UDP 53) for app.<team>.test.
# Writes evidence/<phase>/dns-*.pcap (open in Wireshark, filter: dns) + a decoded .txt.
# On Mac 1 a query to its own IP never touches Wi-Fi (it goes over lo0), so the capture
# interface switches automatically. The most "real" capture is this script run on Mac 4.
source "$(dirname "$0")/common.sh"
need MAC1_IP
phase="${1:-phase1}"
cap_if="$IFACE"; [[ "$(ipconfig getifaddr "$IFACE")" == "$MAC1_IP" ]] && cap_if=lo0
pcap="$ROOT/evidence/$phase/dns-$(hostname -s)-$STAMP.pcap"; mkdir -p "$(dirname "$pcap")"
sudo -v
sudo tcpdump -i "$cap_if" -U -w "$pcap" 'port 53' 2>/dev/null & cap=$!; sleep 1
flush_cache
dig @"$MAC1_IP" "$APP" +noall +answer
dscacheutil -q host -a name "$APP" >/dev/null   # an OS-level lookup too
sleep 1; sudo kill "$cap"; wait "$cap" 2>/dev/null || true
tcpdump -nn -vv -r "$pcap" 2>/dev/null | tee "${pcap%.pcap}.txt"
echo; echo "Saved $pcap (+ .txt). Look for: client high port -> $MAC1_IP.53 (UDP), A? $APP, answer A ${MAC2_IP:-<Mac2>}"
