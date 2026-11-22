#!/usr/bin/env bash
# ONE-TIME (run with your password):  sudo ./scripts/setup-sudo-rules.sh
# Lets the demo scripts (and Claude Code, which can't type a password) run ONLY these exact root
# commands without a password: restart/stop/start the dnsmasq LaunchDaemon, flush mDNSResponder.
# Nothing else gets passwordless root. Remove after the course:  sudo rm /etc/sudoers.d/cnteam-demo
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run with: sudo $0"; exit 1; }
u="${SUDO_USER:?run via sudo}"
tmp="$(mktemp)"
cat > "$tmp" <<RULES
# CN project demo (Mac 1 DNS) -- remove after the course: sudo rm /etc/sudoers.d/cnteam-demo
Defaults:$u verifypw=any
$u ALL=(root) NOPASSWD: /bin/launchctl kickstart -k system/sh.brew.dnsmasq, \\
    /bin/launchctl bootout system/sh.brew.dnsmasq, \\
    /bin/launchctl bootstrap system /Library/LaunchDaemons/sh.brew.dnsmasq.plist, \\
    /usr/bin/killall -HUP mDNSResponder, \\
    /usr/bin/dscacheutil -flushcache
RULES
visudo -c -f "$tmp"
install -m 0440 -o root -g wheel "$tmp" /etc/sudoers.d/cnteam-demo; rm -f "$tmp"
echo "Installed /etc/sudoers.d/cnteam-demo for $u"
