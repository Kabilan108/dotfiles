#!/usr/bin/env bash
# Menu hosting under a headless wlroots compositor: the router's menu branch,
# the parked and shown MenuHost surface states, and real keyboard input
# through a virtual keyboard, including focus returning to a toplevel. The
# headless seat has no pointer, so presses use the scrim's press handler.
set -euo pipefail
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_dir=$(cd -- "$test_dir/../.." && pwd)
fixture_dir=$(mktemp -d /tmp/stillsuit-menu-host.XXXXXXXX)
sway_pid=""
shell_pid=""
keyboard_pid=""
cleanup() {
    local status=$?
    if [[ $status -ne 0 && -f $fixture_dir/test.log ]]; then sed -n '1,200p' "$fixture_dir/test.log"; fi
    if [[ -n $sway_pid ]]; then kill -CONT "$sway_pid" 2>/dev/null || true; fi
    if [[ -n $shell_pid ]]; then kill -CONT "$shell_pid" 2>/dev/null || true; fi
    if [[ -n $shell_pid ]]; then kill -TERM "$shell_pid" 2>/dev/null || true; wait "$shell_pid" || true; fi
    if [[ -n $keyboard_pid ]]; then kill -TERM "$keyboard_pid" 2>/dev/null || true; wait "$keyboard_pid" || true; fi
    if [[ -n $sway_pid ]]; then kill -TERM "$sway_pid" 2>/dev/null || true; wait "$sway_pid" || true; fi
    rm -rf -- "$fixture_dir"
    exit "$status"
}
trap cleanup EXIT

tool() {
    local name=$1 package=$2 found
    found=$(command -v "$name" || true)
    if [[ -z $found ]]; then
        found="$(nix build --no-link --print-out-paths "nixpkgs#$package")/bin/$name"
    fi
    printf '%s' "$found"
}
sway_bin=$(tool sway sway)
wtype_bin=$(tool wtype wtype)
sway_command() {
    local sockets=("$fixture_dir"/runtime/sway-ipc.*.sock)
    "$(dirname -- "$sway_bin")/swaymsg" -s "${sockets[0]}" "$@" > /dev/null
}

mkdir -p "$fixture_dir/runtime" "$fixture_dir/home" "$fixture_dir/config"
chmod 700 "$fixture_dir/runtime"
cp -R "$source_dir" "$fixture_dir/shell"
cp "$test_dir/fixture-shell.qml" "$fixture_dir/shell/shell.qml"
python3 - "$fixture_dir/icon.png" <<'PNG'
import struct, sys, zlib
def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
rows = b"".join(b"\x00" + b"\x89\xb4\xfa\xff" * 16 for _ in range(16))
with open(sys.argv[1], "wb") as out:
    out.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 16, 16, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b""))
PNG
# The probe floats clear of the output's top-left corner, so the parked 1x1
# menu surface stays visible and keeps getting frame callbacks.
printf '%s\n' 'output * resolution 1280x720' \
    'for_window [title="menu-host-probe"] floating enable, move position 600 300' > "$fixture_dir/sway.conf"

# A dead session bus address and no DISPLAY keep D-Bus from autolaunching a
# session whose portals would mount FUSE file systems in the fixture runtime.
unset DISPLAY
env XDG_RUNTIME_DIR="$fixture_dir/runtime" DBUS_SESSION_BUS_ADDRESS="unix:path=$fixture_dir/no-bus" \
    WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=2 WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=pixman \
    "$sway_bin" -c "$fixture_dir/sway.conf" > "$fixture_dir/sway.log" 2>&1 &
sway_pid=$!
socket=""
for _ in {1..100}; do
    for candidate in "$fixture_dir/runtime"/wayland-*; do
        if [[ -S $candidate ]]; then socket=$candidate; break; fi
    done
    [[ -n $socket ]] && break
    sleep 0.02
done
if [[ -z $socket ]]; then sed -n '1,120p' "$fixture_dir/sway.log"; exit 1; fi
# The headless seat starts without a keyboard. A short-lived virtual keyboard
# per wtype call would add and remove the seat's keyboard capability around
# every keystroke, so one idle virtual keyboard stays for the whole run.
XDG_RUNTIME_DIR="$fixture_dir/runtime" WAYLAND_DISPLAY="$socket" "$wtype_bin" -s 600000 &
keyboard_pid=$!
export HOME="$fixture_dir/home" XDG_RUNTIME_DIR="$fixture_dir/runtime" \
    XDG_CONFIG_HOME="$fixture_dir/config" XDG_DATA_HOME="$fixture_dir/data" \
    XDG_STATE_HOME="$fixture_dir/state" XDG_CACHE_HOME="$fixture_dir/cache" \
    WAYLAND_DISPLAY="$socket" QT_QPA_PLATFORM=wayland \
    DBUS_SESSION_BUS_ADDRESS="unix:path=$fixture_dir/no-bus" \
    FIXTURE_ICON_PNG="$fixture_dir/icon.png"
quickshell --no-color -p "$fixture_dir/shell" > "$fixture_dir/test.log" 2>&1 &
shell_pid=$!

