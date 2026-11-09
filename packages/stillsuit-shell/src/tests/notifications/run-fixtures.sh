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

# notify-send closes its own notification once an action arrives, so a sender
# that stays (resident) is sent over D-Bus directly.
gdbus_bin=$(command -v gdbus || printf '%s/bin/gdbus' "$(nix build --no-link --print-out-paths nixpkgs#glib.bin)")
send_raw_notification() {
  local summary=$1 actions=$2 hints=$3
  "$gdbus_bin" call --session --dest org.freedesktop.Notifications \
    --object-path /org/freedesktop/Notifications \
    --method org.freedesktop.Notifications.Notify \
    lane-e 0 "" "$summary" "" "$actions" "$hints" 5000 >/dev/null
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

node "$fixture_dir/motion.test.js"
node "$fixture_dir/model-policy.test.js"
node "$fixture_dir/source-links-layout.test.js"
node "$fixture_dir/notification-card-source.test.js"
start_shell

# Dismissing a toast closes it; nothing is archived.
send_notification -a lane-e -t 5000 "dismiss-me"
wait_for_json '(.popups | length) == 1' >/dev/null
[[ $(ipc dismissFirst) == ok ]]
wait_for_json '(.popups | length) == 0 and (.held | length) == 0 and .liveRefCount == 0' >/dev/null

# Toast dismissals share the persist() debounce: a burst writes state once.
for index in {1..3}; do
  send_notification -a "debounce-$index" -t 60000 "debounce-$index"
done
wait_for_json '(.popups | length) == 3' >/dev/null
sleep 0.3
writes_before=$(ipc state | jq '.stateWrites')
burst=$(ipc dismissPopups)
jq -e '.dismissed == 3 and .synchronousWrites == 0' >/dev/null <<<"$burst"
wait_for_json "(.popups | length) == 0 and .stateWrites == $((writes_before + 1))" >/dev/null
sleep 0.3
jq -e ".stateWrites == $((writes_before + 1))" >/dev/null <<<"$(ipc state)"
wait_for_state_file '.schemaVersion == 3 and (.popups | length) == 0 and has("history") == false'

# Requested timeout is milliseconds.
send_notification -a lane-e -t 350 "requested-timeout"
wait_for_json '.popups | length == 1' >/dev/null
wait_for_json '(.popups | length) == 0' >/dev/null

# Cards with buttons stay at least ten seconds; plain ones keep the default.
send_notification -a lane-e -A reply=Reply "button-card" >/dev/null &
button_pid=$!
button_state=$(wait_for_json '.popups[0].summary == "button-card"')
jq -e '.popups[0].deadline - .popups[0].timestamp | . >= 9900 and . <= 10100' >/dev/null <<<"$button_state"
send_notification -a lane-e "plain-card"
plain_state=$(wait_for_json '.popups[0].summary == "plain-card"')
jq -e '.popups[0].deadline - .popups[0].timestamp | . >= 4900 and . <= 5100' >/dev/null <<<"$plain_state"
ipc dismissAll >/dev/null
wait "$button_pid" 2>/dev/null || true

# A replacement-only update keeps identity and restarts the engine deadline.
replacement_id=$(send_notification -p -a lane-e -t 350 "replace-before")
sleep 0.2
send_notification -a lane-e -r "$replacement_id" -t 700 "replace-after"
sleep 0.25
jq -e '(.popups | length) == 1 and .popups[0].summary == "replace-after"' >/dev/null <<<"$(ipc state)"
sleep 0.25
jq -e '.popups | length == 1' >/dev/null <<<"$(ipc state)"
wait_for_json '(.popups | length) == 0' >/dev/null

# A stack tag continues one card: same key, new content, the old sender closed.
send_notification -a volume-tool -t 5000 -h string:x-dunst-stack-tag:volume -h int:value:30 "Volume"
first_volume=$(wait_for_json '.popups[0].hints.value == 30')
volume_key=$(jq -r '.popups[0].key' <<<"$first_volume")
send_notification -a volume-tool -t 5000 -h string:x-dunst-stack-tag:volume -h int:value:70 "Volume"
stacked=$(wait_for_json '.popups[0].hints.value == 70')
jq -e --arg key "$volume_key" '(.popups | length) == 1 and .popups[0].key == $key and .liveRefCount == 1' \
  >/dev/null <<<"$stacked"
send_notification -a other-tool -t 5000 -h string:x-dunst-stack-tag:volume -h int:value:10 "Volume"
wait_for_json '(.popups | length) == 2' >/dev/null
ipc dismissAll >/dev/null

# Named and default actions invoke the sender directly.
send_notification -a lane-e -t 5000 -A default=Open -A reply=Reply "named-action" >"$tmp_dir/named.out" &
named_pid=$!
wait_for_json '.popups[0].actions | map(.identifier) == ["default", "reply"]' >/dev/null
[[ $(ipc invokeFirst reply) == ok ]]
wait "$named_pid"
[[ $(<"$tmp_dir/named.out") == reply ]]
wait_for_json '(.popups | length) == 0' >/dev/null

# A resident notification stays after its action.
send_raw_notification resident-card '["default", "Open"]' '{"resident": <true>}'
wait_for_json '.popups[0].summary == "resident-card" and .popups[0].resident == true' >/dev/null
[[ $(ipc invokeFirst default) == ok ]]
sleep 0.3
jq -e '.popups[0].summary == "resident-card" and .liveRefCount == 1' >/dev/null <<<"$(ipc state)"
send_raw_notification plain-action-card '["default", "Open"]' '{}'
wait_for_json '.popups[0].summary == "plain-action-card"' >/dev/null
[[ $(ipc invokeFirst default) == ok ]]
wait_for_json '[.popups[] | select(.summary == "plain-action-card")] | length == 0' >/dev/null
ipc dismissAll >/dev/null

# Hover intent pauses one deck and queues arrivals until exit; leaving gives
# the paused card at least the 1.2 s grace instead of what it had left.
send_notification -a lane-e -t 400 "pause-me"
wait_for_json '.popups[0].summary == "pause-me"' >/dev/null
[[ $(ipc hoverFirst on) == ok ]]
sleep 0.5
jq -e '.popups[0].summary == "pause-me"' >/dev/null <<<"$(ipc state)"
send_notification -a another-app -t 5000 "queued-arrival"
paused_state=$(wait_for_json '.queuedArrivals | length == 1')
jq -e '.popups[0].summary == "pause-me"' >/dev/null <<<"$paused_state"
status_state=$(notification_status)
jq -e '.apiVersion == 2 and .counts.queuedArrivals == 1
  and .presentation.pausedNotificationCount == 1
  and (has("summary") | not) and (has("body") | not) and (has("urls") | not)' \
  >/dev/null <<<"$status_state"
[[ $(ipc hoverFirst off) == ok ]]
resumed=$(wait_for_json '(.queuedArrivals | length) == 0 and (.popups | length) == 2')
jq -e '.popups[] | select(.summary == "pause-me") | .deadline - $now | . >= 1000' \
  --argjson now "$(jq '.now' <<<"$resumed")" >/dev/null <<<"$resumed"
sleep 0.7
jq -e '[.popups[] | select(.summary == "pause-me")] | length == 1' >/dev/null <<<"$(ipc state)"
wait_for_json '[.popups[] | select(.summary == "pause-me")] | length == 0' >/dev/null
ipc dismissAll >/dev/null

# Quiet mode holds what is on screen and what arrives; critical breaks
# through; transient and stacked status cards are dropped; turning quiet off
# replays the held rows with their actions still live.
send_notification -a chat-app -t 5000 "visible-before-quiet"
wait_for_json '(.popups | length) == 1' >/dev/null
[[ $(ipc toggleQuiet) == on ]]
wait_for_json '.quiet and (.popups | length) == 0 and (.held | length) == 1 and .held[0].heldReason == "quiet"' >/dev/null
send_notification -a chat-app -t 5000 -A default=Open "held-with-action" >"$tmp_dir/held.out" &
held_pid=$!
wait_for_json '(.held | length) == 2 and .heldBadgeText == "2"' >/dev/null
send_notification -u critical -a any-app -t 5000 "critical-bypass"
wait_for_json '.popups[0].quietClass == "bypass"' >/dev/null
send_notification -e -a chat-app -t 5000 "ephemeral-quiet"
send_notification -a volume-tool -t 5000 -h string:x-dunst-stack-tag:volume -h int:value:50 "Volume"
sleep 0.3
jq -e '(.held | length) == 2 and (.popups | length) == 1' >/dev/null <<<"$(ipc state)"
jq -e '.quiet.active and .counts.held == 2' >/dev/null <<<"$(notification_status)"
[[ $(qs ipc --pid "$shell_pid" call stillsuit-notifications toggleQuiet) == off ]]
replayed=$(wait_for_json '(.quiet | not) and (.held | length) == 0 and (.popups | length) == 3')
jq -e '.popups | map(.summary) | index("held-with-action") != null and index("visible-before-quiet") != null' \
  >/dev/null <<<"$replayed"
jq -e '[.popups[] | select(.summary != "critical-bypass") | .deadline > 0] | all' >/dev/null <<<"$replayed"
held_key=$(jq -r '.popups[] | select(.summary == "held-with-action") | .key' <<<"$replayed")
[[ $(qs ipc --pid "$shell_pid" call stillsuit-notifications setQuiet maybe) == invalid ]]
ipc dismissAll >/dev/null
[[ -n $held_key ]]
wait "$held_pid" 2>/dev/null || true

# A replayed row's action still reaches its sender.
[[ $(ipc toggleQuiet) == on ]]
send_notification -a chat-app -t 5000 -A default=Open "replayed-action" >"$tmp_dir/replayed.out" &
replayed_pid=$!
wait_for_json '(.held | length) == 1' >/dev/null
[[ $(ipc toggleQuiet) == off ]]
wait_for_json '.popups[0].summary == "replayed-action"' >/dev/null
[[ $(ipc invokeFirst default) == ok ]]
wait "$replayed_pid"
[[ $(<"$tmp_dir/replayed.out") == default ]]

# A held row its sender raises to critical breaks through quiet at once.
[[ $(ipc toggleQuiet) == on ]]
raised_id=$(send_notification -p -a chat-app -t 5000 "raise-me")
wait_for_json '(.held | length) == 1' >/dev/null
send_notification -a chat-app -r "$raised_id" -u critical -t 5000 "raised"
raised=$(wait_for_json '(.held | length) == 0 and .popups[0].summary == "raised"')
jq -e '.quiet and .popups[0].quietClass == "bypass"' >/dev/null <<<"$raised"
[[ $(ipc toggleQuiet) == off ]]
ipc dismissAll >/dev/null

# A muted source is held while others show, and replays when unmuted.
send_notification -a source-one -t 5000 "source-one-before"
source_state=$(wait_for_json '.popups[0].summary == "source-one-before"')
source_key=$(jq -r '.popups[0].sourceKey' <<<"$source_state")
until_ms=$(ipc muteFirstSource)
[[ $until_ms =~ ^[0-9]+$ ]]
send_notification -a source-one -t 5000 "source-one-held"
send_notification -a source-two -t 5000 "source-two-visible"
muted=$(wait_for_json '.popups[0].summary == "source-two-visible" and (.held | length) == 2')
jq -e '.held | all(.heldReason == "source-mute")' >/dev/null <<<"$muted"
jq -e '.heldBadgeText == ""' >/dev/null <<<"$muted"
[[ $(ipc unmute "$source_key") == ok ]]
wait_for_json '(.held | length) == 0 and (.popups | length) == 3' >/dev/null
[[ $(ipc unmute "$source_key") == inactive ]]
ipc dismissAll >/dev/null

# At most five sources show, each with at most eight rows; the stalest go.
for index in {1..7}; do
  send_notification -a "deck-$index" -t 60000 "deck-$index"
done
decks_state=$(wait_for_json '(.decks | length) == 5')
jq -e '[.popups[].appName] | index("deck-1") == null and index("deck-2") == null and index("deck-7") != null' \
  >/dev/null <<<"$decks_state"
ipc dismissAll >/dev/null
for index in {1..10}; do
  send_notification -a busy-app -t 60000 "busy-$index"
done
rows_state=$(wait_for_json '(.popups | length) == 8')
jq -e '.decks == [{"key": "app:busy-app", "rows": 8}] and .popups[0].summary == "busy-10"
  and .popups[7].summary == "busy-3"' >/dev/null <<<"$rows_state"
wait_for_json '.liveRefCount == 8' >/dev/null

# One global service presents every toast on exactly one output.
presentation=$(ipc presentationProof)
jq -e '.outputA == 8 and .outputB == 0 and .overlap == 0' >/dev/null <<<"$presentation"
ipc dismissAll >/dev/null

# Quiet mode and held rows survive a restart; their actions do not.
[[ $(ipc toggleQuiet) == on ]]
send_notification -a chat-app -t 5000 -A default=Open "held-across-restart"
wait_for_json '(.held | length) == 1' >/dev/null
wait_for_state_file '.quiet == true and (.held | length) == 1'
stop_shell
start_shell
restored=$(wait_for_json '.quiet and (.held | length) == 1')
jq -e '.held[0].summary == "held-across-restart" and .liveRefCount == 0' >/dev/null <<<"$restored"
[[ $(ipc firstActionState) == expired ]]
[[ $(ipc toggleQuiet) == off ]]
wait_for_json '.popups[0].summary == "held-across-restart"' >/dev/null
ipc dismissAll >/dev/null

# A persisted popup keeps its absolute engine deadline across a restart.
send_notification -a lane-e -t 1200 "restart-deadline"
wait_for_json '.popups[0].summary == "restart-deadline"' >/dev/null
sleep 0.25
stop_shell
start_shell
wait_for_json '.popups[0].summary == "restart-deadline"' >/dev/null
[[ $(ipc firstActionState) == none ]]
wait_for_json '(.popups | length) == 0' >/dev/null

# A version 2 file loses its history and finite global snooze; its source
# snoozes become mutes.
stop_shell
future=$(( $(date +%s) * 1000 + 600000 ))
jq -n --argjson until "$future" '{
  schemaVersion: 2,
  snoozes: { "*": { until: $until }, "app:signal": { until: $until, startedAt: 1 } },
  popups: [],
  history: [{ key: "old-history", summary: "old-history", timestamp: 1 }]
}' >"$state_dir/notifications-v1.json"
start_shell
migrated=$(wait_for_json '(.quiet | not) and (.mutes | keys) == ["app:signal"]')
jq -e '(.held | length) == 0 and (.popups | length) == 0' >/dev/null <<<"$migrated"
wait_for_state_file '.schemaVersion == 3 and has("history") == false and has("snoozes") == false'
ipc unmute app:signal >/dev/null

