#!/usr/bin/env bash
set -euo pipefail

fixture_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ ${STILLSUIT_NOTIFICATION_VIEW_TEST_BUS:-} != 1 ]]; then
  exec dbus-run-session --config-file="$fixture_dir/session-bus.conf" -- \
    env STILLSUIT_NOTIFICATION_VIEW_TEST_BUS=1 "$0" "$@"
fi

if [[ -z ${DBUS_SESSION_BUS_ADDRESS:-} ]]; then
  echo "view fixture bug: no private D-Bus session" >&2
  exit 1
fi

tmp_dir=$(mktemp -d -t stillsuit-notification-views.XXXXXXXX)
fixture_home_dir="$tmp_dir/home"
config_home_dir="$tmp_dir/xdg-config"
data_home_dir="$tmp_dir/xdg-data"
cache_home_dir="$tmp_dir/xdg-cache"
state_dir="$tmp_dir/xdg-state"
runtime_dir="$tmp_dir/xdg-runtime"
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
  "$XDG_STATE_HOME" "$XDG_RUNTIME_DIR" "$config_dir/src/services" \
  "$config_dir/src/ui" "$config_dir/src/plugins/builtin/notifications"
chmod 700 "$runtime_dir"
cp "$fixture_dir/view-fixture-shell.qml" "$config_dir/shell.qml"
cp "$fixture_dir/../../services/NotificationModel.js" "$config_dir/src/services/NotificationModel.js"
cp "$fixture_dir/../../services/NotificationPolicy.js" "$config_dir/src/services/NotificationPolicy.js"
cp "$fixture_dir/../../services/NotificationSource.js" "$config_dir/src/services/NotificationSource.js"
cp "$fixture_dir/../../services/NotificationLinks.js" "$config_dir/src/services/NotificationLinks.js"
cp "$fixture_dir/../../services/NotificationLayout.js" "$config_dir/src/services/NotificationLayout.js"
cp "$fixture_dir/../../services/NotificationService.qml" "$config_dir/src/services/NotificationService.qml"
cp "$fixture_dir/../../ui/"*.qml "$config_dir/src/ui/"
cp "$fixture_dir/../../plugins/builtin/notifications/NotificationCard.qml" \
  "$config_dir/src/plugins/builtin/notifications/NotificationCard.qml"
cp "$fixture_dir/../../plugins/builtin/notifications/Motion.js" \
  "$config_dir/src/plugins/builtin/notifications/Motion.js"
cp "$fixture_dir/../../plugins/builtin/notifications/SpringValue.qml" \
  "$config_dir/src/plugins/builtin/notifications/SpringValue.qml"
cp "$fixture_dir/../../plugins/builtin/notifications/NotificationToasts.qml" \
  "$config_dir/src/plugins/builtin/notifications/NotificationToasts.qml"
cp "$fixture_dir/../../plugins/builtin/notifications/NotificationDeck.qml" \
  "$config_dir/src/plugins/builtin/notifications/NotificationDeck.qml"
cp "$fixture_dir/../../plugins/builtin/notifications/Widget.qml" \
  "$config_dir/src/plugins/builtin/notifications/Widget.qml"
cp "$fixture_dir/../../../design-lab/themes/catppuccin-mocha.json" "$config_dir/theme.json"
export STILLSUIT_NOTIFICATION_VIEW_THEME="$config_dir/theme.json"
shell_pid=""

