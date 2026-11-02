#!/usr/bin/env bash
# Test the CPA (cliproxyapi) gateway that this checkout builds for sietch: the
# unit's preStart, both nginx fronts, the management API, logging and the
# unit's sandbox. Dummy keys, free loopback ports and temp state only; the
# running service and /var/lib/cliproxyapi are never touched. See README.md.
#
#   tests/cpa/run.sh [--browser] [--keep]
#
# --browser  also log into the dashboard with agent-browser
# --keep     keep the temp directory even when every check passes
set -uo pipefail
# shellcheck source-path=SCRIPTDIR

usage() {
  echo "usage: tests/cpa/run.sh [--browser] [--keep]" >&2
  exit 2
}

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(git -C "$here" rev-parse --show-toplevel)
browser=false
keep=false

while (($#)); do
  case $1 in
  --browser)
    browser=true
    shift
    ;;
  --keep)
    keep=true
    shift
    ;;
  *) usage ;;
  esac
done

run=$(mktemp -d "${TMPDIR:-/tmp}/cpa-test.XXXXXX")
out=$run/out
state=$run/state
mkdir -p "$out" "$state/auth"
mkey=dummy-mgmt-key
ikey=dummy-inference-key
model=test-model

# shellcheck source=lib.sh
source "$here/lib.sh"
# shellcheck source=fronts.sh
source "$here/fronts.sh"
# shellcheck source=hardened.sh
source "$here/hardened.sh"
# shellcheck source=browser.sh
source "$here/browser.sh"

upstream_pid=
cpa_pid=
nginx_pid=
hardened_unit=
hardened_state=

cleanup() {
  [[ -n $hardened_unit ]] && systemctl --user stop "$hardened_unit" 2>/dev/null
  [[ -n $hardened_state ]] && rm -rf "$hardened_state"
  stop_pid "$nginx_pid"
  stop_pid "$cpa_pid"
  stop_pid "$upstream_pid"
  if ((${#failures[@]} == 0)) && ! $keep; then
    rm -rf "$run"
  else
    echo "logs kept in $run"
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# The nix build output goes to a file; on a version bump it includes the CPA compile.
# shellcheck disable=SC2154 # resolved.sh sets the store paths and drvs
resolve() {
  local vars=$run/resolved.sh
  echo "resolving store paths from $root#nixosConfigurations.sietch"
  if ! nix eval --raw "$root#nixosConfigurations.sietch" --apply "$(cat "$here/resolve.nix")" \
    >"$vars" 2>"$out/resolve.log"; then
    cat "$out/resolve.log"
    echo "FAIL could not evaluate nixosConfigurations.sietch"
    exit 1
  fi
  # shellcheck source=/dev/null
  source "$vars"
  if ! nix build --no-link "${drvs[@]/%/^*}" >"$out/build.log" 2>&1; then
    cat "$out/build.log"
    echo "FAIL could not build the CPA closure"
    exit 1
  fi
  echo "cpa:      $cpa"
  echo "preStart: $pre_start"
  echo "panel:    $panel"
  echo "nginx:    $nginx -c $nginx_conf"
}

resolve
read -r api_port test_front_port test_admin_port upstream_port hardened_port < <(free_ports 5)

# shellcheck disable=SC2154 # python comes from resolved.sh
"$python" -I "$here/upstream.py" "$upstream_port" >"$out/upstream.log" 2>&1 &
upstream_pid=$!
if ! wait_http "http://127.0.0.1:$upstream_port/v1/models"; then
  echo "FAIL dummy upstream did not start"
  exit 1
fi

fronts_checks
hardened_checks
if $browser; then
  browser_checks
fi
end_section

printf '\n== summary\n'
printf '%s\n' "${section_results[@]}"
if ((${#failures[@]})); then
  printf '\n%s failed:\n' "${#failures[@]}"
  printf '  %s\n' "${failures[@]}"
  echo "RESULT: FAIL ($total_passes passed, ${#failures[@]} failed)"
  exit 1
fi
echo "RESULT: PASS ($total_passes passed, 0 failed)"
