#!/usr/bin/env bash
set -euo pipefail

fixture_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_root=$(cd -- "$fixture_dir/../.." && pwd)
tmp_dir=$(mktemp -d -t stillsuit-d4.XXXXXXXX)
shell_pid=""
sway_pid=""

cleanup() {
    if [[ -n "$shell_pid" ]] && kill -0 "$shell_pid" 2>/dev/null; then
        kill -TERM "$shell_pid"
        wait "$shell_pid" || true
    fi
    if [[ -n "$sway_pid" ]] && kill -0 "$sway_pid" 2>/dev/null; then
        kill -TERM "$sway_pid"
        wait "$sway_pid" || true
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
export STILLSUIT_FIXTURE_STAT="$tmp_dir/stat"
export STILLSUIT_FIXTURE_MEMINFO="$tmp_dir/meminfo"
export QT_QPA_PLATFORM=wayland
unset DBUS_SESSION_BUS_ADDRESS
mkdir -p "$HOME" "$XDG_CONFIG_HOME/quickshell/stillsuit-d4-fixture" "$XDG_DATA_HOME" \
    "$XDG_STATE_HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

sway_bin=$(command -v sway || true)
if [[ -z $sway_bin ]]; then
    sway_store=$(nix build --no-link --print-out-paths nixpkgs#sway)
    sway_bin="$sway_store/bin/sway"
fi
printf '%s\n' 'output * resolution 1280x720' > "$tmp_dir/sway.conf"
DBUS_SESSION_BUS_ADDRESS="unix:path=$tmp_dir/no-session-bus" \
    WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=2 WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=pixman \
    "$sway_bin" -c "$tmp_dir/sway.conf" >"$tmp_dir/sway.log" 2>&1 &
sway_pid=$!
wayland_socket=""
for _ in {1..100}; do
    for candidate in "$XDG_RUNTIME_DIR"/wayland-*; do
        if [[ -S $candidate ]]; then
            wayland_socket=$candidate
            break
        fi
    done
    [[ -n $wayland_socket ]] && break
    sleep 0.02
done
if [[ -z ${wayland_socket:-} ]]; then
    cat "$tmp_dir/sway.log" >&2
    echo "headless sway fixture compositor did not start" >&2
    exit 1
fi
export WAYLAND_DISPLAY=${wayland_socket##*/}

printf '%s\n' 'cpu 100 0 100 800 0 0 0 0 0 0' > "$STILLSUIT_FIXTURE_STAT"
printf '%s\n' 'MemTotal: 1000 kB' 'MemAvailable: 600 kB' > "$STILLSUIT_FIXTURE_MEMINFO"

config_dir="$XDG_CONFIG_HOME/quickshell/stillsuit-d4-fixture"
cp "$fixture_dir/fixture-shell.qml" "$config_dir/shell.qml"
cp "$fixture_dir/../FixtureTheme.js" "$config_dir/FixtureTheme.js"
cp -r "$source_root/ui" "$config_dir/ui"
mkdir -p "$config_dir/plugins/builtin"
for plugin in clock workspaces resources meeting recording; do
    cp -r "$source_root/plugins/builtin/$plugin" "$config_dir/plugins/builtin/$plugin"
done
cp -r "$source_root/plugins/builtin/bar" "$config_dir/plugins/builtin/bar"

for manifest in "$source_root"/plugins/builtin/{clock,workspaces,resources,meeting,recording}/manifest.json; do
    jq -e '.schemaVersion == 1 and (.id | startswith("stillsuit."))' "$manifest" >/dev/null
done
for manifest in "$source_root"/plugins/builtin/*/manifest.json; do
    if jq -e '.kinds | index("bar-widget") != null' "$manifest" >/dev/null; then
        widget_file=$(jq -r '.entryPoints.barWidget' "$manifest")
        rg -n 'required property string outputId' "${manifest%/*}/$widget_file" >/dev/null
    fi
done
jq -e '.kinds == ["service", "bar-widget"] and .scope.service == "global"' \
    "$source_root/plugins/builtin/clock/manifest.json" >/dev/null
jq -e '.kinds == ["service", "bar-widget"] and .scope.service == "global"
  and (.entryPoints | has("panel") | not)' \
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
jq -e '.clockServiceInstances == 1 and .resourceServiceInstances == 1 and .outputs == 2 and .clockViews == 2 and .workspaceViews == 2 and .resourceViews == 2 and .meetingViews == 2 and .recordingViews == 2 and .sharedClockService and .sharedResourceService' >/dev/null <<<"$topology"
production_bar=$(ipc productionBarSnapshot)
jq -e '.constructions == 2 and (.outputIds | length) == 2 and .outputIds[0] != .outputIds[1] and .primaryWorkspaces == 1 and .secondaryWorkspaces == 2' >/dev/null <<<"$production_bar"
workspace=$(ipc workspaceSnapshot)
jq -e '.primaryWorkspaces == 1 and .secondaryWorkspaces == 2 and .secondaryColumns == 4 and .secondaryFocusedColumn == 2' >/dev/null <<<"$workspace"
first_resources=$(ipc resourceSnapshot)
jq -e '.cpuPercent == 0 and .memoryPercent == 40' >/dev/null <<<"$first_resources"
printf '%s\n' 'cpu 200 0 200 1000 0 0 0 0 0 0' > "$STILLSUIT_FIXTURE_STAT"
printf '%s\n' 'MemTotal: 1000 kB' 'MemAvailable: 250 kB' > "$STILLSUIT_FIXTURE_MEMINFO"
second_resources=$(ipc resourceSnapshot)
jq -e '.cpuPercent == 50 and .memoryPercent == 75' >/dev/null <<<"$second_resources"
routes=$(ipc routeActions)
jq -e '. == ["stillsuit.recording", "stillsuit.recording"]' >/dev/null <<<"$routes"
workflow=$(ipc workflowState)
jq -e '.recordingText == "01:07" and .meetingText == "Minutes ready" and .meetingCompleted' >/dev/null <<<"$workflow"

if rg -n '(^| )?(ERROR|FATAL)(:| )' "$tmp_dir/quickshell.log"; then
    echo "fixture logged a QML error" >&2
    exit 1
fi

echo "d4 widgets fixture: ok"
