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
cp "$fixture_dir/../../plugins/builtin/notifications/NotificationCenter.qml" \
  "$config_dir/src/plugins/builtin/notifications/NotificationCenter.qml"
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

for _ in {1..120}; do
  result=$(qs ipc --pid "$shell_pid" call stillsuit-notification-view-fixture ready 2>/dev/null || true)
  if [[ $result == ready ]]; then
    [[ $(qs ipc --pid "$shell_pid" call stillsuit-notification-view-fixture seedRows) == ok ]]
    sleep 0.1
    topology=$(qs ipc --pid "$shell_pid" call stillsuit-notification-view-fixture topology)
    jq -e '.serviceInstances == 1 and .outputs >= 1
      and .toastViews == .outputs and .centerViews == .outputs
      and .widgetViews == .outputs and .rowsSeeded
      and .centerRows == 2 and .toastRows == 1' >/dev/null <<<"$topology"
    view_ipc() { qs ipc --pid "$shell_pid" call stillsuit-notification-view-fixture "$@"; }

    # Hidden keepLoaded centers derive nothing; the presented one sees every row.
    jq -e '.trackedCount == 2 and (.views | all(.rows == 0 and .sections == 0))' \
      >/dev/null <<<"$(view_ipc centers)"
    first_output=$(jq -r '.views[0].outputId' <<<"$(view_ipc centers)")
    jq -e --arg output "$first_output" '.views | map(select(.outputId == $output))
      | all(.presented and .rows == 2 and .sections == 1)' >/dev/null <<<"$(view_ipc openCenter)"
    jq -e '.views | all(.rows == 0)' >/dev/null <<<"$(view_ipc closeCenter)"

    # A revision updates toast decks in place; only a new source adds a deck.
    jq -e '.deckKeys == ["app:fixture"] and .capturedDeckAlive' >/dev/null <<<"$(view_ipc captureDeck)"
    sleep 0.1
    jq -e '.capturedDeckAlive and .capturedSummaries == ["Toast row (updated)"] and .enteredAll' \
      >/dev/null <<<"$(view_ipc touchToast toast-row)"
    jq -e '.capturedDeckAlive and .capturedRows == ["same-source", "toast-row"]
      and .expandedCards == 1' >/dev/null <<<"$(view_ipc addToast same-source app:fixture)"
    jq -e '.capturedDeckAlive and .expandedCards == 1' >/dev/null <<<"$(view_ipc captureDeck)"
    jq -e '.capturedDeckAlive and .capturedCardAlive and .capturedRead == [false, true]' \
      >/dev/null <<<"$(view_ipc decks)"
    jq -e '.capturedDeckAlive and .capturedCardAlive and .capturedRead == [true, true]' \
      >/dev/null <<<"$(view_ipc markToastsRead)"
    jq -e '.deckKeys == ["app:other", "app:fixture"] and .capturedDeckAlive
      and .capturedCardAlive' >/dev/null <<<"$(view_ipc addToast other-source app:other)"
    sleep 0.1
    jq -e '.enteredAll' >/dev/null <<<"$(view_ipc decks)"

    # A same-source arrival that takes over the front card mid-swipe is not the
    # one dismissed: the swipe archives the notification it started on, and
    # the arrival shows in place with no leftover drag offset.
    [[ $(view_ipc swipeWithArrival app:other) == other-source ]]
    sleep 0.6
    jq -e '.deckAlive and .frontKey == "new-arrival" and .frontDragOffset == 0
      and (.popups | index("new-arrival")) != null and (.popups | index("other-source")) == null
      and (.dismissed | index("other-source")) != null
      and (.dismissed | index("new-arrival")) == null' >/dev/null <<<"$(view_ipc swipeState app:other)"
    if grep -E ' ERROR| FATAL|Cannot create delegate|Required property theme' \
        "$tmp_dir/quickshell.log"; then
      echo "view fixture logged a QML error" >&2
      exit 1
    fi
    echo "notification view fixture: ok"
    exit 0
  fi
  sleep 0.05
done

cat "$tmp_dir/quickshell.log" >&2
echo "notification view fixture did not become ready" >&2
exit 1
