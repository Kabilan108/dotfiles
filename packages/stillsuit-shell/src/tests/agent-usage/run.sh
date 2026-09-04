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
export STILLSUIT_CONFIG_ID=stillsuit-agent-usage-fixture
unset DBUS_SESSION_BUS_ADDRESS

mkdir -p "$HOME" "$XDG_CONFIG_HOME/quickshell" "$XDG_DATA_HOME" "$XDG_STATE_HOME" \
    "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

python3 "$script_dir/helper_test.py"

owned_sources=(
    "$source_root/plugins/builtin/agent-usage"
    "$source_root/../bin/stillsuit-agent-usage"
)
if rg -n --glob '*.qml' --glob '*.py' \
        '#[0-9a-fA-F]{6}|\.palette\.|theme\.(colors|controls|geometry)\.' \
        "${owned_sources[@]}"; then
    printf 'agent usage source contains a raw or legacy palette reference\n' >&2
    exit 1
fi
if rg -n 'accessToken.*(?:print|json\.dumps)|Authorization.*result|stderr=.*PIPE' \
        "${owned_sources[@]}"; then
    printf 'agent usage source exposes credential material\n' >&2
    exit 1
fi
rg -F 'required property var screen' \
    "$source_root/plugins/builtin/agent-usage/Panel.qml" >/dev/null
rg -F 'screen: root.screen' \
    "$source_root/plugins/builtin/agent-usage/Panel.qml" >/dev/null
rg -F '"% left"' \
    "$source_root/plugins/builtin/agent-usage/Panel.qml" >/dev/null
if rg -F 'kind: "raised"' \
        "$source_root/plugins/builtin/agent-usage/Panel.qml"; then
    printf 'agent usage accounts must use the flat list layout\n' >&2
    exit 1
fi
test -f "$source_root/plugins/builtin/agent-usage/assets/codex.svg"
test -f "$source_root/plugins/builtin/agent-usage/assets/claude.svg"
jq -e '.barWidget.defaultSection == "right" and .barWidget.order == 0' \
    "$source_root/plugins/builtin/agent-usage/manifest.json" >/dev/null
jq -e '.barWidget.order > 0' \
    "$source_root/plugins/builtin/resources/manifest.json" >/dev/null

fixture_config="$XDG_CONFIG_HOME/quickshell/$STILLSUIT_CONFIG_ID"
cp -R -- "$source_root" "$fixture_config"
cp -- "$script_dir/fixture-shell.qml" "$fixture_config/shell.qml"

if ! timeout 20s quickshell --config "$STILLSUIT_CONFIG_ID" --no-color \
        >"$fixture_root/quickshell.log" 2>&1; then
    sed -n '1,260p' "$fixture_root/quickshell.log" >&2
    exit 1
fi
if rg -n 'ERROR qml| ERROR:|AGENT_USAGE_FIXTURE_FAIL' \
        "$fixture_root/quickshell.log"; then
    sed -n '1,260p' "$fixture_root/quickshell.log" >&2
    exit 1
fi
grep -F 'AGENT_USAGE_FIXTURE_OK' "$fixture_root/quickshell.log" >/dev/null
printf 'agent usage QML fixture ok\n'