# Held rows whose mute expired while the shell was down replay on start.
stop_shell
now_ms=$(( $(date +%s) * 1000 ))
jq -n --argjson now "$now_ms" '{
  schemaVersion: 3,
  quiet: false,
  mutes: { "app:signal": { until: ($now - 1000), startedAt: ($now - 3600000) } },
  popups: [],
  held: [{ key: "expired-mute", summary: "expired-mute", appName: "signal", timestamp: ($now - 5000),
    sourceKey: "app:signal", sourceLabel: "signal", heldReason: "source-mute" }]
}' >"$state_dir/notifications-v1.json"
start_shell
released=$(wait_for_json '(.held | length) == 0 and .popups[0].summary == "expired-mute"')
jq -e '.popups[0].deadline > 0 and .mutes == {}' >/dev/null <<<"$released"
ipc dismissAll >/dev/null

# Runtime cleanup drops an old live popup, closes its sender, and releases its ref.
send_notification -u critical -a lane-e -t 0 -A default=Open "old-live-cleanup" \
  >"$tmp_dir/old-live.out" &
old_live_pid=$!
old_live_state=$(wait_for_json '.popups[0].summary == "old-live-cleanup" and .liveRefCount == 1')
old_live_timestamp=$(jq -r '.popups[0].timestamp' <<<"$old_live_state")
prune_timestamp=$(jq -nr --argjson timestamp "$old_live_timestamp" \
  '$timestamp + (24 * 60 * 60 * 1000) + 1')
