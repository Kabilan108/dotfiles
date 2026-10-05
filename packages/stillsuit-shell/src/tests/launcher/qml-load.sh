#!/usr/bin/env bash
# Loads every launcher model file through Quickshell's QML engine (V4), runs a
# few engine queries there and asserts per-keystroke budgets at 400 and 1,500 apps.

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
model_dir=$(cd -- "$script_dir/../../plugins/builtin/launcher/model" && pwd)
fixture_root=$(mktemp -d /tmp/stillsuit-launcher-qml.XXXXXXXX)

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
unset WAYLAND_DISPLAY DBUS_SESSION_BUS_ADDRESS

mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" \
    "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

config_dir="$XDG_CONFIG_HOME/stillsuit-launcher-qml-fixture"
mkdir -p "$config_dir"
cp -R -- "$model_dir" "$config_dir/model"
cp -- "$script_dir/qml-load-fixture.qml" "$config_dir/shell.qml"

log="$fixture_root/fixture.log"
status=0
timeout 60s quickshell --no-color -p "$config_dir" > "$log" 2>&1 || status=$?
if [[ $status -ne 0 ]] || grep -Eq 'ERROR|WARN qml|WARN scene|LAUNCHER_QML_FIXTURE_FAIL|TypeError|ReferenceError|SyntaxError' "$log" \
        || ! grep -Fq 'LAUNCHER_QML_FIXTURE_OK' "$log"; then
    sed -n '1,200p' "$log" >&2
    printf 'launcher QML fixture: failed (exit %s)\n' "$status" >&2
    exit 1
fi
grep -F 'LAUNCHER_QML_PERF' "$log" | sed 's/^.*LAUNCHER_QML_PERF/qml perf:/'
printf 'launcher QML fixture: ok\n'
