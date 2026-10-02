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

flush_cache() { sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder; }

# What the OS resolver (mDNSResponder, with its cache) says -- unlike dig, which bypasses it.
os_lookup() { dscacheutil -q host -a name "$1" | awk '/ip_address/{print $2}' | head -1; }

restart_dns() { sudo brew services restart dnsmasq >/dev/null; sleep 1; }

# set_record NAME IP -- rewrite one address= line in the live config, then restart.
set_record() {
  sed -i '' -E "s|^address=/$1/.*|address=/$1/$2|" "$LIVE_CONF"
  grep -q "^address=/$1/$2\$" "$LIVE_CONF" || { echo "!! failed to set $1 -> $2" >&2; exit 1; }
  restart_dns
}
