#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_root=$(cd -- "$script_dir/../.." && pwd)
plugin_root="$source_root/plugins/builtin/tray"
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
export STILLSUIT_CONFIG_ID=stillsuit-tray-fixture
unset DBUS_SESSION_BUS_ADDRESS

mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" \
    "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

jq -e '
    .schemaVersion == 1
    and .id == "stillsuit.tray"
    and (.kinds | sort) == ["bar-widget", "panel", "service"]
    and .scope.service == "global"
    and .keepLoaded == true
' "$plugin_root/manifest.json" >/dev/null

if rg -n '#[0-9a-fA-F]{6}|\.palette\.|theme\.(colors|controls|geometry)\.' "$plugin_root"; then
    printf 'tray source contains a raw or legacy palette reference\n' >&2
    exit 1
fi
if rg -n '^[^/]*(UseQApplication|\.display\()' "$plugin_root"; then
    printf 'tray source routes menus through the platform menu path\n' >&2
    exit 1
fi
rg -F 'import Quickshell.Services.SystemTray' "$plugin_root/Service.qml" >/dev/null
rg -F 'QsMenuOpener' "$plugin_root/Panel.qml" >/dev/null
rg -F 'readonly property bool hostedPanel: true' "$plugin_root/Panel.qml" >/dev/null
rg -F 'required property var screen' "$plugin_root/Panel.qml" >/dev/null
if rg -n '^[^/]*\b(Timer|Process|Socket)\b' "$plugin_root/Widget.qml" "$plugin_root/Panel.qml"; then
    printf 'tray views own state they should leave to the service\n' >&2
    exit 1
fi

fixture_config="$XDG_CONFIG_HOME/quickshell/$STILLSUIT_CONFIG_ID"
mkdir -p "$fixture_config/plugins" "$fixture_config/qml/Stillsuit"
cp -- "$script_dir/fixture-shell.qml" "$fixture_config/shell.qml"
cp -- "$script_dir/../FixtureTheme.js" "$fixture_config/FixtureTheme.js"
cp -R -- "$plugin_root" "$fixture_config/plugins/tray"
ln -s "$source_root/ui" "$fixture_config/qml/Stillsuit/Ui"
export QML_IMPORT_PATH="$fixture_config/qml"

if ! timeout 20s quickshell --config "$STILLSUIT_CONFIG_ID" --no-color \
        >"$fixture_root/quickshell.log" 2>&1; then
    sed -n '1,200p' "$fixture_root/quickshell.log" >&2
    exit 1
fi
if rg -n 'ERROR qml| ERROR:|TRAY_FIXTURE_FAIL|TypeError|ReferenceError' "$fixture_root/quickshell.log"; then
    sed -n '1,200p' "$fixture_root/quickshell.log" >&2
    exit 1
fi
grep -F 'TRAY_FIXTURE_OK' "$fixture_root/quickshell.log" >/dev/null
printf 'tray QML fixture ok\n'
