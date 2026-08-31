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
export STILLSUIT_CONFIG_ID="stillsuit-lane-d3-fixture"
unset DBUS_SESSION_BUS_ADDRESS

mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" \
    "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

fixture_config="$XDG_CONFIG_HOME/quickshell/$STILLSUIT_CONFIG_ID"
mkdir -p "$(dirname -- "$fixture_config")"
cp -R -- "$source_root" "$fixture_config"
cp -- "$script_dir/Fixture.qml" "$fixture_config/shell.qml"

manifest_paths=(
    "$source_root/plugins/builtin/audio/manifest.json"
    "$source_root/plugins/builtin/network/manifest.json"
    "$source_root/plugins/builtin/power/manifest.json"
    "$source_root/plugins/builtin/battery/manifest.json"
    "$source_root/plugins/builtin/bluetooth/manifest.json"
)

ids=$(jq -r '.id' "${manifest_paths[@]}")
[[ $(printf '%s\n' "$ids" | sort -u | wc -l) -eq 5 ]]
jq -e '(.schemaVersion == 1) and (.apiVersion == "1") and (.scope.service == "global") and (.entryPoints.service | endswith(".qml"))' "${manifest_paths[@]}" >/dev/null

rg -n 'bash -lc|command:.*\+|command:.*\$\{' "$source_root/services" "$source_root/plugins/builtin/audio" "$source_root/plugins/builtin/network" "$source_root/plugins/builtin/power" "$source_root/plugins/builtin/battery" "$source_root/plugins/builtin/bluetooth" >/dev/null && exit 1 || true
rg -F 'readonly property var helperArgv: ["powerprofilesctl", "get"]' "$source_root/services/PowerService.qml" >/dev/null
rg -F 'setProfileProcess.command = ["powerprofilesctl", "set", next]' "$source_root/services/PowerService.qml" >/dev/null

quickshell --config "$STILLSUIT_CONFIG_ID" --no-color >"$fixture_root/quickshell.log" 2>&1
grep -F 'D3_FIXTURE_OK singleton=5 outputs=2 unavailable=contained argv=fixed' "$fixture_root/quickshell.log" >/dev/null
