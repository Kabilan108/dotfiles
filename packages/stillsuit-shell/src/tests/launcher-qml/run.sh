#!/usr/bin/env bash
# Launcher service and menu in an offscreen shell: fixture desktop entries,
# a fake host context, and fake qalc and fd scripts that log each run so the
# fixture can check which lookups started, finished, or were terminated.
# The fd script runs the real fd for patterns containing "needle" against a search
# tree with a directory link into another volume and Nix-style result links.
# Set LAUNCHER_QML_SCREENSHOTS to a directory to keep the menu screenshots.
set -euo pipefail
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_dir=$(cd -- "$test_dir/../.." && pwd)
fixture_dir=$(mktemp -d /tmp/stillsuit-launcher-menu.XXXXXXXX)
shell_pid=""
cleanup() {
    local status=$?
    if [[ -n $shell_pid ]]; then kill -TERM "$shell_pid" 2>/dev/null || true; wait "$shell_pid" || true; fi
    pkill -KILL -f -- "$fixture_dir" 2>/dev/null || true
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
real_fd=$(tool fd fd)

mkdir -p "$fixture_dir/runtime" "$fixture_dir/home" "$fixture_dir/config" "$fixture_dir/state" \
    "$fixture_dir/data/applications" "$fixture_dir/system-data" "$fixture_dir/bin" \
    "$fixture_dir/search/src" "$fixture_dir/shots"
chmod 700 "$fixture_dir/runtime"
cp -R "$source_dir" "$fixture_dir/shell"
cp "$test_dir/fixture-shell.qml" "$fixture_dir/shell/shell.qml"
: >"$fixture_dir/log"

desktop() {
    printf '[Desktop Entry]\nType=Application\n%s\n' "$2" >"$fixture_dir/data/applications/$1.desktop"
}
desktop com.mitchellh.ghostty $'Name=Ghostty\nGenericName=Terminal\nExec=ghostty\nIcon=com.mitchellh.ghostty\nKeywords=shell;terminal;\nActions=new-window;\n\n[Desktop Action new-window]\nName=New Window\nExec=ghostty --new-window'
desktop obsidian $'Name=Obsidian\nComment=Knowledge base\nExec=obsidian %u\nIcon=obsidian'
desktop com.obsproject.Studio $'Name=OBS Studio\nGenericName=Streaming and Recording\nExec=obs\nIcon=com.obsproject.Studio'
desktop code $'Name=Visual Studio Code\nGenericName=Text Editor\nExec=code %F\nIcon=vscode'
desktop helium $'Name=Helium\nGenericName=Web Browser\nExec=helium %U\nIcon=helium'
desktop hidden-tool $'Name=Hidden Tool\nExec=hidden\nNoDisplay=true'

bash_bin=$(command -v bash)
cat >"$fixture_dir/bin/qalc" <<STUB
#!$bash_bin
log="\$LAUNCHER_FIXTURE_LOG"
expression="\${@: -1}"
printf 'qalc start %s\n' "\$*" >>"\$log"
case "\$expression" in
    "1+1")
        # Ignores SIGTERM, so its answer arrives after a newer request.
        trap '' TERM
        sleep 0.8
        printf 'qalc done 1+1\n' >>"\$log"
        echo 2 ;;
    "3*3") echo 9 ;;
    "2+2*3") echo 8 ;;
    *)
        sleep 5 >/dev/null &
        trap 'kill \$!; printf "qalc term %s\n" "\$expression" >>"\$log"; exit 143' TERM
        wait \$!
        echo 0 ;;
esac
STUB
cat >"$fixture_dir/bin/fd" <<STUB
#!$bash_bin
log="\$LAUNCHER_FIXTURE_LOG"
root="\${@: -1}"
pattern="\${@: -2:1}"
printf 'fd start %s\n' "\$*" >>"\$log"
case "\$pattern" in
    slow)
        sleep 5 >/dev/null &
        trap 'kill \$!; printf "fd term slow\n" >>"\$log"; exit 143' TERM
        wait \$! ;;
    main*) printf '%s\0' "\$root/src/main.qml" "\$root/docs/main-quick/" ;;
    partial)
        printf '%s\0%s' "\$root/partial-done.txt" "\$root/partial-cut"
        sleep 5 >/dev/null &
        trap 'kill \$!; exit 143' TERM
        wait \$! ;;
    *needle*) exec "$real_fd" "\$@" ;;
