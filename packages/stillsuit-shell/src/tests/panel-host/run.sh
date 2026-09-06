#!/usr/bin/env bash
set -euo pipefail
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_dir=$(cd -- "$test_dir/../.." && pwd)
fixture_dir=$(mktemp -d /tmp/stillsuit-panel-host.XXXXXXXX)
sway_pid=""
shell_pid=""
cleanup() {
    local status=$?
    if [[ $status -ne 0 && -f $fixture_dir/test.log ]]; then cat "$fixture_dir/test.log"; fi
    if [[ -n $shell_pid ]]; then kill -TERM "$shell_pid" 2>/dev/null || true; wait "$shell_pid" || true; fi
    if [[ -n $sway_pid ]]; then kill -TERM "$sway_pid" 2>/dev/null || true; wait "$sway_pid" || true; fi
    rm -rf -- "$fixture_dir"
    exit "$status"
}
trap cleanup EXIT
mkdir -p "$fixture_dir/runtime" "$fixture_dir/home" "$fixture_dir/config"
chmod 700 "$fixture_dir/runtime"
cp -R "$source_dir" "$fixture_dir/shell"
cp "$test_dir/fixture-shell.qml" "$fixture_dir/shell/shell.qml"
printf '%s\n' 'output * resolution 1280x720' > "$fixture_dir/sway.conf"
sway_bin=$(command -v sway || true)
if [[ -z $sway_bin ]]; then
    sway_store=$(nix build --no-link --print-out-paths nixpkgs#sway)
    sway_bin="$sway_store/bin/sway"
fi
env XDG_RUNTIME_DIR="$fixture_dir/runtime" DBUS_SESSION_BUS_ADDRESS="unix:path=$fixture_dir/no-bus" \
    WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=2 WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=pixman \
    "$sway_bin" -c "$fixture_dir/sway.conf" > "$fixture_dir/sway.log" 2>&1 &
sway_pid=$!
socket=""
for attempt in {1..100}; do
    for candidate in "$fixture_dir/runtime"/wayland-*; do
        if [[ -S $candidate ]]; then socket=$candidate; break; fi
    done
    [[ -n $socket ]] && break
    sleep 0.02
done
if [[ -z $socket ]]; then sed -n '1,120p' "$fixture_dir/sway.log"; exit 1; fi
export HOME="$fixture_dir/home" XDG_RUNTIME_DIR="$fixture_dir/runtime" \
    XDG_CONFIG_HOME="$fixture_dir/config" XDG_DATA_HOME="$fixture_dir/data" \
    XDG_STATE_HOME="$fixture_dir/state" XDG_CACHE_HOME="$fixture_dir/cache" \
    WAYLAND_DISPLAY="$socket" QT_QPA_PLATFORM=wayland
unset DBUS_SESSION_BUS_ADDRESS
quickshell --no-color -p "$fixture_dir/shell" > "$fixture_dir/test.log" 2>&1 &
shell_pid=$!
ipc() { quickshell ipc --pid "$shell_pid" call panel-host-test "$@"; }
for attempt in {1..150}; do
    [[ $(ipc phase 2>/dev/null || true) == ready ]] && break
    if ! kill -0 "$shell_pid" 2>/dev/null; then cat "$fixture_dir/test.log"; exit 1; fi
    sleep 0.05
done
if [[ $(ipc phase) != ready ]]; then cat "$fixture_dir/test.log"; exit 1; fi
click() {
    [[ $(ipc press "$1") == ok ]]
    sleep 0.1
}
click 20
[[ $(ipc checkPointer widget) == ok ]]
click 640
[[ $(ipc checkPointer background) == ok ]]
for attempt in {1..100}; do
    kill -0 "$shell_pid" 2>/dev/null || break
    sleep 0.02
done
if kill -0 "$shell_pid" 2>/dev/null; then echo "fixture did not exit"; exit 1; fi
result=0
wait "$shell_pid" || result=$?
shell_pid=""
if [[ $result -ne 0 ]] || rg -q 'PANEL_HOST_FAIL|ERROR qml| ERROR:' "$fixture_dir/test.log"; then
    sed -n '1,200p' "$fixture_dir/test.log"; exit 1
fi
rg 'PANEL_HOST_OK' "$fixture_dir/test.log"