ipc() { quickshell ipc --pid "$shell_pid" call menu-host-test "$@"; }
field() { jq -r ".$1" <<<"$(ipc state)"; }
run_step() {
    local result
    result=$(ipc run "$1")
    if [[ $result != ok ]]; then
        printf 'menu-host step %s: %s\n' "$1" "$result" >&2
        exit 1
    fi
}
wait_for() {
    local description=$1 expression=$2
    for _ in {1..100}; do
        if jq -e "$expression" >/dev/null <<<"$(ipc state)"; then return 0; fi
        sleep 0.03
    done
    printf 'menu-host: timed out waiting for %s: %s\n' "$description" "$(ipc state)" >&2
    exit 1
}
type_text() { "$wtype_bin" "$@"; sleep 0.1; }

for _ in {1..150}; do
    [[ $(ipc phase 2>/dev/null || true) == ready ]] && break
    if ! kill -0 "$shell_pid" 2>/dev/null; then exit 1; fi
    sleep 0.05
done
[[ $(ipc phase) == ready ]] || exit 1

wait_for "the toplevel to take keyboard focus" '.probeFocus'
type_text a
wait_for "typing to reach the toplevel" '.probeText == "a"'

[[ $(ipc open '{"mode":"combi"}') == ok ]]
wait_for "the menu to draw and focus its field" '.drawn and .fieldFocus and (.probeFocus | not)'
run_step openGeometry
type_text b
"$wtype_bin" -k Down
"$wtype_bin" -M ctrl -k k -m ctrl
"$wtype_bin" -k Return
sleep 0.1
wait_for "keys to reach the menu" '.menuText == "b" and .downCount == 1 and .ctrlKCount == 1 and .acceptCount == 1'
run_step keys
run_step bannerAndPanels

run_step presses
wait_for "the closed menu to park" '(.menuOpen | not) and .presentedMenuId == "" and (.drawn | not)'
run_step parked
wait_for "focus to return to the toplevel" '.probeFocus'
type_text c
wait_for "typing to reach the toplevel again" '.probeText == "ac"'

[[ $(ipc open '{"mode":"combi"}') == ok ]]
wait_for "the reopened menu to take focus" '.drawn and .fieldFocus'
"$wtype_bin" -k Escape
wait_for "Escape to close the menu" '(.menuOpen | not)'
wait_for "focus to return after Escape" '.probeFocus'
type_text d
wait_for "typing to reach the toplevel after Escape" '.probeText == "acd"'

# The content holds focus from present on, before the surface grows.
run_step presentBeforeGrowth
[[ $(ipc close) == ok ]]
wait_for "focus to return after the before-growth check" '.probeFocus'

# Keys typed with no pause after opening.
run_step resetKeys
[[ $(ipc openTimed) == ok ]]
"$wtype_bin" term
"$wtype_bin" -k Down
wait_for "immediate keys to reach the menu" '.menuText == "term" and .downCount == 1'
run_step immediateKeys
[[ $(ipc close) == ok ]]
wait_for "focus to return after the immediate keys" '.probeFocus'

# A parked surface that commits under a fullscreen window stalls: open and
# close the menu over it, then open again.
sway_command '[title="menu-host-probe"] fullscreen enable'
sleep 0.2
[[ $(ipc open '{"mode":"combi"}') == ok ]]
wait_for "the menu to draw over the fullscreen probe" '.drawn and .fieldFocus'
[[ $(ipc close) == ok ]]
sleep 0.3
run_step resetKeys
[[ $(ipc openTimed) == ok ]]
wait_for "the stalled menu to take focus" '.drawn and .fieldFocus'
run_step stalledOpen
type_text x
wait_for "typing to reach the remapped menu" '.menuText == "x"'
[[ $(ipc close) == ok ]]
sway_command '[title="menu-host-probe"] fullscreen disable'
wait_for "focus to return after the stalled menu" '.probeFocus'

[[ $(ipc open '{"mode":"combi"}') == ok ]]
wait_for "the menu to draw for icon checks" '.drawn'
sleep 0.3
run_step icons
[[ $(ipc close) == ok ]]
run_step router
run_step reentrant
run_step queuedFocus
run_step startDestroyedMenu
sleep 0.2
run_step destroyedMenu
sleep 0.2
run_step destroyedPanel
run_step startScreenRemoval
sleep 0.3
run_step screenRemoval
run_step finish

for _ in {1..100}; do
    kill -0 "$shell_pid" 2>/dev/null || break
    sleep 0.02
done
if kill -0 "$shell_pid" 2>/dev/null; then echo "fixture did not exit"; exit 1; fi
result=0
wait "$shell_pid" || result=$?
shell_pid=""
if [[ $result -ne 0 ]] || rg -q 'MENU_HOST_FAIL|ERROR qml| ERROR:|TypeError|ReferenceError' "$fixture_dir/test.log"; then
    sed -n '1,200p' "$fixture_dir/test.log"; exit 1
fi
rg 'MENU_HOST_OK' "$fixture_dir/test.log"