esac
STUB
chmod +x "$fixture_dir/bin/qalc" "$fixture_dir/bin/fd"

# The search root links a directory on another volume, as home directories
# link into /vault, and holds result links into a store tree with more
# matches than fd's result cap.
mkdir -p "$fixture_dir/vault/repos/project" "$fixture_dir/search/proj/node_modules/pkg"
: >"$fixture_dir/vault/repos/project/needle-vault.txt"
: >"$fixture_dir/search/proj/needle-src.txt"
: >"$fixture_dir/search/proj/node_modules/pkg/needle-module.txt"
ln -s "$fixture_dir/vault/repos" "$fixture_dir/search/repos"
for package in {1..30}; do
    mkdir -p "$fixture_dir/store/out/share/$package"
    for file in {1..10}; do : >"$fixture_dir/store/out/share/$package/needle-$file.txt"; done
done
ln -s "$fixture_dir/store/out" "$fixture_dir/search/result"
ln -s "$fixture_dir/store/out" "$fixture_dir/search/result-man"
ln -s "$fixture_dir/store/out" "$fixture_dir/search/proj/result"

python3 - "$fixture_dir/clip.png" <<'PNG'
import struct, sys, zlib
def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
rows = b"".join(b"\x00" + b"\x89\xb4\xfa\xff" * 32 for _ in range(24))
with open(sys.argv[1], "wb") as out:
    out.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 32, 24, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b""))
PNG

export HOME="$fixture_dir/home" XDG_RUNTIME_DIR="$fixture_dir/runtime" \
    XDG_CONFIG_HOME="$fixture_dir/config" XDG_DATA_HOME="$fixture_dir/data" \
    XDG_DATA_DIRS="$fixture_dir/system-data" \
    XDG_STATE_HOME="$fixture_dir/state" XDG_CACHE_HOME="$fixture_dir/cache" \
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    LAUNCHER_FIXTURE_LOG="$fixture_dir/log" \
    LAUNCHER_FIXTURE_STATE="$fixture_dir/state/stillsuit" \
    LAUNCHER_FIXTURE_SEARCH_ROOT="$fixture_dir/search" \
    LAUNCHER_FIXTURE_QALC="$fixture_dir/bin/qalc" \
    LAUNCHER_FIXTURE_FD="$fixture_dir/bin/fd" \
    LAUNCHER_FIXTURE_IMAGE="$fixture_dir/clip.png" \
    LAUNCHER_FIXTURE_APPLICATIONS="$fixture_dir/data/applications" \
    LAUNCHER_FIXTURE_SCREENSHOTS="$fixture_dir/shots"
unset DBUS_SESSION_BUS_ADDRESS DISPLAY WAYLAND_DISPLAY

quickshell --no-color -p "$fixture_dir/shell" >"$fixture_dir/test.log" 2>&1 &
shell_pid=$!
for _ in {1..1200}; do
    kill -0 "$shell_pid" 2>/dev/null || break
    sleep 0.05
done
if kill -0 "$shell_pid" 2>/dev/null; then
    sed -n '1,200p' "$fixture_dir/test.log"
    echo "launcher-qml fixture did not finish" >&2
    exit 1
fi
result=0
wait "$shell_pid" || result=$?
shell_pid=""

if [[ -n ${LAUNCHER_QML_SCREENSHOTS:-} ]]; then
    mkdir -p "$LAUNCHER_QML_SCREENSHOTS"
    cp "$fixture_dir"/shots/*.png "$LAUNCHER_QML_SCREENSHOTS"/ 2>/dev/null || true
fi

if [[ $result -ne 0 ]] || ! rg -q 'LAUNCHER_QML_OK' "$fixture_dir/test.log" \
        || rg -q 'LAUNCHER_QML_FAIL|ERROR qml| ERROR:|TypeError|ReferenceError|is not a type|Unable to assign' "$fixture_dir/test.log"; then
    sed -n '1,240p' "$fixture_dir/test.log"
    exit 1
fi
rg 'LAUNCHER_QML_OK' "$fixture_dir/test.log"
