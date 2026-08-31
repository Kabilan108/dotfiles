#!/usr/bin/env bash
set -euo pipefail

fixture_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
package_dir=$(cd -- "$fixture_dir/../../.." && pwd)
tmp_dir=$(mktemp -d -t stillsuit-d5.XXXXXXXX)
shell_pid=""
socket_pid=""
fake_recorder_pid=""

cleanup() {
  local status=$?
  if [[ -n $shell_pid ]] && kill -0 "$shell_pid" 2>/dev/null; then kill "$shell_pid"; wait "$shell_pid" 2>/dev/null || true; fi
  if [[ -n $socket_pid ]] && kill -0 "$socket_pid" 2>/dev/null; then kill "$socket_pid"; wait "$socket_pid" 2>/dev/null || true; fi
  if [[ -n $fake_recorder_pid ]] && kill -0 "$fake_recorder_pid" 2>/dev/null; then kill "$fake_recorder_pid"; wait "$fake_recorder_pid" 2>/dev/null || true; fi
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
export STILLSUIT_FIXTURE_HELPER="$fixture_dir/fake-recorder"
export STILLSUIT_FIXTURE_HELPER_LOG="$tmp_dir/helper.log"
export STILLSUIT_FIXTURE_RECORDING_STATE="$tmp_dir/recording.json"
export STILLSUIT_FIXTURE_MEETING_STATE="$tmp_dir/meeting.json"
export STILLSUIT_FIXTURE_SOCKET="$tmp_dir/dictator.sock"
# This fixture exercises services only; force the isolated renderer rather than
# attaching an overlay test to the live compositor.
export QT_QPA_PLATFORM=offscreen
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

for variable_name in HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME XDG_RUNTIME_DIR; do
  [[ ${!variable_name} == "$tmp_dir"/* ]] || { echo "fixture escaped temporary roots: $variable_name" >&2; exit 1; }
done

printf '%s\n' '{"schemaVersion":1,"phase":"recording","pid":1,"monitor":"DP-1","elapsed_seconds":4}' > "$STILLSUIT_FIXTURE_RECORDING_STATE"
printf '%s\n' '{"schemaVersion":1,"phase":"transcribing","label":"fixture","progress":1,"total":2}' > "$STILLSUIT_FIXTURE_MEETING_STATE"
python3 "$fixture_dir/socket-server.py" "$STILLSUIT_FIXTURE_SOCKET" >"$tmp_dir/socket.log" 2>&1 &
socket_pid=$!
for _ in {1..100}; do [[ -S $STILLSUIT_FIXTURE_SOCKET ]] && break; sleep 0.02; done
[[ -S $STILLSUIT_FIXTURE_SOCKET ]]

config_dir="$tmp_dir/quickshell"
mkdir -p "$config_dir/plugins/builtin" "$config_dir/services"
cp "$fixture_dir/WorkflowFixture.qml" "$config_dir/shell.qml"
cp -R "$package_dir/src/services/." "$config_dir/services/"
cp -R "$package_dir/src/plugins/builtin/workflows" "$config_dir/plugins/builtin/workflows"

ipc() { qs ipc --pid "$shell_pid" call stillsuit-d5-fixture "$@"; }
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
start_shell() {
  qs --no-color -p "$config_dir" >"$tmp_dir/quickshell.log" 2>&1 &
  shell_pid=$!
  wait_json '.aggregateApiVersion == "1" and .recording.status == "ready" and .dictator.socketConnections == 1' >/dev/null
}
stop_shell() {
  local pid=$shell_pid
  kill "$pid"
  wait "$pid" 2>/dev/null || true
  shell_pid=""
}

start_shell
state=$(ipc state)
jq -e '.serviceObjects == 1 and .overlays == 2 and .overlaySharesAggregate and .dictator.levels == 23 and .dictator.state == "recording"' >/dev/null <<<"$state"

# The action uses only literal argv; the fake helper sees the exact reviewed order.
[[ $(ipc start) == started ]]
for _ in {1..100}; do [[ -s $STILLSUIT_FIXTURE_HELPER_LOG ]] && break; sleep 0.02; done
[[ $(<"$STILLSUIT_FIXTURE_HELPER_LOG") == 'start --directory /tmp/fixture-recordings --monitor DP-1 --title fixture-title --desktop-audio --no-microphone' ]]

# Corrupt and future-version durable state are contained without commanding the helper.
printf '%s\n' '{broken' > "$STILLSUIT_FIXTURE_RECORDING_STATE"
[[ $(ipc refresh) == ok ]]
wait_json '.recording.status == "corrupt" and .recording.phase == "idle"' >/dev/null
printf '%s\n' '{"schemaVersion":2,"phase":"recording"}' > "$STILLSUIT_FIXTURE_MEETING_STATE"
[[ $(ipc refresh) == ok ]]
wait_json '.meeting.status == "unsupported" and .meeting.phase == "idle"' >/dev/null

# A live-looking recorder is external authority. Destroy/recreate the fixture
# and prove it neither invokes stop nor signals this private fake process.
sleep 60 &
fake_recorder_pid=$!
printf '{"schemaVersion":1,"phase":"recording","pid":%s,"monitor":"DP-1"}\n' "$fake_recorder_pid" > "$STILLSUIT_FIXTURE_RECORDING_STATE"
[[ $(ipc refresh) == ok ]]
wait_json '.recording.active and .recording.status == "ready"' >/dev/null
stop_shell
kill -0 "$fake_recorder_pid"
start_shell
kill -0 "$fake_recorder_pid"
[[ $(wc -l < "$STILLSUIT_FIXTURE_HELPER_LOG") -eq 1 ]]

echo "d5-workflows: ok"
