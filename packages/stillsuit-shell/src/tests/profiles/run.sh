#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_root=$(cd -- "$script_dir/../.." && pwd)
fixture_root=$(mktemp -d /tmp/stillsuit-profile-status.XXXXXXXX)

cleanup() {
    rm -rf -- "$fixture_root"
}
trap cleanup EXIT

export HOME="$fixture_root/home"
export XDG_CONFIG_HOME="$fixture_root/config"
export XDG_DATA_HOME="$fixture_root/data"
export XDG_STATE_HOME="$fixture_root/state"
export XDG_CACHE_HOME="$fixture_root/cache"
export XDG_RUNTIME_DIR="$fixture_root/runtime"
export QT_QPA_PLATFORM=offscreen
export STILLSUIT_PROFILE_FAILURE_HELPER
STILLSUIT_PROFILE_FAILURE_HELPER=$(type -P false)
unset DBUS_SESSION_BUS_ADDRESS

mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" \
    "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

config_dir="$XDG_CONFIG_HOME/stillsuit-profile-status-fixture"
cp -R -- "$source_root/." "$config_dir"
cp -- "$script_dir/status-fixture.qml" "$config_dir/shell.qml"
status_log="$fixture_root/status.log"
if ! timeout 20s quickshell --no-color -p "$config_dir" > "$status_log" 2>&1; then
    sed -n '1,240p' "$status_log" >&2
    exit 1
fi
if rg -n 'ERROR qml| ERROR:|PROFILE_STATUS_FIXTURE_FAIL' "$status_log"; then
    sed -n '1,240p' "$status_log" >&2
    exit 1
fi
rg -F 'PROFILE_STATUS_FIXTURE_OK' "$status_log" > /dev/null
printf 'profile status QML fixture: ok\n'
