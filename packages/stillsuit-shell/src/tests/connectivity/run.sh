#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_root=$(cd -- "$script_dir/../.." && pwd)
fixture_root=$(mktemp -d)

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
export STILLSUIT_CONFIG_ID=stillsuit-connectivity-fixture
unset DBUS_SESSION_BUS_ADDRESS

mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" \
    "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

fixture_config="$XDG_CONFIG_HOME/quickshell/$STILLSUIT_CONFIG_ID"
mkdir -p "$(dirname -- "$fixture_config")"
cp -R -- "$source_root" "$fixture_config"
cp -- "$script_dir/fixture-shell.qml" "$fixture_config/shell.qml"

python3 "$script_dir/helper_test.py"

owned_sources=(
    "$source_root/services/NetworkService.qml"
    "$source_root/services/BluetoothService.qml"
    "$source_root/plugins/builtin/network"
    "$source_root/plugins/builtin/bluetooth"
)

if rg -n '#[0-9a-fA-F]{6}|\.palette\.|theme\.(colors|controls|geometry)\.' "${owned_sources[@]}"; then
    printf 'connectivity source contains a raw or legacy palette reference\n' >&2
    exit 1
fi
if rg -n 'bash -lc|sh -c|password.*command|command:.*password|last.*password' "${owned_sources[@]}"; then
    printf 'connectivity source exposes a shell or password command path\n' >&2
    exit 1
fi

rg -F 'stdinEnabled: true' "$source_root/services/NetworkService.qml" >/dev/null
rg -F 'helper.write(JSON.stringify(request) + "\n")' "$source_root/services/NetworkService.qml" >/dev/null
rg -F 'name === "MobergAnalytics"' "$source_root/plugins/builtin/network/Panel.qml" >/dev/null
rg -F 'read-only' "$source_root/plugins/builtin/network/Panel.qml" >/dev/null
rg -F 'preferredDefaultAudioSink = node' "$source_root/services/BluetoothService.qml" >/dev/null
rg -F 'onClicked: root.service.forgetDevice(row.device)' "$source_root/plugins/builtin/bluetooth/Panel.qml" >/dev/null

for panel in network bluetooth; do
    panel_path="$source_root/plugins/builtin/$panel/Panel.qml"
    rg -F 'required property var screen' "$panel_path" >/dev/null
    rg -F 'screen: root.screen' "$panel_path" >/dev/null
done

if ! timeout 20s quickshell --config "$STILLSUIT_CONFIG_ID" --no-color \
        >"$fixture_root/quickshell.log" 2>&1; then
    sed -n '1,260p' "$fixture_root/quickshell.log" >&2
    exit 1
fi
if rg -n 'ERROR qml| ERROR:|CONNECTIVITY_FIXTURE_FAIL' "$fixture_root/quickshell.log"; then
    sed -n '1,260p' "$fixture_root/quickshell.log" >&2
    exit 1
fi
grep -F 'CONNECTIVITY_FIXTURE_OK' "$fixture_root/quickshell.log" >/dev/null
printf 'connectivity QML fixture ok\n'