[[ $(ipc pruneAt "$prune_timestamp") == 1 ]]
wait_for_json '(.popups | length) == 0 and .liveRefCount == 0' >/dev/null
wait_for_pid_exit "$old_live_pid"

# Unknown hints are discarded before and after a process restart.
[[ $(ipc toggleQuiet) == on ]]
send_notification -a lane-e -t 250 -h "string:untrusted-command:touch $marker" "forged-hint"
hint_state=$(wait_for_json '.held[0].summary == "forged-hint"')
jq -e '.held[0].hints["untrusted-command"] == null' >/dev/null <<<"$hint_state"
[[ ! -e $marker ]]
wait_for_state_file '(.held | length) == 1'
stop_shell
start_shell
restarted_state=$(wait_for_json '.held[0].summary == "forged-hint"')
jq -e '.held[0].hints["untrusted-command"] == null' >/dev/null <<<"$restarted_state"
[[ $(ipc invokeFirst default) == unavailable ]]
[[ ! -e $marker ]]

# A bad record cannot poison valid held rows during the next restart.
stop_shell
jq '.held += [{"summary":"missing identity"}]' "$state_dir/notifications-v1.json" >"$tmp_dir/corrupt-state.json"
cp "$tmp_dir/corrupt-state.json" "$state_dir/notifications-v1.json"
start_shell
recovered_state=$(wait_for_json '.held | length == 1')
jq -e '.held[0].summary == "forged-hint"' >/dev/null <<<"$recovered_state"
[[ ! -e $marker ]]

