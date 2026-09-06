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

wait_for_reconciliation() {
  local expression reconciliation
  expression=$1
  for _ in {1..160}; do
    reconciliation=$(ipc reconciliation 2>/dev/null || true)
    if [[ -n $reconciliation ]] && jq -e "$expression" >/dev/null 2>&1 <<<"$reconciliation"; then
      printf '%s\n' "$reconciliation"
      return 0
    fi
    sleep 0.05
  done
  printf 'fixture reconciliation timed out: %s\n' "$expression" >&2
  ipc reconciliation >&2 || true
  return 1
}

wait_for_reconnect() {
  local expression reconnect
  expression=$1
  for _ in {1..160}; do
    reconnect=$(ipc reconnect 2>/dev/null || true)
    if [[ -n $reconnect ]] && jq -e "$expression" >/dev/null 2>&1 <<<"$reconnect"; then
      printf '%s\n' "$reconnect"
      return 0
    fi
    sleep 0.05
  done
  printf 'fixture reconnect timed out: %s\n' "$expression" >&2
  ipc reconnect >&2 || true
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

# Niri returns an output map keyed by connector. Both the event stream and the
# first successful command triplet normalize it to a sorted plain array.
wait_for_reconciliation '.completedGeneration == 1 and .acceptedGeneration == 1' >/dev/null
first=$(wait_for '(.apiVersion == "1") and (.name == "niri") and (.focusedOutputId == "DP-2")')
jq -e '
  (.revision >= 1)
  and ((.outputs | type) == "array")
  and ([.outputs[].name] == ["DP-2", "eDP-1"])
  and (.outputs[0].id == "desk-output")
  and (.outputs[0].name == "DP-2")
  and (.outputs[1].id == "eDP-1")
  and (.outputs[1].name == "eDP-1")
  and ([.workspaces[].id] == [1])
  and ([.windows[].id] == [10])
' >/dev/null <<<"$first"

# Generation 2 has usable output and window JSON, but workspaces exits 23 with
# empty stdout. None of that generation may replace any part of generation 1.
wait_for_reconciliation '.completedGeneration == 2 and .acceptedGeneration == 1' >/dev/null
after_bad=$(ipc state)
jq -e '
  ([.outputs[].name] == ["DP-2", "eDP-1"])
  and ([.workspaces[].id] == [1])
  and ([.windows[].id] == [10])
  and ([.windows[].title] == ["generation-1"])
  and ([.outputs[].name] | index("BROKEN-OUTPUT") == null)
' >/dev/null <<<"$after_bad"

# Generation 3 exits zero but contains malformed output JSON. The other two
# valid members are still rejected as part of the same triplet.
: >"$STILLSUIT_D2_FIXTURE_STATE/allow-malformed"
wait_for_reconciliation '.completedGeneration == 3 and .acceptedGeneration == 1' >/dev/null
after_malformed=$(ipc state)
jq -e '
  ([.outputs[].name] == ["DP-2", "eDP-1"])
  and ([.workspaces[].id] == [1])
  and ([.windows[].id] == [10])
  and ([.windows[].title] == ["generation-1"])
' >/dev/null <<<"$after_malformed"

# Generation 4 never completes. The timeout must reject the whole generation,
# terminate its collectors, and release the running flag for a later retry.
: >"$STILLSUIT_D2_FIXTURE_STATE/allow-recovery"
wait_for_reconciliation '.completedGeneration == 4 and .acceptedGeneration == 1 and .timedOutGeneration == 4' >/dev/null
after_timeout=$(ipc state)
jq -e '
  ([.outputs[].name] == ["DP-2", "eDP-1"])
  and ([.workspaces[].id] == [1])
  and ([.windows[].id] == [10])
  and ([.windows[].title] == ["generation-1"])
' >/dev/null <<<"$after_timeout"

# The next generation may then commit its three valid members together.
: >"$STILLSUIT_D2_FIXTURE_STATE/allow-final-recovery"
wait_for_reconciliation '.completedGeneration >= 5 and .acceptedGeneration >= 5 and .timedOutGeneration == 4' >/dev/null
recovered=$(wait_for '
  ([.outputs[].name] == ["HDMI-A-1"])
  and ([.workspaces[].id] == [4])
  and ([.windows[].id] == [40])
  and (.focusedOutputId == "HDMI-A-1")
')
jq -e '
  (.outputs[0].id == "HDMI-A-1")
  and (.outputs[0].make == "Recovered")
  and (.windows[0].title == "generation-5")
' >/dev/null <<<"$recovered"

# The fake stream exits repeatedly without the live Niri socket. After the
# initial healthy event resets the counter, retries double from 50 to 100 ms
# and stay capped at 200 ms.
reconnect=$(wait_for_reconnect '.attempts >= 3 and .scheduledDelayMs == 200')
jq -e '.baseDelayMs == 50 and .doubledDelayMs == 100 and .cappedDelayMs == 200' >/dev/null <<<"$reconnect"
[[ $(<"$STILLSUIT_D2_FIXTURE_STATE/stream-count") -ge 4 ]]

# Commands remain fixed literal Niri argv forms, and the fixture has one global
# service and adapter instance.
ownership=$(ipc ownership)
jq -e '.serviceInstances == 1 and .adapterInstances == 1' >/dev/null <<<"$ownership"
sort -u "$STILLSUIT_D2_FIXTURE_STATE/argv.log" >"$tmp_dir/argv.unique"
diff -u <(printf '%s\n' 'msg --json event-stream' 'msg -j outputs' 'msg -j windows' 'msg -j workspaces') "$tmp_dir/argv.unique"

if rg --line-number --ignore-case '(binding loop|typeerror|referenceerror)' "$tmp_dir/quickshell.log" >"$tmp_dir/quickshell-errors"; then
  cat "$tmp_dir/quickshell-errors" >&2
  exit 1
else
  rg_status=$?
  if (( rg_status != 1 )); then exit "$rg_status"; fi
fi
