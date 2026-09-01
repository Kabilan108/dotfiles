#!/usr/bin/env bash
set -euo pipefail

fixture_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_root=$(cd -- "$fixture_dir/../.." && pwd)
tmp_dir=$(mktemp -d -t stillsuit-bar-v2.XXXXXXXX)
shell_pid=""
sway_pid=""

cleanup() {
    if [[ -n $shell_pid ]] && kill -0 "$shell_pid" 2>/dev/null; then
        kill -TERM "$shell_pid"
        wait "$shell_pid" || true
    fi
    if [[ -n $sway_pid ]] && kill -0 "$sway_pid" 2>/dev/null; then
        kill -TERM "$sway_pid"
        wait "$sway_pid" || true
    fi
    rm -rf -- "$tmp_dir"
}
trap cleanup EXIT

node "$fixture_dir/run-contracts.mjs"

export HOME="$tmp_dir/home"
export XDG_CONFIG_HOME="$tmp_dir/config"
export XDG_DATA_HOME="$tmp_dir/data"
export XDG_STATE_HOME="$tmp_dir/state"
export XDG_CACHE_HOME="$tmp_dir/cache"
export XDG_RUNTIME_DIR="$tmp_dir/runtime"
export QT_QPA_PLATFORM=wayland
unset DBUS_SESSION_BUS_ADDRESS
mkdir -p "$HOME" "$XDG_CONFIG_HOME/quickshell/stillsuit-bar-v2-fixture" \
    "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

sway_bin=$(command -v sway || true)
if [[ -z $sway_bin ]]; then
    sway_store=$(nix build --no-link --print-out-paths nixpkgs#sway)
    sway_bin="$sway_store/bin/sway"
fi
printf '%s\n' 'output * resolution 1280x720' > "$tmp_dir/sway.conf"
DBUS_SESSION_BUS_ADDRESS="unix:path=$tmp_dir/no-session-bus" \
    WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=2 WLR_LIBINPUT_NO_DEVICES=1 \
    WLR_RENDERER=pixman "$sway_bin" -c "$tmp_dir/sway.conf" \
    >"$tmp_dir/sway.log" 2>&1 &
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
    sed -n '1,240p' "$tmp_dir/sway.log" >&2
    printf 'headless sway fixture compositor did not start\n' >&2
    exit 1
fi
export WAYLAND_DISPLAY=${wayland_socket##*/}

config_dir="$XDG_CONFIG_HOME/quickshell/stillsuit-bar-v2-fixture"
cp "$fixture_dir/fixture-shell.qml" "$config_dir/shell.qml"
mkdir -p "$config_dir/plugins/builtin"
for plugin in bar clock workspaces osd; do
    cp -r "$source_root/plugins/builtin/$plugin" "$config_dir/plugins/builtin/$plugin"
done
cp -r "$source_root/ui" "$config_dir/ui"

qs --no-color -p "$config_dir" >"$tmp_dir/quickshell.log" 2>&1 &
shell_pid=$!

ipc() {
    qs ipc --pid "$shell_pid" call stillsuit-bar-v2-fixture "$@"
}

for _ in {1..120}; do
    if [[ $(ipc ready 2>/dev/null || true) == ready ]]; then
        break
    fi
    sleep 0.05
done
if [[ $(ipc ready) != ready ]]; then
    sed -n '1,260p' "$tmp_dir/quickshell.log" >&2
    printf 'bar v2 fixture did not become ready\n' >&2
    exit 1
fi

contracts=$(ipc contracts)
jq -e '
    .barHeight == 26 and .outerGap == 0 and .exclusionZone == 26
    and .constructionCount == 2
    and (.outputIds | length) == 2 and .outputIds[0] != .outputIds[1]
    and .primaryProductionWorkspaces == 1 and .secondaryProductionWorkspaces == 2
    and .primaryWorkspaces == 1 and .secondaryWorkspaces == 2
    and .secondaryColumns == 4 and .secondaryFocusedColumn == 2
    and .inline and .clockServiceInstances == 1
    and .osdViews == 2 and .osdOutputIds[0] != .osdOutputIds[1]
    and .sharedOsdService and .osdPanelBackground and .osdMediumRadius
    and .osdBorder and .osdTrack and .osdFillAssignment and .osdText
    and .audioSignal and .brightnessSignal and .microphoneSignal
    and .dictationErrorSignal and .dictationSurface and .accessible
' >/dev/null <<<"$contracts"

reduced=$(ipc reducedMotion)
jq -e '.workspaceDuration == 0 and .osdDuration == 0 and .dictationReduced' \
    >/dev/null <<<"$reduced"

if rg -n 'ERROR qml| ERROR:|Type .* unavailable|is not a type' "$tmp_dir/quickshell.log"; then
    printf 'bar v2 fixture logged a QML error\n' >&2
    exit 1
fi

printf 'bar v2 headless fixture: ok\n'
