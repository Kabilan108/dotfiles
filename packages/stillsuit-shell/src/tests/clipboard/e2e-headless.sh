#!/usr/bin/env bash
# Real wl-clipboard against a private headless sway. Never touches the host
# session: WAYLAND_DISPLAY and XDG_RUNTIME_DIR point at the nested compositor.
# Needs sway, wl-copy and wl-paste on PATH. With STILLSUIT_CLIPBOARD_COLLECTOR
# set to a built wrapper, it also runs the wrapper with a PATH holding only
# wl-clipboard, as the service does.

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_root=$(cd -- "$script_dir/../.." && pwd)
collector=${STILLSUIT_CLIPBOARD_COLLECTOR:-$(cd -- "$source_root/.." && pwd)/bin/stillsuit-clipboard-collector}
root=$(mktemp -d)
sway_pid=""
watch_pid=""

cleanup() {
    [[ -n $watch_pid ]] && kill "$watch_pid" 2>/dev/null || true
    [[ -n $sway_pid ]] && kill "$sway_pid" 2>/dev/null || true
    wait 2>/dev/null || true
    rm -rf -- "$root"
}
trap cleanup EXIT

unset WAYLAND_DISPLAY DISPLAY SWAYSOCK
export XDG_RUNTIME_DIR="$root/runtime"
mkdir -m 700 "$XDG_RUNTIME_DIR"
export WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1
printf '' >"$root/sway.conf"
sway --config "$root/sway.conf" >"$root/sway.log" 2>&1 &
sway_pid=$!
for _ in $(seq 100); do
    socket=$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name 'wayland-*' ! -name '*.lock' -print -quit)
    [[ -n $socket ]] && break
    sleep 0.1
