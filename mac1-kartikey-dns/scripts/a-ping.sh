#!/usr/bin/env bash
# Task A: ping every teammate. Nothing downstream works until all of these pass.
source "$(dirname "$0")/common.sh"
need MAC2_IP MAC3_IP MAC4_IP
ok=1
for pair in "Mac2:$MAC2_IP" "Mac3:$MAC3_IP" "Mac4:$MAC4_IP"; do
  ev phase1/A-ping.txt ping -c 4 "${pair#*:}" | grep -q ' 0.0% packet loss' && echo "PASS ${pair%%:*}" || { echo "FAIL ${pair%%:*} (${pair#*:})"; ok=0; }
done
(( ok )) || echo "!! Some pings failed. On big campus Wi-Fi, 'client isolation' often blocks laptop-to-laptop traffic -- switch to a phone hotspot all 4 Macs join."
