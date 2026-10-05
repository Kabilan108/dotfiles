#!/usr/bin/env bash
# App-launch contract: the helper script against stub systemd tools, then the
# AppLaunch service and its context actions in an offscreen shell, including
# the startup helper check through real processes.
set -euo pipefail
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_dir=$(cd -- "$test_dir/../.." && pwd)

bash "$test_dir/helper_test.sh"

fixture_dir=$(mktemp -d /tmp/stillsuit-app-launch.XXXXXXXX)
shell_pid=""
cleanup() {
    local status=$?
    if [[ -n $shell_pid ]]; then kill -TERM "$shell_pid" 2>/dev/null || true; wait "$shell_pid" || true; fi
    rm -rf -- "$fixture_dir"
    exit "$status"
}
trap cleanup EXIT

mkdir -p "$fixture_dir/runtime" "$fixture_dir/home" "$fixture_dir/config" \
    "$fixture_dir/data/applications" "$fixture_dir/system-data" "$fixture_dir/stubs" \
    "$fixture_dir/helper" "$fixture_dir/late"
chmod 700 "$fixture_dir/runtime"
cp -R "$source_dir" "$fixture_dir/shell"
cp "$test_dir/fixture-shell.qml" "$fixture_dir/shell/shell.qml"

cat >"$fixture_dir/data/applications/fixture-terminal.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Fixture Terminal Tool
Exec=fixture-tool --open %F "quoted arg" %%literal
Path=/tmp
Terminal=true
Actions=new-window;

[Desktop Action new-window]
Name=New Window
Exec=fixture-tool --new-window %u
DESKTOP
cat >"$fixture_dir/data/applications/fixture-hidden.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Hidden Fixture
Exec=hidden-tool
NoDisplay=true
DESKTOP

jq -n '{
    terminal: ["term", "-e"],
    browser: ["/opt/bin/browser-bin", "--new-tab"],
    opener: ["opener"],
    session: { lock: ["/fixture/bin/lock", "--now"], logout: ["/bin/true", ""] }
}' >"$fixture_dir/launch.json"

copy_log="$fixture_dir/copies"
bash_bin=$(command -v bash)
cat_bin=$(command -v cat)
sleep_bin=$(command -v sleep)
cat >"$fixture_dir/stubs/wl-copy" <<STUB
#!$bash_bin
{
    printf 'args=%s\n' "\$*"
    "$cat_bin"
    printf '\n--end--\n'
} >>"$copy_log"
"$sleep_bin" 0.3
STUB
chmod +x "$fixture_dir/stubs/wl-copy"

# A stand-in for the launch helper: --check passes, a launch records its argv
# one argument per line, followed by an end marker.
launch_log="$fixture_dir/launches"
cat >"$fixture_dir/helper/stillsuit-app-launch" <<STUB
#!$bash_bin
[[ \$# -eq 1 && \$1 == --check ]] && exit 0
{ printf '%s\n' "\$@"; printf -- '--end--\n'; } >>"$launch_log"
STUB
chmod +x "$fixture_dir/helper/stillsuit-app-launch"

export HOME="$fixture_dir/home" XDG_RUNTIME_DIR="$fixture_dir/runtime" \
    XDG_CONFIG_HOME="$fixture_dir/config" XDG_DATA_HOME="$fixture_dir/data" \
    XDG_DATA_DIRS="$fixture_dir/system-data" \
    XDG_STATE_HOME="$fixture_dir/state" XDG_CACHE_HOME="$fixture_dir/cache" \
    QT_QPA_PLATFORM=offscreen FIXTURE_LAUNCH_CONFIG="$fixture_dir/launch.json" \
    FIXTURE_HELPER="$fixture_dir/helper/stillsuit-app-launch" \
    FIXTURE_LATE_HELPER="$fixture_dir/late/stillsuit-app-launch" \
    PATH="$fixture_dir/stubs:$PATH"
unset DBUS_SESSION_BUS_ADDRESS DISPLAY WAYLAND_DISPLAY STILLSUIT_APP_LAUNCH_HELPER STILLSUIT_LAUNCH_CONFIG

quickshell --no-color -p "$fixture_dir/shell" >"$fixture_dir/test.log" 2>&1 &
shell_pid=$!
ipc() { quickshell ipc --pid "$shell_pid" call app-launch-test "$@"; }
fail() {
    printf 'app-launch fixture: %s\n' "$1" >&2
    sed -n '1,200p' "$fixture_dir/test.log" >&2
    exit 1
}

for _ in {1..200}; do
    [[ $(ipc phase 2>/dev/null || true) == copying ]] && break
    kill -0 "$shell_pid" 2>/dev/null || fail "shell exited early"
    sleep 0.05
done
[[ $(ipc phase) == copying ]] || fail "fixture never reached the copy phase"
for _ in {1..100}; do
    [[ $(ipc copyState) == '{"running":false,"pending":false}' ]] && break
    sleep 0.05
done
[[ $(ipc copyState) == '{"running":false,"pending":false}' ]] || fail "copies did not drain"

# A helper that did not exist at startup becomes usable after one launch
# finds it unavailable and starts a re-check.
[[ $(ipc helperState late) == '{"state":"unavailable","checks":1}' ]] \
    || fail "late helper before install: $(ipc helperState late)"
cp "$fixture_dir/helper/stillsuit-app-launch" "$fixture_dir/late/stillsuit-app-launch"
[[ $(ipc lateLaunch) == unavailable ]] || fail "late helper launch before its re-check"
for _ in {1..100}; do
    [[ $(ipc helperState late) == '{"state":"ready","checks":2}' ]] && break
    sleep 0.05
done
[[ $(ipc helperState late) == '{"state":"ready","checks":2}' ]] \
    || fail "late helper re-check: $(ipc helperState late)"
[[ $(ipc lateLaunch) == ok ]] || fail "late helper launch after its re-check"
[[ $(ipc helperState missing) == '{"state":"unavailable","checks":2}' ]] \
    || fail "nonexistent helper re-check: $(ipc helperState missing)"

expected_launches=$(printf '%s\n' \
    --name org.example.Editor --cwd /srv/project -- editor --new --end-- \
    --name org.example.Editor --cwd /srv/project -- editor --private --end--)
for _ in {1..100}; do
    [[ -e $launch_log && $(<"$launch_log") == "$expected_launches" ]] && break
    sleep 0.05
done
[[ -e $launch_log && $(<"$launch_log") == "$expected_launches" ]] \
    || fail "unexpected real helper launches: $(cat "$launch_log" 2>/dev/null)"

ipc_surface=$(quickshell ipc --pid "$shell_pid" show)
[[ $ipc_surface == *stillsuit-surface* ]] || fail "IPC listing is missing the host targets"
if rg -q 'appLaunch|openUrl|openPath|copyText|sessionAction' <<<"$ipc_surface"; then
    fail "launch actions are reachable through IPC: $ipc_surface"
fi

result=$(ipc result)
jq -e '.failures | length == 0' >/dev/null <<<"$result" || fail "$(jq -r '.failures[]' <<<"$result")"

expected_copies=$'args=--type text/plain;charset=utf-8\nfirst copy\n--end--\nargs=--type text/plain;charset=utf-8\nthird copy\nwith a line\n--end--'
[[ $(<"$copy_log") == "$expected_copies" ]] || fail "unexpected wl-copy input: $(<"$copy_log")"

if rg -q 'ERROR qml| ERROR:|TypeError|ReferenceError|is not a type' "$fixture_dir/test.log"; then
    fail "QML error logged"
fi
printf 'app-launch fixture ok: %s checks\n' "$(jq -r '.checks' <<<"$result")"
