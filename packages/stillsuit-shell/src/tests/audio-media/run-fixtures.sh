#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_root=$(cd -- "$script_dir/../.." && pwd)
fixture_root=$(mktemp -d)
sway_pid=""

cleanup() {
    if [[ -n $sway_pid ]] && kill -0 "$sway_pid" 2>/dev/null; then
        kill -TERM "$sway_pid"
        wait "$sway_pid" || true
    fi
    rm -rf -- "$fixture_root"
}
trap cleanup EXIT

export HOME="$fixture_root/home"
export XDG_CONFIG_HOME="$fixture_root/config"
export XDG_DATA_HOME="$fixture_root/data"
export XDG_STATE_HOME="$fixture_root/state"
export XDG_CACHE_HOME="$fixture_root/cache"
export XDG_RUNTIME_DIR="$fixture_root/runtime"
export QT_QPA_PLATFORM=wayland
export STILLSUIT_CONFIG_ID=stillsuit-audio-media-fixture
unset DBUS_SESSION_BUS_ADDRESS

mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" \
    "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

sway_bin=$(command -v sway || true)
if [[ -z $sway_bin ]]; then
    sway_store=$(nix build --no-link --print-out-paths nixpkgs#sway)
    sway_bin="$sway_store/bin/sway"
fi
printf '%s\n' 'output * resolution 1280x720' > "$fixture_root/sway.conf"
DBUS_SESSION_BUS_ADDRESS="unix:path=$fixture_root/no-session-bus" \
    WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=1 WLR_LIBINPUT_NO_DEVICES=1 \
    WLR_RENDERER=pixman "$sway_bin" -c "$fixture_root/sway.conf" \
    >"$fixture_root/sway.log" 2>&1 &
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
if [[ -z $wayland_socket ]]; then
    sed -n '1,260p' "$fixture_root/sway.log" >&2
    printf 'Headless fixture compositor did not start\n' >&2
    exit 1
fi
export WAYLAND_DISPLAY=${wayland_socket##*/}

fixture_config="$XDG_CONFIG_HOME/quickshell/$STILLSUIT_CONFIG_ID"
mkdir -p "$(dirname -- "$fixture_config")"
cp -R -- "$source_root" "$fixture_config"
cp -- "$script_dir/fixture-shell.qml" "$fixture_config/shell.qml"
# Shared-lane integration must add this descriptor to src/ui. The isolated
# fixture installs it only in its disposable config so plugin imports compile.
cp -- "$script_dir/ui.qmldir" "$fixture_config/ui/qmldir"

audio_service="$source_root/services/AudioService.qml"
media_service="$source_root/services/MediaService.qml"
audio_plugin="$source_root/plugins/builtin/audio"

if rg -n '#[0-9a-fA-F]{6}|\.palette\.|context\.theme\.(colors|controls)' \
        "$audio_plugin"; then
    printf 'Audio plugin bypasses theme-v2 roles\n' >&2
    exit 1
fi
if rg -n 'bash -lc|command:.*\+|command:.*\$\{|selectInput|per.?app|1\.5' \
        "$audio_service" "$media_service" "$audio_plugin"; then
    printf 'Audio/media source violates a locked boundary\n' >&2
    exit 1
fi

rg -F 'Math.max(0, Math.min(1, number))' "$audio_service" >/dev/null
rg -F 'selectOutputProcess.command = ["pactl", "set-default-sink", selectedName]' \
    "$audio_service" >/dev/null
rg -F 'readonly property var player: _selectedPlayer()' "$media_service" >/dev/null
rg -F 'context.actions.surfaceToggle("stillsuit.audio", "")' \
    "$audio_plugin/Widget.qml" >/dev/null
jq -e '.id == "stillsuit.audio"
    and .scope.service == "global"
    and (.capabilities | index("pipewire-control"))
    and (.capabilities | index("mpris-control"))' \
    "$audio_plugin/manifest.json" >/dev/null

quickshell --config "$STILLSUIT_CONFIG_ID" --no-color \
    >"$fixture_root/quickshell.log" 2>&1

if rg -n 'AUDIO_MEDIA_FIXTURE_FAIL|ERROR qml| ERROR:' \
        "$fixture_root/quickshell.log"; then
    sed -n '1,260p' "$fixture_root/quickshell.log" >&2
    exit 1
fi
result=$(rg -o 'AUDIO_MEDIA_FIXTURE_OK checks=[0-9]+' \
    "$fixture_root/quickshell.log")
if [[ -z $result ]]; then
    sed -n '1,260p' "$fixture_root/quickshell.log" >&2
    exit 1
fi

printf '%s\n' "$result"
