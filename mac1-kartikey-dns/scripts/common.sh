# Sourced by every script. Loads team.env and provides small helpers.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/team.env"
DNSMASQ_D=/opt/homebrew/etc/dnsmasq.d
LIVE_CONF="$DNSMASQ_D/cnteam.conf"
APP="app.$TEAM.test"
API="api.$TEAM.test"
STAMP="$(date +%Y%m%d-%H%M%S)"

need() { # need VAR... -- abort if any team.env value is blank
  for v in "$@"; do
    [[ -n "${!v:-}" ]] || { echo "!! $v is empty -- fill it in $ROOT/team.env first" >&2; exit 1; }
  done
}

# Run a command, echo it with a prompt, and append both to an evidence file.
#   ev phase1/dig.txt dig app.cnteam.test
ev() {
  local out="$ROOT/evidence/$1"; shift
  mkdir -p "$(dirname "$out")"
  { echo; echo "[$(date '+%H:%M:%S')] $(hostname -s)\$ $*"; "$@" 2>&1 || true; } | tee -a "$out"
}

note() { echo; echo "==> $*"; }

flush_cache() { dscacheutil -flushcache; sudo killall -HUP mDNSResponder; }   # killall needs root (sudo rule)

# dnsmasq runs as the root LaunchDaemon sh.brew.dnsmasq (KeepAlive). These exact commands are
# passwordless after ./scripts/setup-sudo-rules.sh. 'kill' alone would just respawn it, so stop = bootout.
DNS_SVC=system/sh.brew.dnsmasq
DNS_PLIST=/Library/LaunchDaemons/sh.brew.dnsmasq.plist
dns_stop()   { sudo launchctl bootout "$DNS_SVC" 2>/dev/null || true; sleep 1; }
dns_start()  { sudo launchctl bootstrap system "$DNS_PLIST" 2>/dev/null || sudo launchctl kickstart -k "$DNS_SVC"; sleep 1; }
dns_status() { launchctl print "$DNS_SVC" 2>/dev/null | awk '/^\tstate|^\tpid|last exit code/' || echo "  dnsmasq service not loaded (stopped)"; }

# What the OS resolver (mDNSResponder, with its cache) says -- unlike dig, which bypasses it.
os_lookup() { dscacheutil -q host -a name "$1" | awk '/ip_address/{print $2}' | head -1; }

restart_dns() { launchctl print "$DNS_SVC" >/dev/null 2>&1 && sudo launchctl kickstart -k "$DNS_SVC" || dns_start; sleep 1; }

# set_record NAME IP -- rewrite one address= line in the live config, then restart.
set_record() {
  sed -i '' -E "s|^address=/$1/.*|address=/$1/$2|" "$LIVE_CONF"
  grep -q "^address=/$1/$2\$" "$LIVE_CONF" || { echo "!! failed to set $1 -> $2" >&2; exit 1; }
  restart_dns
}

# Server-side scripts call this: abort early if DHCP gave Mac 1 a new IP since team.env was written.
check_mac1_ip() {
  local now; now="$(ipconfig getifaddr "$IFACE" 2>/dev/null || true)"
  [[ "$now" == "$MAC1_IP" ]] && return 0
  echo "!! $IFACE is '$now' but team.env says MAC1_IP=$MAC1_IP -- IP drifted." >&2
  echo "   Update MAC1_IP in team.env, re-run install-dns.sh, and tell the team (their resolver lists change)." >&2
  exit 1
}

# ttl_on_wire NAME -- the TTL column dnsmasq actually sends (0 = clients must not cache)
ttl_on_wire() { dig +noall +answer +time=2 +tries=1 @"${2:-$MAC1_IP}" "$1" | awk '$4=="A"{print $2; f=1; exit} END{if(!f) print "<no answer>"}'; }

# ask SERVER NAME -- the A record a server returns, or empty (dig +short prints errors on stdout!)
ask() { dig +short +time=2 +tries=1 @"$1" "$2" | grep -E '^[0-9]+(\.[0-9]+){3}$' | head -1 || true; }

# Mac 4 (backup) answer vs Mac 1 (primary) answer for a name; prints both, returns 1 if they differ.
compare_servers() {
  local p b; p="$(ask "$MAC1_IP" "$1")"; b="$(ask "$MAC4_IP" "$1")"
  printf '%-18s Mac1(%s)=%-15s Mac4(%s)=%-15s %s\n' "$1" "$MAC1_IP" "${p:-<none>}" "$MAC4_IP" "${b:-<none>}" \
    "$([[ -n "$p" && "$p" == "$b" ]] && echo OK || echo '<-- MISMATCH')"
  [[ -n "$p" && "$p" == "$b" ]]
}
