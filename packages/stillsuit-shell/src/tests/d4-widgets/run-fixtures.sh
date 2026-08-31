#!/usr/bin/env bash
set -euo pipefail

fixture_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_root=$(cd -- "$fixture_dir/../.." && pwd)
tmp_dir=$(mktemp -d -t stillsuit-d4.XXXXXXXX)
shell_pid=""

cleanup() {
    if [[ -n "$shell_pid" ]] && kill -0 "$shell_pid" 2>/dev/null; then
        kill -TERM "$shell_pid"
        wait "$shell_pid" || true
    fi
    rm -rf -- "$tmp_dir"
}
trap cleanup EXIT

export HOME="$tmp_dir/home"
export XDG_CONFIG_HOME="$tmp_dir/config"
export XDG_DATA_HOME="$tmp_dir/data"
export XDG_STATE_HOME="$tmp_dir/state"
export XDG_CACHE_HOME="$tmp_dir/cache"
export XDG_RUNTIME_DIR="$tmp_dir/runtime"
export QT_QPA_PLATFORM=offscreen
unset DBUS_SESSION_BUS_ADDRESS
mkdir -p "$HOME" "$XDG_CONFIG_HOME/quickshell/stillsuit-d4-fixture" "$XDG_DATA_HOME" \
    "$XDG_STATE_HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

config_dir="$XDG_CONFIG_HOME/quickshell/stillsuit-d4-fixture"
cp "$fixture_dir/fixture-shell.qml" "$config_dir/shell.qml"
for plugin in clock workspaces resources meeting recording; do
    cp -r "$source_root/plugins/builtin/$plugin" "$config_dir/$plugin"
done

for manifest in "$source_root"/plugins/builtin/{clock,workspaces,resources,meeting,recording}/manifest.json; do
    jq -e '.schemaVersion == 1 and (.id | startswith("stillsuit."))' "$manifest" >/dev/null
done
jq -e '.kinds == ["service", "bar-widget", "panel"] and .scope.service == "global"' \
    "$source_root/plugins/builtin/resources/manifest.json" >/dev/null
jq -e '.dependencies == ["stillsuit.workflows"]' "$source_root/plugins/builtin/meeting/manifest.json" >/dev/null
jq -e '.dependencies == ["stillsuit.workflows"]' "$source_root/plugins/builtin/recording/manifest.json" >/dev/null

qs --no-color -p "$config_dir" >"$tmp_dir/quickshell.log" 2>&1 &
shell_pid=$!

ipc() { qs ipc --pid "$shell_pid" call stillsuit-d4-fixture "$@"; }

for _ in {1..120}; do
    if [[ $(ipc ready 2>/dev/null || true) == ready ]]; then
        break
    fi
    sleep 0.05
done
if [[ $(ipc ready) != ready ]]; then
    cat "$tmp_dir/quickshell.log" >&2
    echo "d4 fixture did not become ready" >&2
    exit 1
fi

topology=$(ipc topology)
jq -e '.serviceInstances == 1 and .outputs == 2 and .clockViews == 2 and .workspaceViews == 2 and .resourceViews == 2 and .meetingViews == 2 and .recordingViews == 2 and .sharedResourceService' >/dev/null <<<"$topology"
workspace=$(ipc workspaceSnapshot)
jq -e '.primaryWorkspaces == 1 and .secondaryWorkspaces == 2 and .secondaryColumns == 4 and .secondaryFocusedColumn == 2' >/dev/null <<<"$workspace"
routes=$(ipc routeActions)
jq -e '. == ["stillsuit.meeting", "stillsuit.recording", "stillsuit.resources"]' >/dev/null <<<"$routes"
workflow=$(ipc workflowState)
jq -e '.recordingText == "01:07" and .meetingText == "Minutes ready" and .meetingCompleted' >/dev/null <<<"$workflow"

if rg -n '(^| )?(ERROR|FATAL)(:| )' "$tmp_dir/quickshell.log"; then
    echo "fixture logged a QML error" >&2
    exit 1
fi

echo "d4 widgets fixture: ok"
