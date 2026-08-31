#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
fixture_tmp=$(mktemp -d)
wayland_display=${WAYLAND_DISPLAY:-}
wayland_runtime_dir=${XDG_RUNTIME_DIR:-}

cleanup() {
    rm -rf -- "$fixture_tmp"
}
trap cleanup EXIT

export HOME="$fixture_tmp/home"
export XDG_CONFIG_HOME="$fixture_tmp/config"
export XDG_DATA_HOME="$fixture_tmp/data"
export XDG_CACHE_HOME="$fixture_tmp/cache"
export XDG_STATE_HOME="$fixture_tmp/state"
export XDG_RUNTIME_DIR="$fixture_tmp/runtime"
export STILLSUIT_CONFIG_ID=stillsuit-d1-bar-fixture
unset DBUS_SESSION_BUS_ADDRESS
if [[ -n $wayland_display && $wayland_display != /* ]]; then
    export WAYLAND_DISPLAY="$wayland_runtime_dir/$wayland_display"
fi

mkdir -p "$HOME" "$XDG_CONFIG_HOME/quickshell" "$XDG_DATA_HOME" \
    "$XDG_CACHE_HOME" "$XDG_STATE_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
mkdir -p "$fixture_tmp/config-id/bar"
cp "$script_dir/fixture-shell.qml" "$fixture_tmp/config-id/shell.qml"
cp "$script_dir/../../plugins/builtin/bar/Bar.qml" "$fixture_tmp/config-id/bar/Bar.qml"
cp "$script_dir/../../plugins/builtin/bar/WidgetSlot.qml" "$fixture_tmp/config-id/bar/WidgetSlot.qml"

qs --no-color -p "$fixture_tmp/config-id"
