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
config_dir="$tmp_dir/config"
state_dir="$tmp_dir/state"
mkdir -p "$config_dir/services" "$config_dir/notifications" "$state_dir"
cp "$fixture_dir/view-fixture-shell.qml" "$config_dir/shell.qml"
cp "$fixture_dir/../../services/NotificationModel.js" "$config_dir/services/NotificationModel.js"
cp "$fixture_dir/../../services/NotificationPolicy.js" "$config_dir/services/NotificationPolicy.js"
cp "$fixture_dir/../../services/NotificationService.qml" "$config_dir/services/NotificationService.qml"
cp "$fixture_dir/../../plugins/builtin/notifications/NotificationCard.qml" "$config_dir/notifications/NotificationCard.qml"
cp "$fixture_dir/../../plugins/builtin/notifications/NotificationCenter.qml" "$config_dir/notifications/NotificationCenter.qml"
cp "$fixture_dir/../../plugins/builtin/notifications/NotificationToasts.qml" "$config_dir/notifications/NotificationToasts.qml"
shell_pid=""

# shellcheck disable=SC2329 # Invoked by the EXIT trap.
cleanup() {
  if [[ -n $shell_pid ]] && kill -0 "$shell_pid" 2>/dev/null; then
    kill "$shell_pid"
    wait "$shell_pid" 2>/dev/null || true
  fi
  rm -rf -- "$tmp_dir"
}
trap cleanup EXIT

XDG_STATE_HOME="$state_dir" qs --no-color -p "$config_dir" >"$tmp_dir/quickshell.log" 2>&1 &
shell_pid=$!

for _ in {1..120}; do
  result=$(qs ipc --pid "$shell_pid" call stillsuit-notification-view-fixture ready 2>/dev/null || true)
  if [[ $result == ready ]]; then
    topology=$(qs ipc --pid "$shell_pid" call stillsuit-notification-view-fixture topology)
    jq -e '.serviceInstances == 1 and .outputs >= 1
      and .toastViews == .outputs and .centerViews == .outputs' >/dev/null <<<"$topology"
    if grep -E ' ERROR| FATAL' "$tmp_dir/quickshell.log"; then
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
