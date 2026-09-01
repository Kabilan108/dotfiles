#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_root=$(cd -- "$script_dir/../.." && pwd)
test_root=$(mktemp -d)
fixture_pid=""

cleanup() {
    if [[ -n "$fixture_pid" ]] && kill -0 "$fixture_pid" 2>/dev/null; then
        kill -TERM "$fixture_pid"
        wait "$fixture_pid" || true
    fi
    rm -rf -- "$test_root"
}
trap cleanup EXIT

export HOME="$test_root/home"
export XDG_CONFIG_HOME="$test_root/config"
export XDG_DATA_HOME="$test_root/data"
export XDG_STATE_HOME="$test_root/state"
export XDG_CACHE_HOME="$test_root/cache"
export XDG_RUNTIME_DIR="$test_root/runtime"
export QT_QPA_PLATFORM=offscreen
unset DBUS_SESSION_BUS_ADDRESS

mkdir -p "$HOME" "$XDG_CONFIG_HOME/quickshell" "$XDG_DATA_HOME" \
    "$XDG_STATE_HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

uv run --with jsonschema python "$script_dir/manifest-schema.test.py"

cursor_config_id="stillsuit-schema-theme-cursor"
cursor_config_dir="$XDG_CONFIG_HOME/quickshell/$cursor_config_id"
mkdir -p "$cursor_config_dir"
ln -s "$script_dir/ManifestCursorFixture.qml" "$cursor_config_dir/shell.qml"
ln -s "$source_root/core" "$cursor_config_dir/core"
ln -s "$source_root/ui" "$cursor_config_dir/ui"

cursor_log="$test_root/cursor.log"
quickshell --no-color -c "$cursor_config_id" > "$cursor_log" 2>&1 &
fixture_pid=$!
cursor_pid=$fixture_pid

cursor_deadline=$((SECONDS + 20))
cursor_result=""
while (( SECONDS < cursor_deadline )); do
    if ! kill -0 "$cursor_pid" 2>/dev/null; then
        printf 'cursor fixture exited before IPC became available\n' >&2
        sed -n '1,240p' "$cursor_log" >&2
        exit 1
    fi
    if cursor_result=$(quickshell ipc --pid "$cursor_pid" call \
            stillsuit-schema-theme-contract run 2>/dev/null); then
        break
    fi
    sleep 0.05
done

if ! jq -e '.ok == true and .checks == 15' >/dev/null <<< "$cursor_result"; then
    printf 'manifest/cursor fixture failed: %s\n' "$cursor_result" >&2
    sed -n '1,240p' "$cursor_log" >&2
    exit 1
fi
printf 'manifest/cursor fixture ok: %s checks\n' \
    "$(jq -r '.checks' <<< "$cursor_result")"
kill -TERM "$cursor_pid"
wait "$cursor_pid" || cursor_status=$?
if [[ "${cursor_status:-0}" -ne 0 && "${cursor_status:-0}" -ne 143 ]]; then
    printf 'cursor fixture exited with unexpected status %s\n' "$cursor_status" >&2
    exit 1
fi
fixture_pid=""

host_config_id="stillsuit-schema-theme-host"
ln -s "$source_root" "$XDG_CONFIG_HOME/quickshell/$host_config_id"
catalog_path="$test_root/catalog.json"
jq -n '{ schemaVersion: 1, selectedBar: "", plugins: [] }' > "$catalog_path"

canonical_theme="$source_root/../themes/catppuccin-mocha.nix"
valid_theme="$test_root/theme-v2.json"
valid_extra_theme="$test_root/theme-valid-extra.json"
missing_identity_theme="$test_root/theme-missing-identity.json"
missing_palette_theme="$test_root/theme-missing-palette.json"
array_identity_theme="$test_root/theme-array-identity.json"
string_palette_theme="$test_root/theme-string-palette.json"
nix eval --json --file "$canonical_theme" > "$valid_theme"
jq '.palette.chromatic.compatibilityProbe = "#f5e0dc"' "$valid_theme" > "$valid_extra_theme"
jq 'del(.identity)' "$valid_theme" > "$missing_identity_theme"
jq 'del(.palette)' "$valid_theme" > "$missing_palette_theme"
jq '.identity = []' "$valid_theme" > "$array_identity_theme"
jq '.palette = "not-a-record"' "$valid_theme" > "$string_palette_theme"

run_theme_case() {
    local theme_path=$1
    local expected=$2
    local case_name=$3
    local host_log="$test_root/theme-$case_name.log"
    local host_status=""
    local theme_result=""
    local deadline=$((SECONDS + 20))

    STILLSUIT_CONFIG_ID="$host_config_id" \
        STILLSUIT_CATALOG_PATH="$catalog_path" \
        STILLSUIT_THEME_PATH="$theme_path" \
        STILLSUIT_SHADOW_MODE=1 \
        quickshell --no-color -c "$host_config_id" > "$host_log" 2>&1 &
    fixture_pid=$!
    local host_pid=$fixture_pid

    while (( SECONDS < deadline )); do
        if ! kill -0 "$host_pid" 2>/dev/null; then
            printf 'theme fixture %s exited before readiness\n' "$case_name" >&2
            sed -n '1,240p' "$host_log" >&2
            return 1
        fi
        if host_status=$(quickshell ipc --pid "$host_pid" call \
                stillsuit status 2>/dev/null) \
                && jq -e '.catalogRevision >= 1' >/dev/null <<< "$host_status"; then
            break
        fi
        sleep 0.05
    done
    if [[ -z "$host_status" ]] \
            || ! jq -e '.catalogRevision >= 1' >/dev/null <<< "$host_status"; then
        printf 'theme fixture %s did not finish loading\n' "$case_name" >&2
        sed -n '1,240p' "$host_log" >&2
        return 1
    fi

    theme_result=$(quickshell ipc --pid "$host_pid" call stillsuit theme)
    if [[ "$expected" == "accept" ]]; then
        jq -e --slurpfile expectedTheme "$theme_path" \
            '. == $expectedTheme[0]' >/dev/null <<< "$theme_result"
        jq -e '.ready == true' >/dev/null <<< "$host_status"
    else
        jq -e '. == {}' >/dev/null <<< "$theme_result"
        jq -e '.ready == false' >/dev/null <<< "$host_status"
    fi

    kill -TERM "$host_pid"
    local host_exit=0
    wait "$host_pid" || host_exit=$?
    if [[ "$host_exit" -ne 0 && "$host_exit" -ne 143 ]]; then
        printf 'theme fixture %s exited with unexpected status %s\n' \
            "$case_name" "$host_exit" >&2
        return 1
    fi
    fixture_pid=""
    printf 'theme fixture %s: %s\n' "$case_name" "$expected"
}

run_theme_case "$valid_extra_theme" accept valid-extra-chromatic
run_theme_case "$missing_identity_theme" reject missing-identity
run_theme_case "$missing_palette_theme" reject missing-palette
run_theme_case "$array_identity_theme" reject array-identity
run_theme_case "$string_palette_theme" reject string-palette

printf 'schema/theme contracts ok\n'
