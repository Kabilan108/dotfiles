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
cp "$fixture_dir/../../services/NotificationSource.js" "$config_dir/services/NotificationSource.js"
cp "$fixture_dir/../../services/NotificationLinks.js" "$config_dir/services/NotificationLinks.js"
cp "$fixture_dir/../../services/NotificationLayout.js" "$config_dir/services/NotificationLayout.js"
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

send_notification() {
  env -u LD_LIBRARY_PATH notify-send "$@"
}

notification_status() {
  qs ipc --pid "$shell_pid" call stillsuit-notifications status
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

wait_for_pid_exit() {
  local pid=$1
  local _
  for _ in {1..120}; do
    if ! kill -0 "$pid" 2>/dev/null; then
      wait "$pid" 2>/dev/null || true
      return 0
    fi
    sleep 0.05
  done
  echo "process did not exit: $pid" >&2
  return 1
}

node "$fixture_dir/model-policy.test.js"
node "$fixture_dir/source-links-layout.test.js"
node "$fixture_dir/notification-card-source.test.js"
start_shell

# Opening the center marks only the rows present at that instant as read.
send_notification -a lane-e -t 5000 "before-center-open"
wait_for_json '.unreadCount == 1' >/dev/null
[[ $(ipc openCenter) == open ]]
wait_for_json '.unreadCount == 0' >/dev/null
send_notification -a lane-e -t 5000 "after-center-open"
wait_for_json '.unreadCount == 1 and (.popups | length) == 2' >/dev/null

# Toast dismissal archives a row; center deletion removes its history.
[[ $(ipc dismissFirst) == ok ]]
archive_state=$(wait_for_json '(.history | length) == 1 and (.popups | length) == 1')
jq -e '.history[0].closeReason == "dismissed"' >/dev/null <<<"$archive_state"
[[ $(ipc deleteFirst) == ok ]]
wait_for_json '.trackedCount == 1' >/dev/null
ipc dismissAll >/dev/null

# Requested timeout is milliseconds, and expiry archives before closing.
send_notification -a lane-e -t 350 "requested-timeout"
wait_for_json '.popups | length == 1' >/dev/null
wait_for_json '(.popups | length) == 0 and .history[0].closeReason == "expired"' >/dev/null

# A replacement-only update keeps identity and restarts the engine deadline.
ipc dismissAll >/dev/null
replacement_id=$(send_notification -p -a lane-e -t 350 "replace-before")
sleep 0.2
send_notification -a lane-e -r "$replacement_id" -t 700 "replace-after"
sleep 0.25
replacement_state=$(ipc state)
jq -e '(.popups | length) == 1 and .popups[0].summary == "replace-after"' >/dev/null <<<"$replacement_state"
sleep 0.25
jq -e '.popups | length == 1' >/dev/null <<<"$(ipc state)"
wait_for_json '(.popups | length) == 0 and .history[0].summary == "replace-after"' >/dev/null

# Named and default actions invoke the sender directly.
ipc dismissAll >/dev/null
send_notification -a lane-e -t 5000 -A default=Open -A reply=Reply "named-action" >"$tmp_dir/named.out" &
named_pid=$!
wait_for_json '.popups[0].actions | map(.identifier) == ["default", "reply"]' >/dev/null
[[ $(ipc invokeFirst reply) == ok ]]
wait "$named_pid"
[[ $(<"$tmp_dir/named.out") == reply ]]

send_notification -a lane-e -t 5000 -A default=Open "default-action" >"$tmp_dir/default.out" &
default_pid=$!
wait_for_json '.popups[0].actions[0].identifier == "default"' >/dev/null
[[ $(ipc invokeFirst default) == ok ]]
wait "$default_pid"
[[ $(<"$tmp_dir/default.out") == default ]]

# Hover intent pauses one deck in the service and queues arrivals until exit.
ipc dismissAll >/dev/null
send_notification -a lane-e -t 300 "pause-me"
wait_for_json '.popups[0].summary == "pause-me"' >/dev/null
[[ $(ipc hoverFirst on) == ok ]]
sleep 0.2
wait_for_json '.popups[0].summary == "pause-me"' >/dev/null
send_notification -a another-app -t 5000 "held-arrival"
paused_state=$(wait_for_json '.heldArrivals | length == 1')
jq -e '.popups[0].summary == "pause-me"' >/dev/null <<<"$paused_state"
sleep 0.25
jq -e '.popups[0].summary == "pause-me"' >/dev/null <<<"$(ipc state)"
status_state=$(notification_status)
jq -e '.apiVersion == 1 and .counts.heldArrivals == 1
  and .presentation.pausedNotificationCount == 1
  and (has("summary") | not) and (has("body") | not) and (has("urls") | not)' \
  >/dev/null <<<"$status_state"
[[ $(ipc hoverFirst off) == ok ]]
wait_for_json '(.heldArrivals | length) == 0 and (.popups | length) == 2' >/dev/null
wait_for_json '.history[0].summary == "pause-me"' >/dev/null
ipc dismissAll >/dev/null

# Clearing a source removes only that group's notifications.
send_notification -a clear-source-one -t 5000 "clear-source-one-a"
send_notification -a clear-source-two -t 5000 "clear-source-two"
send_notification -a clear-source-one -t 5000 "clear-source-one-b"
clear_source_state=$(wait_for_json '.trackedCount == 3')
clear_source_key=$(jq -r '.popups[] | select(.summary == "clear-source-one-a") | .sourceKey' <<<"$clear_source_state")
[[ $(ipc clearSource "$clear_source_key") == ok ]]
cleared_source_state=$(wait_for_json '.trackedCount == 1')
jq -e --arg key "$clear_source_key" '
  .popups[0].summary == "clear-source-two"
  and (.popups + .history + .heldArrivals | all(.sourceKey != $key))
' >/dev/null <<<"$cleared_source_state"
[[ $(ipc clearSource "$clear_source_key") == unknown ]]
ipc dismissAll >/dev/null

# Per-source snoozes share the finite mechanism without muting other sources.
send_notification -a source-one -t 5000 "source-one-before"
wait_for_json '.popups[0].summary == "source-one-before"' >/dev/null
source_key=$(ipc state | jq -r '.popups[0].sourceKey')
ipc snoozeFirstSource 30m >/dev/null
send_notification -a source-one -t 5000 "source-one-held"
send_notification -a source-two -t 5000 "source-two-visible"
source_state=$(wait_for_json '.popups[0].summary == "source-two-visible" and (.history | length) == 2')
jq -e '.history | all(.heldReason == "source-snooze")' >/dev/null <<<"$source_state"
ipc snoozeAll 30m >/dev/null
overlap_state=$(wait_for_json ".snoozes[\"*\"] and .snoozes[\"$source_key\"]")
jq -e --arg key "$source_key" '.snoozes["*"] and .snoozes[$key]' >/dev/null <<<"$overlap_state"
[[ $(ipc wake '*') == ok ]]
wait_for_json "(.snoozes[\"*\"] == null) and .snoozes[\"$source_key\"]" >/dev/null
[[ $(ipc wake "$source_key") == ok ]]
ipc dismissAll >/dev/null

# A finite global snooze has bypass, retained, and transient classes.
ipc dismissAll >/dev/null
send_notification -a chat-app -t 5000 "visible-before-snooze"
wait_for_json '(.popups | length) == 1' >/dev/null
global_until=$(ipc snoozeAll 1h)
[[ $global_until =~ ^[0-9]+$ ]]
cleared_state=$(wait_for_json '(.popups | length) == 0 and (.history | length) == 1')
jq -e '.history[0].closeReason == "global-snooze" and .history[0].heldReason == "global-snooze" and .liveRefCount == 1' >/dev/null <<<"$cleared_state"
ipc dismissAll >/dev/null
send_notification -a chat-app -t 5000 "retained-snooze"
wait_for_json '.history[0].quietClass == "silenced-retained" and .history[0].heldReason == "global-snooze"' >/dev/null
send_notification -u critical -a any-app -t 5000 "critical-bypass"
wait_for_json '.popups[0].quietClass == "bypass"' >/dev/null
local_count=$(ipc state | jq '.trackedCount')
send_notification -e -a chat-app -t 5000 "ephemeral-snooze"
sleep 0.15
[[ $(ipc state | jq '.trackedCount') == "$local_count" ]]
[[ $(ipc wake '*') == ok ]]

# The open center suppresses banners on its own output. Closing it restores
# single-output presentation for notifications that are still live.
presentation=$(ipc presentationProof)
jq -e '.outputA == 0 and .outputB == 0' >/dev/null <<<"$presentation"
[[ $(ipc closeCenter) == closed ]]
# One global service presents every toast on exactly one output.
presentation=$(ipc presentationProof)
jq -e '.serviceInstances == 1 and .outputA == 1 and .outputB == 0 and .overlap == 0' >/dev/null <<<"$presentation"

# A burst over the limit keeps five live toasts and 95 history rows.
ipc dismissAll >/dev/null
for index in {1..105}; do
  send_notification -a lane-e -t 60000 "burst-$index"
done
burst_state=$(wait_for_json '.trackedCount == 100')
jq -e '.popups | length == 5' >/dev/null <<<"$burst_state"
jq -e '.history | length == 95' >/dev/null <<<"$burst_state"
jq -e '.unreadCount == 100 and .unreadBadgeText == "9+"' >/dev/null <<<"$burst_state"

# Expired sender actions remain visible only as inert history metadata.
ipc dismissAll >/dev/null
send_notification -a lane-e -t 300 -A default=Open "expired-action" >"$tmp_dir/expired.out" &
expired_pid=$!
wait_for_json '.popups[0].actions[0].identifier == "default"' >/dev/null
expired_state=$(wait_for_json '(.popups | length) == 0 and .history[0].summary == "expired-action"')
jq -e '.history[0].actions[0].identifier == "default"' >/dev/null <<<"$expired_state"
[[ $(ipc firstActionState) == expired ]]
wait "$expired_pid" 2>/dev/null || true

# A persisted popup keeps its absolute engine deadline across a restart.
ipc dismissAll >/dev/null
send_notification -a lane-e -t 1200 "restart-deadline"
wait_for_json '.popups[0].summary == "restart-deadline"' >/dev/null
[[ $(ipc openCenter) == open ]]
wait_for_json '.unreadCount == 0' >/dev/null
sleep 0.25
stop_shell
start_shell
wait_for_json '.popups[0].summary == "restart-deadline" and .unreadCount == 0' >/dev/null
[[ $(ipc firstActionState) == none ]]
wait_for_json '(.popups | length) == 0 and .history[0].summary == "restart-deadline"' >/dev/null

# Restart hydration drops an old deadline-zero popup instead of restoring it.
ipc dismissAll >/dev/null
stop_shell
jq -n '{
  schemaVersion: 1,
  dnd: false,
  popups: [{
    key: "old-persistent-restart",
    originalId: 1,
    summary: "old-persistent-restart",
    timestamp: 1,
    deadline: 0,
    read: false
  }],
  history: []
}' >"$state_dir/notifications-v1.json"
start_shell
old_restart_state=$(wait_for_json '(.popups | length) == 0 and (.history | length) == 0')
jq -e '.trackedCount == 0 and .unreadCount == 0 and .liveRefCount == 0' \
  >/dev/null <<<"$old_restart_state"