# Evicting a held row past the limit releases its live notification reference.
ipc dismissAll >/dev/null
stop_shell
export STILLSUIT_NOTIFICATION_HELD_LIMIT=2
start_shell
for index in {1..3}; do
  send_notification -a lane-e -t 60000 "held-$index"
done
eviction_state=$(wait_for_json '(.held | length) == 2 and .liveRefCount == 2')
jq -e '.held | map(.summary) == ["held-3", "held-2"]' >/dev/null <<<"$eviction_state"

# Clear-all reaches disk before it returns, so a crash cannot restore old rows.
wait_for_state_file '(.held | length) == 2'
[[ $(ipc dismissAll) == ok ]]
if ! jq -e '(.popups | length) == 0 and (.held | length) == 0' \
  "$state_dir/notifications-v1.json" >/dev/null; then
  echo "clear-all did not synchronously persist empty notification state" >&2
  cat "$state_dir/notifications-v1.json" >&2
  exit 1
fi
crash_shell
start_shell
wait_for_json '(.popups | length) == 0 and (.held | length) == 0' >/dev/null

if grep -E ' ERROR| FATAL' "$tmp_dir/quickshell.log"; then
  echo "fixture shell logged a QML error" >&2
  exit 1
fi

echo "notification fixtures: ok"
