#!/usr/bin/env bash
set -euo pipefail

fixture_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_root=$(cd -- "$fixture_dir/../.." && pwd)
tmp_dir=$(mktemp -d -t stillsuit-d2.XXXXXXXX)
shell_pid=""

cleanup() {
  if [[ -n $shell_pid ]] && kill -0 "$shell_pid" 2>/dev/null; then
    kill -TERM "$shell_pid"
    wait "$shell_pid" || true
  fi
  rm -rf -- "$tmp_dir"
}
trap cleanup EXIT

export HOME="$tmp_dir/home"
export XDG_CONFIG_HOME="$tmp_dir/config"
export XDG_DATA_HOME="$tmp_dir/data"
export XDG_STATE_HOME="$tmp_dir/state"
export XDG_CACHE_HOME="$tmp_dir/cache"
export XDG_RUNTIME_DIR="$tmp_dir/runtime"
export QT_QPA_PLATFORM=offscreen
export STILLSUIT_D2_FIXTURE_STATE="$tmp_dir/fake-niri"
export PATH="$fixture_dir/fixtures:$PATH"
unset DBUS_SESSION_BUS_ADDRESS
mkdir -p "$HOME" "$XDG_CONFIG_HOME/quickshell" "$XDG_DATA_HOME" \
  "$XDG_STATE_HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR" "$STILLSUIT_D2_FIXTURE_STATE"
chmod 700 "$XDG_RUNTIME_DIR"
chmod +x "$fixture_dir/fixtures/niri"

config_id=stillsuit-d2-compositor-fixture
config_dir="$XDG_CONFIG_HOME/quickshell/$config_id"
mkdir -p "$config_dir"
ln -s "$fixture_dir/fixture-shell.qml" "$config_dir/shell.qml"
ln -s "$source_root/services" "$config_dir/services"

ipc() { qs ipc --pid "$shell_pid" call stillsuit-d2-compositor-fixture "$@"; }

wait_for() {
  local expression state
  expression=$1
  for _ in {1..160}; do
    state=$(ipc state 2>/dev/null || true)
    if [[ -n $state ]] && jq -e "$expression" >/dev/null 2>&1 <<<"$state"; then
      printf '%s\n' "$state"
      return 0
    fi
    sleep 0.05
  done
  printf 'fixture condition timed out: %s\n' "$expression" >&2
  ipc state >&2 || true
  return 1
}

qs --no-color -p "$config_dir" >"$tmp_dir/quickshell.log" 2>&1 &
shell_pid=$!
sleep 0.02
if ! kill -0 "$shell_pid" 2>/dev/null; then
  cat "$tmp_dir/quickshell.log" >&2
  wait "$shell_pid" || true
  exit 1
fi

# Initial stream and bounded reconciliation produce the exact plain v1 shape.
first=$(wait_for '(.apiVersion == "1") and (.name == "niri") and (.outputs[0].id == "DP-1") and ((.windows | length) >= 1)')
jq -e '(.revision >= 1) and (.focusedOutputId == "DP-1")' >/dev/null <<<"$first"

# The fake stream exits, reconnects, and incremental events are folded before
# the next reconciliation overwrites the changed title with its authoritative value.
second=$(wait_for '(.windows | map(select(.id == 11))[0].title == "reconciled") and .workspaces[0].active_window_id == 11')
(( $(jq -r '.revision' <<<"$second") >= 4 ))
for _ in {1..80}; do
  if [[ -f $STILLSUIT_D2_FIXTURE_STATE/stream-count ]] \
    && [[ $(<"$STILLSUIT_D2_FIXTURE_STATE/stream-count") -ge 2 ]]; then
    break
  fi
  sleep 0.05
done
[[ $(<"$STILLSUIT_D2_FIXTURE_STATE/stream-count") -ge 2 ]]

# Malformed stream input did not clear the last good snapshot; all invoked
# command output also cannot erase it. Commands are fixed Niri argv forms, and
# the fixture has one global instance.
for _ in {1..80}; do
  if [[ -f $STILLSUIT_D2_FIXTURE_STATE/outputs-count ]] \
    && [[ $(<"$STILLSUIT_D2_FIXTURE_STATE/outputs-count") -ge 2 ]]; then
    break
  fi
  sleep 0.05
done
[[ $(<"$STILLSUIT_D2_FIXTURE_STATE/outputs-count") -ge 2 ]]
after_bad=$(ipc state)
jq -e '((.outputs | length) == 1) and ((.workspaces | length) == 1) and ((.windows | length) == 2)' >/dev/null <<<"$after_bad"
jq -e '((.outputs | length) == 1) and ((.workspaces | length) == 1) and ((.windows | length) == 2)' >/dev/null <<<"$second"
ownership=$(ipc ownership)
jq -e '.serviceInstances == 1 and .adapterInstances == 1' >/dev/null <<<"$ownership"
sort -u "$STILLSUIT_D2_FIXTURE_STATE/argv.log" >"$tmp_dir/argv.unique"
diff -u <(printf '%s\n' 'msg --json event-stream' 'msg -j outputs' 'msg -j windows' 'msg -j workspaces') "$tmp_dir/argv.unique"