# Runtime cleanup drops an old live popup, closes its sender, and releases its ref.
send_notification -u critical -a lane-e -t 0 -A default=Open "old-live-cleanup" \
  >"$tmp_dir/old-live.out" &
old_live_pid=$!
old_live_state=$(wait_for_json '.popups[0].summary == "old-live-cleanup" and .liveRefCount == 1')
old_live_timestamp=$(jq -r '.popups[0].timestamp' <<<"$old_live_state")
prune_timestamp=$(jq -nr --argjson timestamp "$old_live_timestamp" \
  '$timestamp + (24 * 60 * 60 * 1000) + 1')
[[ $(ipc pruneAt "$prune_timestamp") == 1 ]]
pruned_live_state=$(wait_for_json '(.popups | length) == 0 and (.history | length) == 0')
jq -e '.trackedCount == 0 and .unreadCount == 0 and .liveRefCount == 0' \
  >/dev/null <<<"$pruned_live_state"
wait_for_pid_exit "$old_live_pid"

# Unknown hints are discarded before and after a process restart.
ipc dismissAll >/dev/null
send_notification -a lane-e -t 250 -h "string:untrusted-command:touch $marker" "forged-hint"
hint_state=$(wait_for_json '.history[0].summary == "forged-hint"')
jq -e '.history[0].hints["untrusted-command"] == null' >/dev/null <<<"$hint_state"
[[ ! -e $marker ]]
stop_shell
start_shell
restarted_state=$(wait_for_json '.history[0].summary == "forged-hint"')
jq -e '.history[0].hints["untrusted-command"] == null' >/dev/null <<<"$restarted_state"
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

# Evicting a retained quiet row releases its live notification reference.
ipc dismissAll >/dev/null
stop_shell
export STILLSUIT_NOTIFICATION_HISTORY_LIMIT=2
start_shell
ipc snoozeAll 1h >/dev/null
for index in {1..3}; do
  send_notification -a lane-e -t 60000 "retained-$index"
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
