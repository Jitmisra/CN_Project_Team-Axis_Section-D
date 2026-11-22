#!/usr/bin/env bash
# dns-backup.sh — Manage backup DNS on Mac 4
# Usage: dns-backup.sh {install|status|set-record <name> <ip>|sync-check}
set -euo pipefail
cd "$(dirname "$0")/.."
source team.env

CONF="/opt/homebrew/etc/dnsmasq.d/cnteam.conf"
LOG="/opt/homebrew/var/log/dnsmasq-cnteam.log"

case "${1:-help}" in

install)
    echo "=== Installing backup DNS on Mac 4 ==="
    # dnsmasq must already be installed: brew install dnsmasq
    which dnsmasq >/dev/null || { echo "Run: brew install dnsmasq"; exit 1; }

    # Ensure conf-dir line exists
    grep -q '^conf-dir=/opt/homebrew/etc/dnsmasq.d' /opt/homebrew/etc/dnsmasq.conf 2>/dev/null \
      || echo 'conf-dir=/opt/homebrew/etc/dnsmasq.d,*.conf' >> /opt/homebrew/etc/dnsmasq.conf

    mkdir -p /opt/homebrew/etc/dnsmasq.d /opt/homebrew/var/log

    # Write config — use interface=en0 (auto-adds loopback, no bind-interfaces needed)
    cat > "$CONF" <<EOF
# ==== CN project -- BACKUP private DNS (Mac 4, Anwesha) ====
# Records MUST be identical to Mac 1's primary.
address=/app.${TEAM}.test/${MAC2_IP}
address=/api.${TEAM}.test/${MAC2_IP}
interface=en0
no-resolv
server=${UPSTREAM_DNS}
no-hosts
local-ttl=30
log-queries
log-facility=${LOG}
EOF

    echo "Config written to $CONF"
    cat "$CONF"
    echo ""
    dnsmasq --test && echo "[OK] Config valid"
    echo ""
    echo ">>> NOW RUN: sudo brew services start dnsmasq"
    echo ">>> Then verify: dig @127.0.0.1 app.${TEAM}.test +short"
    echo ">>>              dig @${MAC4_IP} app.${TEAM}.test +short"
    ;;

status)
    echo "=== Backup DNS Status ==="
    if pgrep -x dnsmasq >/dev/null; then
        echo "[OK] dnsmasq is running (PID $(pgrep -x dnsmasq))"
    else
        echo "[!!] dnsmasq NOT running"
    fi
    echo ""
    echo "--- Config ---"
    [ -f "$CONF" ] && cat "$CONF" || echo "(no config at $CONF)"
    echo ""
    echo "--- Test queries ---"
    dig @127.0.0.1 app.${TEAM}.test +short 2>/dev/null || echo "(query failed)"
    dig @${MAC4_IP} app.${TEAM}.test +short 2>/dev/null || echo "(query failed)"
    ;;

set-record)
    # Usage: dns-backup.sh set-record app.cnteam.test 10.7.x.x
    NAME="${2:?Usage: dns-backup.sh set-record <name> <ip>}"
    IP="${3:?Usage: dns-backup.sh set-record <name> <ip>}"
    echo "Updating $NAME -> $IP in $CONF"
    sed -i '' "s|address=/${NAME}/.*|address=/${NAME}/${IP}|" "$CONF"
    grep "$NAME" "$CONF"
    echo ">>> NOW RUN: sudo brew services restart dnsmasq"
    ;;

sync-check)
    echo "=== Checking Mac 1 vs Mac 4 DNS answers ==="
    FAIL=0
    for NAME in app.${TEAM}.test api.${TEAM}.test; do
        A1=$(dig @${MAC1_IP} "$NAME" +short 2>/dev/null || echo "TIMEOUT")
        A4=$(dig @${MAC4_IP} "$NAME" +short 2>/dev/null || echo "TIMEOUT")
        if [ "$A1" = "$A4" ]; then
            echo "[OK] $NAME  Mac1=$A1  Mac4=$A4"
        else
            echo "[!!] MISMATCH $NAME  Mac1=$A1  Mac4=$A4"
            FAIL=1
        fi
    done
    [ $FAIL -eq 0 ] && echo "All records match." || echo "FIX THE MISMATCH before demos!"
    ;;

*)
    echo "Usage: dns-backup.sh {install|status|set-record <name> <ip>|sync-check}"
    ;;
esac
