#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_root=$(cd -- "$script_dir/../.." && pwd)
fixture_root=$(mktemp -d)
fixture_pid=""

cleanup() {
    if [[ -n $fixture_pid ]] && kill -0 "$fixture_pid" 2>/dev/null; then
        kill -TERM "$fixture_pid"
        wait "$fixture_pid" || true
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
export QT_QPA_PLATFORM=offscreen
unset DBUS_SESSION_BUS_ADDRESS

mkdir -p "$HOME" "$XDG_CONFIG_HOME/quickshell" "$XDG_DATA_HOME" \
    "$XDG_STATE_HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

if rg -n '#[0-9a-fA-F]{6}|\.palette\.' "$source_root/ui"; then
    printf 'UI source contains a raw palette token or private color\n' >&2
    exit 1
fi

if rg -n 'Behavior on (implicitWidth|implicitHeight|width|height)' "$source_root/ui"; then
    printf 'UI source animates a layout measurement\n' >&2
    exit 1
fi

if rg -n 'root\.checked\s*=' "$source_root/ui/ShellToggle.qml"; then
    printf 'ShellToggle mutates owner-controlled checked state\n' >&2
    exit 1
fi

rg -F 'Keys.onPressed' "$source_root/ui/ShellAction.qml" >/dev/null
rg -F 'Keys.onPressed' "$source_root/ui/ShellSlider.qml" >/dev/null
rg -F 'interactive && enabled && !busy' "$source_root/ui/ShellAction.qml" >/dev/null

config_id=stillsuit-ui-contract-fixture
config_dir="$XDG_CONFIG_HOME/quickshell/$config_id"
mkdir -p "$config_dir"
ln -s "$script_dir/fixture-shell.qml" "$config_dir/shell.qml"
ln -s "$source_root/ui" "$config_dir/ui"

fixture_log="$fixture_root/quickshell.log"
quickshell --no-color -c "$config_id" >"$fixture_log" 2>&1 &
fixture_pid=$!

deadline=$((SECONDS + 20))
result=""
while (( SECONDS < deadline )); do
    if ! kill -0 "$fixture_pid" 2>/dev/null; then
        printf 'UI fixture exited before IPC became available\n' >&2
        sed -n '1,240p' "$fixture_log" >&2
        exit 1
    fi
    if result=$(quickshell ipc --pid "$fixture_pid" call \
            stillsuit-ui-contract run 2>/dev/null); then
        break
    fi
    sleep 0.05
done

if ! jq -e '.ok == true and .checks >= 46' >/dev/null <<<"$result"; then
    printf 'UI contract fixture failed: %s\n' "$result" >&2
    sed -n '1,240p' "$fixture_log" >&2
    exit 1
fi

if rg -n 'ERROR qml| ERROR:|Type .* unavailable|is not a type' "$fixture_log"; then
    printf 'UI fixture logged a QML error\n' >&2
    exit 1
fi

printf 'UI contract fixture ok: %s checks\n' "$(jq -r '.checks' <<<"$result")"

kill -TERM "$fixture_pid"
fixture_status=0
wait "$fixture_pid" || fixture_status=$?
fixture_pid=""
if [[ $fixture_status -ne 0 && $fixture_status -ne 143 ]]; then
    printf 'UI fixture exited with unexpected status %s\n' "$fixture_status" >&2
    exit 1
fi
