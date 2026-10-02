#!/usr/bin/env bash
# Fill the templates with team.env values -> build/, then syntax-check them.
source "$(dirname "$0")/common.sh"
need TEAM MAC1_IP MAC2_IP UPSTREAM_DNS
render() { sed -e "s/@TEAM@/$TEAM/g" -e "s/@MAC1_IP@/$MAC1_IP/g" -e "s/@MAC2_IP@/$MAC2_IP/g" \
               -e "s/@MAC4_IP@/${MAC4_IP:-MAC4_IP_HERE}/g" -e "s/@UPSTREAM_DNS@/$UPSTREAM_DNS/g" "$1" > "$2"; }
render "$ROOT/config/dnsmasq-mac1.conf.tmpl"        "$ROOT/build/cnteam.conf"
render "$ROOT/config/dnsmasq-mac4-backup.conf.tmpl" "$ROOT/build/dnsmasq-mac4-backup.conf"
cp "$ROOT/config/ttl.conf" "$ROOT/build/ttl.conf"
for f in cnteam.conf dnsmasq-mac4-backup.conf; do
  printf '%-28s ' "$f"; dnsmasq --test -C "$ROOT/build/$f"
done
echo "Rendered into $ROOT/build/"