done
[[ -n ${socket:-} ]] || { cat "$root/sway.log" >&2; echo "headless sway did not start" >&2; exit 1; }
export WAYLAND_DISPLAY=${socket##*/}

state="$root/state/stillsuit/clipboard"
events="$root/events"
watch_err="$root/watch.err"
: >"$events"
"$collector" watch --state-dir "$state" --collector "$collector" --wl-paste "$(command -v wl-paste)" --owner-pid $$ \
    --secret-source-prefix=chrome-extension://nngceckbapebfimnlniiiahkandclblb/ \
    >"$events" 2>"$watch_err" &
watch_pid=$!

expect_event() {
    local count=$1 filter=$2 label=$3
    for _ in $(seq 100); do
        if (($(wc -l <"$events") >= count)) && sed -n "${count}p" "$events" | jq -e "$filter" >/dev/null; then
            printf 'ok: %s\n' "$label"
            return 0
        fi
        sleep 0.1
    done
    printf 'FAIL: %s\n--- events\n' "$label" >&2
    cat "$events" >&2
    cat "$watch_err" >&2
    exit 1
}

# The first event reports the empty selection at startup.
expect_event 1 '.kind == "skipped" and .reason == "empty"' "startup with nothing copied"

printf 'hello from e2e\n' | wl-copy
expect_event 2 '.kind == "text" and .preview == "hello from e2e\n" and .mime == "text/plain;charset=utf-8"
    and (.shape | test("^[0-9a-f]{16}$"))' "text copy"
text_sha=$(sed -n 2p "$events" | jq -r .sha)

printf '\x89PNG\r\n\x1a\ne2e' | wl-copy --type image/png
expect_event 3 '.kind == "image" and .mime == "image/png"' "image copy"

printf 'hunter2' | wl-copy --type x-kde-passwordManagerHint
expect_event 4 '.kind == "skipped" and .reason == "hint"' "password manager hint"

# Without --type, wl-copy would infer a binary type for a lone NUL. Only a
# Gecko-shaped offer can be a clear; wl-copy's NUL is just empty.
printf '\0' | wl-copy --type 'text/plain;charset=utf-8'
expect_event 5 '.kind == "skipped" and .reason == "empty"' "non-Gecko NUL is not a clear"

"$collector" copy --state-dir "$state" --sha "$text_sha" --mime 'text/plain;charset=utf-8' \
    --wl-copy "$(command -v wl-copy)"
expect_event 6 ".kind == \"text\" and .sha == \"$text_sha\"" "re-copy is observed as a repeat"
if [[ $(wl-paste --no-newline --type 'text/plain;charset=utf-8' | sha256sum | cut -d' ' -f1) != "$text_sha" ]]; then
    echo "FAIL: re-copied bytes differ" >&2
    exit 1
fi
echo "ok: re-copy is byte-exact"

image_sha=$(sed -n 3p "$events" | jq -r .sha)
"$collector" rm --state-dir "$state" --sha "$image_sha" | jq -e '.ok and .removed == 1' >/dev/null \
    || { echo "FAIL: rm did not delete the image blob" >&2; exit 1; }
[[ ! -e $state/blobs/$image_sha ]] || { echo "FAIL: image blob survived rm" >&2; exit 1; }
echo "ok: rm deletes a captured blob"

kill "$watch_pid"
wait "$watch_pid" 2>/dev/null || true
watch_pid=""
for _ in $(seq 50); do
    pgrep -f -- "--state-dir $state" >/dev/null || break
    sleep 0.1
done
if pgrep -af -- "--state-dir $state" >&2; then
    echo "FAIL: stopping the watcher left wl-paste or emit running" >&2
    exit 1
fi
echo "ok: stopping the watcher stops its process group"

# wl-paste and wl-copy exec `cat`, so a wrapper missing coreutils loses every
# capture and re-copy under the service's exact PATH while a full PATH hides it.
if [[ -n ${STILLSUIT_CLIPBOARD_COLLECTOR:-} ]]; then
    wl_bin=$(dirname -- "$(readlink -f -- "$(command -v wl-paste)")")
    [[ ! -e $wl_bin/cat ]] || { echo "FAIL: $wl_bin holds cat; the minimal PATH proves nothing" >&2; exit 1; }
    minimal=(env -i "PATH=$wl_bin" "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR" "WAYLAND_DISPLAY=$WAYLAND_DISPLAY")
    mkdir "$root/minimal"
    state="$root/minimal/state"
    events="$root/minimal/events"
    watch_err="$root/minimal/watch.err"
    : >"$events"
    "${minimal[@]}" "$collector" watch --state-dir "$state" --collector "$collector" --wl-paste "$wl_bin/wl-paste" \
        --owner-pid $$ >"$events" 2>"$watch_err" &
    watch_pid=$!
    expect_event 1 '.kind == "text"' "minimal PATH: startup capture of the current selection"
    printf 'minimal path\n' | wl-copy
    expect_event 2 '.kind == "text" and .preview == "minimal path\n"' "minimal PATH: text copy"
    minimal_sha=$(sed -n 2p "$events" | jq -r .sha)
    printf 'other\n' | wl-copy
    expect_event 3 '.kind == "text" and .preview == "other\n"' "minimal PATH: second copy"
    "${minimal[@]}" "$collector" copy --state-dir "$state" --sha "$minimal_sha" --mime 'text/plain;charset=utf-8' \
        --wl-copy "$wl_bin/wl-copy" \
        || { echo "FAIL: minimal PATH: copy exited $?" >&2; exit 1; }
    expect_event 4 ".kind == \"text\" and .sha == \"$minimal_sha\"" "minimal PATH: re-copy is observed"
    if [[ $(wl-paste --no-newline --type 'text/plain;charset=utf-8') != "minimal path" ]]; then
        echo "FAIL: minimal PATH: re-copied text differs" >&2
        exit 1
    fi
    echo "ok: minimal PATH: re-copy is byte-exact"
    kill "$watch_pid"
    wait "$watch_pid" 2>/dev/null || true
    watch_pid=""
    [[ ! -s $watch_err ]] || { echo "FAIL: minimal PATH watcher wrote to stderr" >&2; cat "$watch_err" >&2; exit 1; }
else
    echo "skip: minimal PATH run needs STILLSUIT_CLIPBOARD_COLLECTOR set to a built wrapper"
fi

if rg -a -l hunter2 "$root/state" "$root/events" "$root/watch.err"; then
    echo "FAIL: hinted secret reached disk or output" >&2
    exit 1
fi
[[ ! -s $root/watch.err ]] || { echo "FAIL: watcher wrote to stderr" >&2; cat "$root/watch.err" >&2; exit 1; }
echo "clipboard headless e2e ok"