assert_private_environment() {
  local variable_name variable_value
  for variable_name in HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME XDG_RUNTIME_DIR; do
    variable_value=${!variable_name}
    if [[ $variable_value != "$tmp_dir"/* ]]; then
      printf 'view fixture bug: %s is outside temporary root: %s\n' "$variable_name" "$variable_value" >&2
      return 1
    fi
  done
}

assert_private_environment

# shellcheck disable=SC2329 # Invoked by the EXIT trap.
cleanup() {
  if [[ -n $shell_pid ]] && kill -0 "$shell_pid" 2>/dev/null; then
    kill "$shell_pid"
    wait "$shell_pid" 2>/dev/null || true
  fi
  rm -rf -- "$tmp_dir"
}
trap cleanup EXIT

qs --no-color -p "$config_dir" >"$tmp_dir/quickshell.log" 2>&1 &
shell_pid=$!

view_ipc() { qs ipc --pid "$shell_pid" call stillsuit-notification-view-fixture "$@"; }

wait_view() {
  local expression=$1 _ state
  for _ in {1..80}; do
    state=$(view_ipc state 2>/dev/null || true)
    if [[ -n $state ]] && jq -e "$expression" >/dev/null 2>&1 <<<"$state"; then
      printf '%s\n' "$state"
      return 0
    fi
    sleep 0.05
  done
  echo "view condition timed out: $expression" >&2
  view_ipc state >&2 || true
  return 1
}

ready=""
for _ in {1..120}; do
  if [[ $(view_ipc ready 2>/dev/null || true) == ready ]]; then ready=1; break; fi
  sleep 0.05
done
if [[ -z $ready ]]; then
  cat "$tmp_dir/quickshell.log" >&2
  echo "notification view fixture did not become ready" >&2
  exit 1
fi

jq -e '.outputs >= 1 and .toastViews == .outputs and .widgetViews == .outputs' \
  >/dev/null <<<"$(view_ipc topology)"
slot() { printf '.decks[] | select(.key == "%s") | .slots[] | select(.key == "%s")' "$1" "$2"; }
deck() { printf '.decks[] | select(.key == "%s")' "$1"; }

# A new card enters from the edge, faded, and settles in place.
entering=$(view_ipc add a app:one)
jq -e "$(slot app:one a) | .presence < 0.5 and .offsetX > 24" >/dev/null <<<"$entering"
wait_view "$(slot app:one a) | .presence == 1 and .offsetX == 0" >/dev/null

# A revision updates the card in place; a same-source arrival goes in front
# and the earlier card moves back into the peek.
view_ipc capture >/dev/null
jq -e "$(slot app:one a) | .alive" >/dev/null <<<"$(view_ipc touch a)"
view_ipc add b app:one >/dev/null
stacked=$(wait_view "$(slot app:one b) | .presence == 1")
jq -e "[$(deck app:one) | .slots[].key] == [\"b\", \"a\"] and ($(slot app:one a) | .alive and .y == 10)" \
  >/dev/null <<<"$stacked"

# Decks stack top-down, newest source first.
view_ipc add c app:two >/dev/null
view_ipc add d app:three >/dev/null
layout=$(wait_view "($(deck app:two) | .y == .targetY) and ($(deck app:one) | .y == .targetY)
  and ($(slot app:three d) | .presence == 1)")
jq -e "[.decks[].key] | contains([\"app:three\", \"app:two\", \"app:one\"])" >/dev/null <<<"$layout"
jq -e "($(deck app:two) | .targetY) - ($(deck app:three) | .layoutHeight) | . > 0 and . <= 24" >/dev/null <<<"$layout"
jq -e "($(deck app:one) | .targetY) - ($(deck app:two) | .targetY) == ($(deck app:two) | .targetY)" \
  >/dev/null <<<"$layout"
before_y=$(jq "$(deck app:one) | .targetY" <<<"$layout")

# Removing the middle source: its card leaves in place while the deck below
# moves up at once, and every other delegate survives the mid-list removal.
view_ipc capture >/dev/null
leaving=$(view_ipc dismiss c)
jq -e "($(deck app:two) | .exiting) and ($(slot app:two c) | .exiting)" >/dev/null <<<"$leaving"
moving=$(view_ipc state)
jq -e --argjson before "$before_y" "($(deck app:one) | .targetY) < \$before
  and ($(deck app:one) | .y) > ($(deck app:one) | .targetY)" >/dev/null <<<"$moving"
wait_view '[.decks[].key] | index("app:two") == null' >/dev/null
jq -e 'all(.alive)' >/dev/null <<<"$(view_ipc decksAlive)"
wait_view "($(deck app:one) | .y == .targetY)" >/dev/null

# A flick carries its speed into the exit; the card behind steps forward.
swiped=$(view_ipc swipe b)
jq -e "$(slot app:one b) | .exiting and .offsetX >= 120" >/dev/null <<<"$swiped"
sleep 0.05
jq -e "$(slot app:one b) | .offsetX > 140" >/dev/null <<<"$(view_ipc state)"
wait_view "[$(deck app:one) | .slots[].key] == [\"a\"] and ($(slot app:one a) | .y == 0)" >/dev/null
jq -e '.popups | index("b") == null' >/dev/null <<<"$(view_ipc state)"

# A drag that does not reach the threshold springs back and keeps the card.
jq -e "$(slot app:one a) | .exiting | not" >/dev/null <<<"$(view_ipc snapBack a)"
wait_view "$(slot app:one a) | .offsetX == 0 and (.exiting | not)" >/dev/null

# Hover spreads a deck into a list; leaving folds it back into the peek.
view_ipc add e app:one >/dev/null
wait_view "$(slot app:one e) | .presence == 1" >/dev/null
view_ipc expand app:one >/dev/null
spread=$(wait_view "($(deck app:one) | .expanded) and ($(slot app:one a) | .y > 40)")
jq -e "($(deck app:one) | .layoutHeight) > ($(slot app:one a) | .y)" >/dev/null <<<"$spread"
view_ipc collapse >/dev/null
wait_view "$(slot app:one a) | .y == 10" >/dev/null

# The bell toggles quiet: every toast leaves and the overlay unmaps after the
# last exit; turning quiet off replays them.
quiet=$(view_ipc clickWidget)
jq -e '.quiet and .icon == "notifications-off" and .label == "3"' >/dev/null <<<"$quiet"
jq -e '(.rendered | length) > 0 and all(.decks[]; .exiting)' >/dev/null <<<"$(view_ipc state)"
wait_view '(.rendered | length) == 0 and .extent == 0 and (.held | length) == 3' >/dev/null
jq -e '(.quiet | not) and .icon == "notifications" and .label == ""' >/dev/null <<<"$(view_ipc clickWidget)"
wait_view '(.popups | length) == 3 and all(.decks[].slots[]; .presence == 1)' >/dev/null

if grep -E ' ERROR| FATAL|Cannot create delegate|Required property|TypeError|ReferenceError|is not defined' \
    "$tmp_dir/quickshell.log"; then
  echo "view fixture logged a QML error" >&2
  exit 1
fi
echo "notification view fixture: ok"
