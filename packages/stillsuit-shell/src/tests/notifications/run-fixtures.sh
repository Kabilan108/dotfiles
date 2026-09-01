#!/usr/bin/env bash
set -euo pipefail

if [[ ${STILLSUIT_NOTIFICATION_TEST_BUS:-} != 1 ]]; then
  fixture_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
  exec dbus-run-session --config-file="$fixture_dir/session-bus.conf" -- \
    env STILLSUIT_NOTIFICATION_TEST_BUS=1 "$0" "$@"
fi

if [[ -z ${DBUS_SESSION_BUS_ADDRESS:-} ]]; then
  echo "fixture bug: no private D-Bus session" >&2
  exit 1
fi

fixture_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
tmp_dir=$(mktemp -d -t stillsuit-notifications.XXXXXXXX)
fixture_home_dir="$tmp_dir/home"
config_home_dir="$tmp_dir/xdg-config"
data_home_dir="$tmp_dir/xdg-data"
cache_home_dir="$tmp_dir/xdg-cache"
state_dir="$tmp_dir/xdg-state"
runtime_dir="$tmp_dir/xdg-runtime"
marker="$tmp_dir/executable-hint-ran"
config_dir="$tmp_dir/fixture-config"
wayland_display=${WAYLAND_DISPLAY:-}
wayland_runtime_dir=${XDG_RUNTIME_DIR:-}
export HOME="$fixture_home_dir"
export XDG_CONFIG_HOME="$config_home_dir"
export XDG_DATA_HOME="$data_home_dir"
export XDG_CACHE_HOME="$cache_home_dir"
export XDG_STATE_HOME="$state_dir"
export XDG_RUNTIME_DIR="$runtime_dir"
if [[ -n $wayland_display && $wayland_display != /* ]]; then
  export WAYLAND_DISPLAY="$wayland_runtime_dir/$wayland_display"
fi
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" \
  "$XDG_STATE_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$runtime_dir"
mkdir -p "$config_dir/services"
cp "$fixture_dir/fixture-shell.qml" "$config_dir/shell.qml"
cp "$fixture_dir/../../services/NotificationModel.js" "$config_dir/services/NotificationModel.js"
cp "$fixture_dir/../../services/NotificationPolicy.js" "$config_dir/services/NotificationPolicy.js"
cp "$fixture_dir/../../services/NotificationService.qml" "$config_dir/services/NotificationService.qml"
shell_pid=""

assert_private_environment() {
  local variable_name variable_value
  for variable_name in HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME XDG_RUNTIME_DIR; do
    variable_value=${!variable_name}
    if [[ $variable_value != "$tmp_dir"/* ]]; then
      printf 'fixture bug: %s is outside temporary root: %s\n' "$variable_name" "$variable_value" >&2
      return 1
    fi
  done
}

assert_private_environment

cleanup() {
  if [[ -n $shell_pid ]] && kill -0 "$shell_pid" 2>/dev/null; then
    kill "$shell_pid"
    wait "$shell_pid" 2>/dev/null || true
  fi
  rm -rf -- "$tmp_dir"
}
trap cleanup EXIT

ipc() {
  qs ipc --pid "$shell_pid" call stillsuit-notification-fixture "$@"
}

wait_ready() {
  local _
  for _ in {1..100}; do
    if [[ $(ipc ready 2>/dev/null || true) == ready ]]; then
      return 0
    fi
    sleep 0.05
  done
  echo "fixture shell did not become ready" >&2
  return 1
}

wait_for_json() {
  local expression=$1
  local _ state
  for _ in {1..120}; do
    state=$(ipc state 2>/dev/null || true)
    if [[ -n $state ]] && jq -e "$expression" >/dev/null 2>&1 <<<"$state"; then
      printf '%s\n' "$state"
      return 0
    fi
    sleep 0.05
  done
  echo "condition timed out: $expression" >&2
  ipc state >&2 || true
  return 1
}

start_shell() {
  qs --no-color -p "$config_dir" >"$tmp_dir/quickshell.log" 2>&1 &
  shell_pid=$!
  wait_ready
}

stop_shell() {
  local pid=$shell_pid
  [[ -n $pid ]]
  kill "$pid"
  wait "$pid" 2>/dev/null || true
  shell_pid=""
}

crash_shell() {
  local pid=$shell_pid
  [[ -n $pid ]]
  kill -KILL "$pid"
  wait "$pid" 2>/dev/null || true
  shell_pid=""
}

wait_for_state_file() {
  local expression=$1
  local _
  for _ in {1..120}; do
    if [[ -f $state_dir/notifications-v1.json ]] \
      && jq -e "$expression" "$state_dir/notifications-v1.json" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.05
  done
  echo "state file condition timed out: $expression" >&2
  [[ ! -f $state_dir/notifications-v1.json ]] || cat "$state_dir/notifications-v1.json" >&2
  return 1
}

node "$fixture_dir/model-policy.test.js"
node "$fixture_dir/notification-card-source.test.js"
start_shell

# Requested timeout is milliseconds, and expiry archives before closing.
notify-send -a lane-e -t 350 "requested-timeout"
wait_for_json '.popups | length == 1' >/dev/null
wait_for_json '(.popups | length) == 0 and .history[0].closeReason == "expired"' >/dev/null

# A replacement-only update keeps identity and restarts the engine deadline.
ipc dismissAll >/dev/null
replacement_id=$(notify-send -p -a lane-e -t 350 "replace-before")
sleep 0.2
notify-send -a lane-e -r "$replacement_id" -t 700 "replace-after"
sleep 0.25
replacement_state=$(ipc state)
jq -e '(.popups | length) == 1 and .popups[0].summary == "replace-after"' >/dev/null <<<"$replacement_state"
sleep 0.25
jq -e '.popups | length == 1' >/dev/null <<<"$(ipc state)"
wait_for_json '(.popups | length) == 0 and .history[0].summary == "replace-after"' >/dev/null

# Named and default actions invoke the sender directly.
ipc dismissAll >/dev/null
notify-send -a lane-e -t 5000 -A default=Open -A reply=Reply "named-action" >"$tmp_dir/named.out" &
named_pid=$!
wait_for_json '.popups[0].actions | map(.identifier) == ["default", "reply"]' >/dev/null
[[ $(ipc invokeFirst reply) == ok ]]
wait "$named_pid"
[[ $(<"$tmp_dir/named.out") == reply ]]

notify-send -a lane-e -t 5000 -A default=Open "default-action" >"$tmp_dir/default.out" &
default_pid=$!
wait_for_json '.popups[0].actions[0].identifier == "default"' >/dev/null
[[ $(ipc invokeFirst default) == ok ]]
wait "$default_pid"
[[ $(<"$tmp_dir/default.out") == default ]]

# DND has visible, bypass, retained, and transient classes.
ipc dismissAll >/dev/null
[[ $(ipc setDnd on) == on ]]
notify-send -a chat-app -t 5000 "retained-dnd"
wait_for_json '.history[0].dndClass == "silenced-retained"' >/dev/null
notify-send -u critical -a any-app -t 5000 "critical-bypass"
wait_for_json '.popups[0].dndClass == "bypass"' >/dev/null
local_count=$(ipc state | jq '.trackedCount')
notify-send -e -a chat-app -t 5000 "ephemeral-dnd"
sleep 0.15
[[ $(ipc state | jq '.trackedCount') == "$local_count" ]]
[[ $(ipc setDnd off) == off ]]

# One global service presents every toast on exactly one output.
presentation=$(ipc presentationProof)
jq -e '.serviceInstances == 1 and .outputA == 1 and .outputB == 0 and .overlap == 0' >/dev/null <<<"$presentation"

# A 100-notification burst keeps five live toasts and 95 bounded history rows.
ipc dismissAll >/dev/null
for index in {1..100}; do
  notify-send -a lane-e -t 60000 "burst-$index"
done
burst_state=$(wait_for_json '.trackedCount == 100')
jq -e '.popups | length == 5' >/dev/null <<<"$burst_state"
jq -e '.history | length == 95' >/dev/null <<<"$burst_state"

# A persisted popup keeps its absolute engine deadline across a restart.
ipc dismissAll >/dev/null
notify-send -a lane-e -t 1200 "restart-deadline"
wait_for_json '.popups[0].summary == "restart-deadline"' >/dev/null
sleep 0.25
stop_shell
start_shell
wait_for_json '.popups[0].summary == "restart-deadline"' >/dev/null
wait_for_json '(.popups | length) == 0 and .history[0].summary == "restart-deadline"' >/dev/null

# Executable-looking hints remain data before and after a process restart.
ipc dismissAll >/dev/null
notify-send -a lane-e -t 250 -h "string:omarchy-exec:touch $marker" "forged-hint"
hint_state=$(wait_for_json '.history[0].summary == "forged-hint"')
jq -e --arg marker "touch $marker" '.history[0].hints["omarchy-exec"] == $marker' >/dev/null <<<"$hint_state"
[[ ! -e $marker ]]
stop_shell
start_shell
restarted_state=$(wait_for_json '.history[0].summary == "forged-hint"')
jq -e --arg marker "touch $marker" '.history[0].hints["omarchy-exec"] == $marker' >/dev/null <<<"$restarted_state"
[[ $(ipc invokeFirst default) == unavailable ]]
[[ ! -e $marker ]]

# A bad record cannot poison valid history during the next restart.
stop_shell
jq '.history += [{"summary":"missing identity"}]' "$state_dir/notifications-v1.json" >"$tmp_dir/corrupt-state.json"
cp "$tmp_dir/corrupt-state.json" "$state_dir/notifications-v1.json"
start_shell
recovered_state=$(wait_for_json '.history | length == 1')
jq -e '.history[0].summary == "forged-hint"' >/dev/null <<<"$recovered_state"
[[ ! -e $marker ]]

# Evicting a retained DND row releases its live notification reference.
ipc dismissAll >/dev/null
stop_shell
export STILLSUIT_NOTIFICATION_HISTORY_LIMIT=2
start_shell
[[ $(ipc setDnd on) == on ]]
for index in {1..3}; do
  notify-send -a lane-e -t 60000 "retained-$index"
done
eviction_state=$(wait_for_json '(.history | length) == 2 and .liveRefCount == 2')
jq -e '.history | map(.summary) == ["retained-3", "retained-2"]' >/dev/null <<<"$eviction_state"

# Clear-all reaches disk before it returns, so a crash cannot restore old rows.
wait_for_state_file '(.history | length) == 2'
[[ $(ipc dismissAll) == ok ]]
if ! jq -e '(.popups | length) == 0 and (.history | length) == 0' \
  "$state_dir/notifications-v1.json" >/dev/null; then
  echo "clear-all did not synchronously persist empty notification state" >&2
  cat "$state_dir/notifications-v1.json" >&2
  exit 1
fi
crash_shell
start_shell
wait_for_json '(.popups | length) == 0 and (.history | length) == 0' >/dev/null

if grep -E ' ERROR| FATAL' "$tmp_dir/quickshell.log"; then
  echo "fixture shell logged a QML error" >&2
  exit 1
fi

echo "notification fixtures: ok"
