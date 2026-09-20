#!/usr/bin/env bash
set -euo pipefail

fixture_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
package_dir=$(cd -- "$fixture_dir/../../.." && pwd)
tmp_dir=$(mktemp -d -t stillsuit-d6.XXXXXXXX)
shell_pid=""
socket_pid=""

cleanup() {
  local status=$?
  if [[ -n $shell_pid ]] && kill -0 "$shell_pid" 2>/dev/null; then kill "$shell_pid"; wait "$shell_pid" 2>/dev/null || true; fi
  if [[ -n $socket_pid ]] && kill -0 "$socket_pid" 2>/dev/null; then kill "$socket_pid"; wait "$socket_pid" 2>/dev/null || true; fi
  if [[ -z ${STILLSUIT_FIXTURE_KEEP:-} ]]; then rm -rf -- "$tmp_dir"; else printf 'fixture retained: %s\n' "$tmp_dir" >&2; fi
  exit "$status"
}
trap cleanup EXIT

export HOME="$tmp_dir/home"
export XDG_CONFIG_HOME="$tmp_dir/config"
export XDG_DATA_HOME="$tmp_dir/data"
export XDG_CACHE_HOME="$tmp_dir/cache"
export XDG_STATE_HOME="$tmp_dir/state"
export XDG_RUNTIME_DIR="$tmp_dir/runtime"
export STILLSUIT_FIXTURE_DICTATOR="$fixture_dir/fake-dictator"
export STILLSUIT_FIXTURE_DICTATOR_LOG="$tmp_dir/dictator.log"
export STILLSUIT_FIXTURE_DICTATOR_FAIL="$tmp_dir/dictator.fail"
export STILLSUIT_FIXTURE_SOCKET="$tmp_dir/osd.sock"
export QT_QPA_PLATFORM=offscreen
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
: > "$STILLSUIT_FIXTURE_DICTATOR_LOG"

python3 "$fixture_dir/socket-server.py" "$STILLSUIT_FIXTURE_SOCKET" "$tmp_dir/start-recording" >"$tmp_dir/socket.log" 2>&1 &
socket_pid=$!
for _ in {1..100}; do [[ -S $STILLSUIT_FIXTURE_SOCKET ]] && break; sleep 0.02; done
[[ -S $STILLSUIT_FIXTURE_SOCKET ]]

config_dir="$tmp_dir/quickshell"
mkdir -p "$config_dir/plugins/builtin" "$config_dir/tests"
cp "$fixture_dir/DictationFixture.qml" "$config_dir/shell.qml"
cp -R "$package_dir/src/services" "$config_dir/services"
cp -R "$package_dir/src/plugins/builtin/workflows" "$config_dir/plugins/builtin/workflows"
cp -R "$package_dir/src/plugins/builtin/dictation" "$config_dir/plugins/builtin/dictation"
cp "$package_dir/src/tests/FixtureTheme.js" "$config_dir/tests/FixtureTheme.js"
cp -R "$package_dir/src/ui" "$config_dir/ui"

ipc() { qs ipc --pid "$shell_pid" call stillsuit-d6-fixture "$@"; }
wait_json() {
  local expression=$1 state
  for _ in {1..160}; do
    state=$(ipc state 2>/dev/null || true)
    if [[ -n $state ]] && jq -e "$expression" >/dev/null 2>&1 <<<"$state"; then printf '%s\n' "$state"; return 0; fi
    sleep 0.05
  done
  echo "fixture condition timed out: $expression" >&2
  ipc state >&2 || true
  return 1
}

qs --no-color -p "$config_dir" >"$tmp_dir/quickshell.log" 2>&1 &
shell_pid=$!

# History loads on construction from the literal CLI argv and keeps rows in order.
state=$(wait_json '.apiVersion == "1" and .configured and .connected and .state == "idle" and .recentStatus == "ready"')
jq -e '(.recent | length) == 2 and .recent[0].id == 42 and .recent[1].id == 41 and .recent[0].durationMs == 21227 and .canToggle and (.canCancel | not)' >/dev/null <<<"$state"
[[ $(sed -n '1p' "$STILLSUIT_FIXTURE_DICTATOR_LOG") == 'transcripts -n 5' ]]

# Toggle dispatches exactly one argv and refuses to overlap itself.
[[ $(ipc toggle) == started ]]
for _ in {1..100}; do [[ $(wc -l < "$STILLSUIT_FIXTURE_DICTATOR_LOG") -ge 2 ]] && break; sleep 0.02; done
[[ $(sed -n '2p' "$STILLSUIT_FIXTURE_DICTATOR_LOG") == 'toggle' ]]
wait_json '.actionRunning | not' >/dev/null

# Live state comes from the OSD socket, not from the command result.
touch "$tmp_dir/start-recording"
wait_json '.state == "recording" and .canToggle and .canCancel' >/dev/null
[[ $(ipc cancel) == started ]]
for _ in {1..100}; do [[ $(wc -l < "$STILLSUIT_FIXTURE_DICTATOR_LOG") -ge 3 ]] && break; sleep 0.02; done
[[ $(sed -n '3p' "$STILLSUIT_FIXTURE_DICTATOR_LOG") == 'cancel' ]]

# Returning to idle refreshes history once without an explicit request.
wait_json '.state == "idle"' >/dev/null
for _ in {1..100}; do [[ $(wc -l < "$STILLSUIT_FIXTURE_DICTATOR_LOG") -ge 4 ]] && break; sleep 0.02; done
[[ $(sed -n '4p' "$STILLSUIT_FIXTURE_DICTATOR_LOG") == 'transcripts -n 5' ]]

# A failing command surfaces its last stderr line and clears the busy flag.
touch "$STILLSUIT_FIXTURE_DICTATOR_FAIL"
[[ $(ipc toggle) == started ]]
wait_json '.errorMessage == "error: daemon refused toggle" and (.actionRunning | not)' >/dev/null

# Copy puts the full transcript, newlines included, on the clipboard.
[[ $(ipc copy 0) == copied ]]
[[ $(ipc clipboard) == $'First line\n\nsecond paragraph' ]]

echo "d6 dictation fixture passed"
