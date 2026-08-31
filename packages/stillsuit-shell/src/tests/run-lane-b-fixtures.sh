#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_root=$(cd -- "$script_dir/.." && pwd)
fixture_root="$script_dir/fixtures/plugins"
fixture_tmp=$(mktemp -d)
fixture_pid=""

cleanup() {
    if [[ -n "$fixture_pid" ]] && kill -0 "$fixture_pid" 2>/dev/null; then
        kill -TERM "$fixture_pid"
        wait "$fixture_pid" || true
    fi
    rm -rf -- "$fixture_tmp"
}
trap cleanup EXIT

export HOME="$fixture_tmp/home"
export XDG_CONFIG_HOME="$fixture_tmp/config"
export XDG_DATA_HOME="$fixture_tmp/data"
export XDG_STATE_HOME="$fixture_tmp/state"
export XDG_CACHE_HOME="$fixture_tmp/cache"
export XDG_RUNTIME_DIR="$fixture_tmp/runtime"
export QT_QPA_PLATFORM=offscreen
unset DBUS_SESSION_BUS_ADDRESS

mkdir -p "$HOME" "$XDG_CONFIG_HOME/quickshell" "$XDG_DATA_HOME" \
    "$XDG_STATE_HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

host_config_id="stillsuit-lane-b-host"
host_config_dir="$XDG_CONFIG_HOME/quickshell/$host_config_id"
ln -s "$source_root" "$host_config_dir"

catalog_path="$fixture_tmp/catalog.json"
theme_path="$script_dir/fixtures/theme.v1.json"

jq -n --arg valid "$fixture_root/valid" \
    --arg multi "$fixture_root/multi" \
    --arg brokenPanel "$fixture_root/broken-panel" \
    --arg brokenBar "$fixture_root/broken-bar" \
    --arg brokenWidget "$fixture_root/broken-widget" \
    '{
        schemaVersion: 1,
        selectedBar: "stillsuit.broken-bar",
        plugins: [
            {
                packageRoot: $valid,
                sourceMode: "local",
                enabled: true,
                settings: { fixture: true },
                manifest: {
                    schemaVersion: 1,
                    id: "stillsuit.valid",
                    name: "Valid fixture",
                    version: "1.0.0",
                    apiVersion: "1",
                    kinds: ["service", "panel"],
                    entryPoints: { service: "Service.qml", panel: "Panel.qml" },
                    scope: { service: "global", panel: "global" },
                    dependencies: []
                }
            },
            {
                packageRoot: $multi,
                sourceMode: "local",
                enabled: true,
                settings: {},
                manifest: {
                    schemaVersion: 1,
                    id: "stillsuit.multi",
                    name: "Multi contribution fixture",
                    version: "1.0.0",
                    apiVersion: "1",
                    kinds: ["service", "panel", "overlay"],
                    entryPoints: {
                        service: "Service.qml",
                        panel: "Panel.qml",
                        overlay: "Overlay.qml"
                    },
                    scope: {
                        service: "global",
                        panel: "per-output",
                        overlay: "per-output"
                    },
                    dependencies: [],
                    keepLoaded: true
                }
            },
            {
                packageRoot: $multi,
                sourceMode: "local",
                enabled: true,
                settings: {},
                manifest: {
                    schemaVersion: 1,
                    id: "stillsuit.multi-dependent",
                    name: "Multi dependent fixture",
                    version: "1.0.0",
                    apiVersion: "1",
                    kinds: ["service"],
                    entryPoints: { service: "DependentService.qml" },
                    scope: { service: "global" },
                    dependencies: ["stillsuit.multi"]
                }
            },
            {
                packageRoot: $valid,
                sourceMode: "local",
                enabled: true,
                settings: {},
                manifest: {
                    schemaVersion: 1,
                    id: "stillsuit.malformed",
                    version: "1.0.0",
                    apiVersion: "1",
                    kinds: ["panel"],
                    entryPoints: { panel: "Panel.qml" },
                    scope: { panel: "global" }
                }
            },
            {
                packageRoot: $valid,
                sourceMode: "local",
                enabled: true,
                settings: {},
                manifest: {
                    schemaVersion: 1,
                    id: "stillsuit.bad-api",
                    name: "Bad API fixture",
                    version: "1.0.0",
                    apiVersion: "2",
                    kinds: ["panel"],
                    entryPoints: { panel: "Panel.qml" },
                    scope: { panel: "global" }
                }
            },
            {
                packageRoot: $valid,
                sourceMode: "local",
                enabled: true,
                settings: {},
                manifest: {
                    schemaVersion: 1,
                    id: "stillsuit.unsafe-path",
                    name: "Unsafe path fixture",
                    version: "1.0.0",
                    apiVersion: "1",
                    kinds: ["panel"],
                    entryPoints: { panel: "../Panel.qml" },
                    scope: { panel: "global" }
                }
            },
            {
                packageRoot: $valid,
                sourceMode: "local",
                enabled: true,
                settings: {},
                manifest: {
                    schemaVersion: 1,
                    id: "stillsuit.missing-file",
                    name: "Missing file fixture",
                    version: "1.0.0",
                    apiVersion: "1",
                    kinds: ["panel"],
                    entryPoints: { panel: "Missing.qml" },
                    scope: { panel: "global" }
                }
            },
            {
                packageRoot: $valid,
                sourceMode: "local",
                enabled: true,
                settings: {},
                manifest: {
                    schemaVersion: 1,
                    id: "stillsuit.missing-dependency",
                    name: "Missing dependency fixture",
                    version: "1.0.0",
                    apiVersion: "1",
                    kinds: ["panel"],
                    entryPoints: { panel: "Panel.qml" },
                    scope: { panel: "global" },
                    dependencies: ["stillsuit.absent"]
                }
            },
            {
                packageRoot: $valid,
                sourceMode: "local",
                enabled: true,
                settings: {},
                manifest: {
                    schemaVersion: 1,
                    id: "stillsuit.cycle-a",
                    name: "Cycle A fixture",
                    version: "1.0.0",
                    apiVersion: "1",
                    kinds: ["panel"],
                    entryPoints: { panel: "Panel.qml" },
                    scope: { panel: "global" },
                    dependencies: ["stillsuit.cycle-b"]
                }
            },
            {
                packageRoot: $valid,
                sourceMode: "local",
                enabled: true,
                settings: {},
                manifest: {
                    schemaVersion: 1,
                    id: "stillsuit.cycle-b",
                    name: "Cycle B fixture",
                    version: "1.0.0",
                    apiVersion: "1",
                    kinds: ["panel"],
                    entryPoints: { panel: "Panel.qml" },
                    scope: { panel: "global" },
                    dependencies: ["stillsuit.cycle-a"]
                }
            },
            {
                packageRoot: $valid,
                sourceMode: "local",
                enabled: true,
                settings: {},
                manifest: {
                    schemaVersion: 1,
                    id: "stillsuit.duplicate",
                    name: "Duplicate fixture one",
                    version: "1.0.0",
                    apiVersion: "1",
                    kinds: ["panel"],
                    entryPoints: { panel: "Panel.qml" },
                    scope: { panel: "global" }
                }
            },
            {
                packageRoot: $valid,
                sourceMode: "local",
                enabled: true,
                settings: {},
                manifest: {
                    schemaVersion: 1,
                    id: "stillsuit.duplicate",
                    name: "Duplicate fixture two",
                    version: "1.0.1",
                    apiVersion: "1",
                    kinds: ["panel"],
                    entryPoints: { panel: "Panel.qml" },
                    scope: { panel: "global" }
                }
            },
            {
                packageRoot: $valid,
                sourceMode: "local",
                enabled: true,
                settings: {},
                manifest: {
                    schemaVersion: 1,
                    id: "stillsuit.unknown-kind",
                    name: "Unknown kind fixture",
                    version: "1.0.0",
                    apiVersion: "1",
                    kinds: ["teleporter"],
                    entryPoints: { panel: "Panel.qml" },
                    scope: { panel: "global" }
                }
            },
            {
                packageRoot: $brokenPanel,
                sourceMode: "local",
                enabled: true,
                settings: {},
                manifest: {
                    schemaVersion: 1,
                    id: "stillsuit.broken-panel",
                    name: "Broken panel fixture",
                    version: "1.0.0",
                    apiVersion: "1",
                    kinds: ["panel"],
                    entryPoints: { panel: "Broken.qml" },
                    scope: { panel: "global" }
                }
            },
            {
                packageRoot: $brokenPanel,
                sourceMode: "local",
                enabled: true,
                settings: {},
                manifest: {
                    schemaVersion: 1,
                    id: "stillsuit.broken-service",
                    name: "Broken service fixture",
                    version: "1.0.0",
                    apiVersion: "1",
                    kinds: ["service"],
                    entryPoints: { service: "Broken.qml" },
                    scope: { service: "global" }
                }
            },
            {
                packageRoot: $valid,
                sourceMode: "local",
                enabled: true,
                settings: {},
                manifest: {
                    schemaVersion: 1,
                    id: "stillsuit.service-dependent",
                    name: "Service dependent fixture",
                    version: "1.0.0",
                    apiVersion: "1",
                    kinds: ["service"],
                    entryPoints: { service: "Service.qml" },
                    scope: { service: "global" },
                    dependencies: ["stillsuit.broken-service"]
                }
            },
            {
                packageRoot: $brokenBar,
                sourceMode: "local",
                enabled: true,
                settings: {},
                manifest: {
                    schemaVersion: 1,
                    id: "stillsuit.broken-bar",
                    name: "Broken bar fixture",
                    version: "1.0.0",
                    apiVersion: "1",
                    kinds: ["bar"],
                    entryPoints: { bar: "Broken.qml" },
                    scope: { bar: "per-output" }
                }
            },
            {
                packageRoot: $brokenWidget,
                sourceMode: "local",
                enabled: true,
                settings: {},
                manifest: {
                    schemaVersion: 1,
                    id: "stillsuit.broken-widget",
                    name: "Broken widget fixture",
                    version: "1.0.0",
                    apiVersion: "1",
                    kinds: ["bar-widget"],
                    entryPoints: { barWidget: "Broken.qml" },
                    scope: { barWidget: "per-output" },
                    barWidget: { defaultSection: "right", allowMultiple: false }
                }
            }
        ]
    }' > "$catalog_path"

export STILLSUIT_CONFIG_ID="$host_config_id"
export STILLSUIT_CATALOG_PATH="$catalog_path"
export STILLSUIT_THEME_PATH="$theme_path"
export STILLSUIT_ALLOW_LOCAL_PLUGINS=1
export STILLSUIT_AGENT_PANEL_HELPER="$script_dir/fixtures/fake-agent-panel-helper"
export STILLSUIT_AGENT_PANEL_FIXTURE_LOG="$fixture_tmp/agent-panel-actions.log"
export STILLSUIT_SHADOW_MODE=1

host_log="$fixture_tmp/host.log"
quickshell --no-color -c "$host_config_id" > "$host_log" 2>&1 &
fixture_pid=$!
host_pid=$fixture_pid

wait_for_ping() {
    local pid=$1
    local deadline=$((SECONDS + 20))
    local output=""
    while (( SECONDS < deadline )); do
        if ! kill -0 "$pid" 2>/dev/null; then
            printf 'fixture process %s exited before readiness\n' "$pid" >&2
            sed -n '1,240p' "$host_log" >&2
            return 1
        fi
        if output=$(quickshell ipc --pid "$pid" call stillsuit ping 2>/dev/null) \
                && [[ "$output" == "ok" ]]; then
            return 0
        fi
    done
    printf 'fixture process %s did not become ready\n' "$pid" >&2
    if output=$(quickshell ipc --pid "$pid" call stillsuit status 2>/dev/null); then
        printf 'last status: %s\n' "$output" >&2
    fi
    sed -n '1,240p' "$host_log" >&2
    return 1
}

wait_for_status() {
    local pid=$1
    local expression=$2
    local deadline=$((SECONDS + 20))
    local status=""
    while (( SECONDS < deadline )); do
        if ! kill -0 "$pid" 2>/dev/null; then
            return 1
        fi
        if status=$(quickshell ipc --pid "$pid" call stillsuit status 2>/dev/null) \
                && jq -e "$expression" >/dev/null <<< "$status"; then
            printf '%s' "$status"
            return 0
        fi
    done
    return 1
}

stop_fixture() {
    local pid=$1
    kill -TERM "$pid"
    local status=0
    wait "$pid" || status=$?
    if [[ "$status" -ne 0 && "$status" -ne 143 ]]; then
        printf 'fixture process %s exited with unexpected status %s\n' "$pid" "$status" >&2
        return 1
    fi
    fixture_pid=""
}

wait_for_ping "$host_pid"
host_status=$(quickshell ipc --pid "$host_pid" call stillsuit status)
jq -e '
    .configId == "stillsuit-lane-b-host"
    and .ready == true
    and .fallbackShadowMode == true
    and .bar.fallback == true
    and .bar.activeId == "stillsuit.builtin-bar"
    and .plugins["stillsuit.valid"].state == "loaded"
    and .plugins["stillsuit.malformed"].state == "error"
    and .plugins["stillsuit.unknown-kind"].state == "error"
    and .plugins["stillsuit.bad-api"].state == "error"
    and .plugins["stillsuit.unsafe-path"].state == "error"
    and .plugins["stillsuit.missing-file"].state == "error"
    and .plugins["stillsuit.missing-dependency"].state == "error"
    and .plugins["stillsuit.cycle-a"].state == "error"
    and .plugins["stillsuit.cycle-b"].state == "error"
    and .plugins["stillsuit.duplicate"].state == "error"
    and .plugins["stillsuit.broken-bar"].state == "error"
    and .plugins["stillsuit.broken-widget"].state == "error"
    and .plugins["stillsuit.broken-service"].state == "error"
    and .plugins["stillsuit.service-dependent"].state == "error"
    and .plugins["stillsuit.broken-widget"].widgetClaimed == false
    and .serviceObjectCount == 3
    and .screenCount >= 1
    and .plugins["stillsuit.multi"].surface.contributions.panel.state == "loaded"
    and .plugins["stillsuit.multi"].surface.contributions.overlay.state == "loaded"
    and .plugins["stillsuit.multi"].surface.contributions.panel.instances == .screenCount
    and .plugins["stillsuit.multi"].surface.contributions.overlay.instances == .screenCount
    and .plugins["stillsuit.multi-dependent"].service.state == "loaded"
' >/dev/null <<< "$host_status"

broken_open=$(quickshell ipc --pid "$host_pid" call stillsuit-surface open \
    stillsuit.broken-panel '{}')
[[ "$broken_open" == "ok" ]]
wait_for_status "$host_pid" \
    '.plugins["stillsuit.broken-panel"].state == "error"
        and .plugins["stillsuit.broken-panel"].surface.queuedPayloads == 0' >/dev/null

valid_open=$(quickshell ipc --pid "$host_pid" call stillsuit-surface open \
    stillsuit.valid '{"fixture":true}')
[[ "$valid_open" == "ok" ]]
wait_for_status "$host_pid" \
    '.plugins["stillsuit.valid"].surface.state == "loaded"
        and .plugins["stillsuit.valid"].surface.open == true' >/dev/null
valid_close=$(quickshell ipc --pid "$host_pid" call stillsuit-surface close stillsuit.valid)
[[ "$valid_close" == "ok" ]]

unknown_open=$(quickshell ipc --pid "$host_pid" call stillsuit-surface open \
    stillsuit.not-installed '{}')
[[ "$unknown_open" == "unknown" ]]

unload_result=$(quickshell ipc --pid "$host_pid" call stillsuit-plugin unload stillsuit.valid)
[[ "$unload_result" == "ok" ]]
unloaded_status=$(quickshell ipc --pid "$host_pid" call stillsuit status)
jq -e '
    .plugins["stillsuit.valid"].state == "unloaded"
    and .serviceObjectCount == 2
' >/dev/null <<< "$unloaded_status"
reload_result=$(quickshell ipc --pid "$host_pid" call stillsuit-plugin reload stillsuit.valid)
[[ "$reload_result" == "ok" ]]
wait_for_ping "$host_pid"

for _reload_index in 1 2 3 4 5; do
    reload_result=$(quickshell ipc --pid "$host_pid" call stillsuit-plugin reload stillsuit.valid)
    [[ "$reload_result" == "ok" ]]
    wait_for_ping "$host_pid"
done

post_reload_status=$(quickshell ipc --pid "$host_pid" call stillsuit status)
jq -e --arg instance "$(jq -r '.instanceId' <<< "$host_status")" '
    .ready == true
    and .instanceId == $instance
    and .serviceObjectCount == 3
    and .plugins["stillsuit.valid"].service.state == "loaded"
' >/dev/null <<< "$post_reload_status"

pre_rescan_revision=$(jq -r '.catalogRevision' <<< "$post_reload_status")
rescan_result=$(quickshell ipc --pid "$host_pid" call stillsuit-plugin rescan)
[[ "$rescan_result" == "ok" ]]
post_rescan_status=$(quickshell ipc --pid "$host_pid" call stillsuit status)
jq -e --argjson revision "$pre_rescan_revision" '
    .catalogRevision == ($revision + 1)
    and .serviceObjectCount == 3
    and .plugins["stillsuit.broken-panel"].state == "error"
    and .plugins["stillsuit.broken-widget"].state == "error"
' >/dev/null <<< "$post_rescan_status"

bar_unload_result=$(quickshell ipc --pid "$host_pid" call stillsuit-plugin unload \
    stillsuit.broken-bar)
[[ "$bar_unload_result" == "ok" ]]
bar_unloaded_status=$(quickshell ipc --pid "$host_pid" call stillsuit status)
jq -e '
    .ready == true
    and .bar.fallback == true
    and .bar.activeId == "stillsuit.builtin-bar"
' >/dev/null <<< "$bar_unloaded_status"
bar_reload_result=$(quickshell ipc --pid "$host_pid" call stillsuit-plugin reload \
    stillsuit.broken-bar)
[[ "$bar_reload_result" == "ok" ]]
wait_for_ping "$host_pid"
bar_reloaded_status=$(quickshell ipc --pid "$host_pid" call stillsuit status)
jq -e '
    .ready == true
    and .bar.fallback == true
    and .plugins["stillsuit.broken-bar"].state == "error"
' >/dev/null <<< "$bar_reloaded_status"

multi_unload=$(quickshell ipc --pid "$host_pid" call stillsuit-plugin unload stillsuit.multi)
[[ "$multi_unload" == "ok" ]]
multi_unloaded_status=$(quickshell ipc --pid "$host_pid" call stillsuit status)
jq -e '
    .serviceObjectCount == 1
    and .plugins["stillsuit.multi"].state == "unloaded"
    and .plugins["stillsuit.multi-dependent"].state == "unloaded"
    and .plugins["stillsuit.multi"].surface.contributions.panel.state == "unloaded"
    and .plugins["stillsuit.multi"].surface.contributions.overlay.state == "unloaded"
' >/dev/null <<< "$multi_unloaded_status"
multi_reload=$(quickshell ipc --pid "$host_pid" call stillsuit-plugin reload stillsuit.multi)
[[ "$multi_reload" == "ok" ]]
wait_for_status "$host_pid" '
    .ready == true
    and .serviceObjectCount == 3
    and .plugins["stillsuit.multi-dependent"].service.state == "loaded"
    and .plugins["stillsuit.multi"].surface.contributions.panel.instances == .screenCount
    and .plugins["stillsuit.multi"].surface.contributions.overlay.instances == .screenCount
' >/dev/null

for action in open hide toggle status terminate; do
    action_result=$(quickshell ipc --pid "$host_pid" call stillsuit-agent-panel "$action")
    jq -e --arg action "$action" '
        .dispatch == "started"
        and .running == true
        and .lastAction == $action
        and has("lastResult")
    ' >/dev/null <<< "$action_result"
    wait_for_status "$host_pid" \
        ".agentPanel.running == false
            and .agentPanel.lastAction == \"$action\"
            and .agentPanel.lastResult.action == \"$action\"
            and .agentPanel.lastResult.fixture == true" >/dev/null
done
mapfile -t agent_panel_actions < "$STILLSUIT_AGENT_PANEL_FIXTURE_LOG"
[[ "${agent_panel_actions[*]}" == "open hide toggle status terminate" ]]

processes_path="$fixture_tmp/processes.json"
quickshell list -j -c "$host_config_id" > "$processes_path"
jq -e --argjson pid "$host_pid" '
    type == "array"
    and ([.[] | select(.pid == $pid)] | length) == 1
' "$processes_path" >/dev/null

ipc_path="$fixture_tmp/ipc.txt"
quickshell ipc --pid "$host_pid" show > "$ipc_path"
for target in stillsuit stillsuit-surface stillsuit-plugin stillsuit-agent-panel; do
    count=$(awk -v expected="target ${target}" \
        '$0 == expected { count++ } END { print count + 0 }' "$ipc_path")
    if [[ "$count" -ne 1 ]]; then
        printf 'expected one IPC owner for %s\n' "$target" >&2
        sed -n '1,240p' "$ipc_path" >&2
        exit 1
    fi
done

printf 'host-fixture ok: malformed manifest, unknown kind, broken QML, fallback bar, widget release, singleton reload\n'
printf 'host pid: %s, instance: %s\n' "$host_pid" "$(jq -r '.instanceId' <<< "$host_status")"
if rg -n 'Binding loop|TypeError|ReferenceError|Cannot assign|Failed to load configuration' \
        "$host_log"; then
    printf 'host fixture logged an unexpected QML failure\n' >&2
    exit 1
fi
stop_fixture "$host_pid"

core_config_id="stillsuit-lane-b-core"
core_config_dir="$XDG_CONFIG_HOME/quickshell/$core_config_id"
mkdir -p "$core_config_dir"
ln -s "$script_dir/CoreContractFixture.qml" "$core_config_dir/shell.qml"
ln -s "$source_root/core" "$core_config_dir/core"
ln -s "$source_root/ui" "$core_config_dir/ui"
ln -s "$script_dir/fixtures" "$core_config_dir/fixtures"

core_log="$fixture_tmp/core.log"
quickshell --no-color -c "$core_config_id" > "$core_log" 2>&1 &
fixture_pid=$!
core_pid=$fixture_pid

core_deadline=$((SECONDS + 20))
core_result=""
while (( SECONDS < core_deadline )); do
    if ! kill -0 "$core_pid" 2>/dev/null; then
        printf 'core fixture exited before IPC became available\n' >&2
        sed -n '1,240p' "$core_log" >&2
        exit 1
    fi
    if core_result=$(quickshell ipc --pid "$core_pid" call \
            stillsuit-lane-b-contract run 2>/dev/null); then
        break
    fi
done

jq -e '.ok == true and .checks >= 56' >/dev/null <<< "$core_result"
printf 'core-contract fixture ok: %s checks\n' "$(jq -r '.checks' <<< "$core_result")"
if rg -n 'Binding loop|TypeError|ReferenceError|Cannot assign|Failed to load configuration' \
        "$core_log"; then
    printf 'core fixture logged an unexpected QML failure\n' >&2
    exit 1
fi
stop_fixture "$core_pid"

repair_config_id="stillsuit-host-core-repair"
repair_config_dir="$XDG_CONFIG_HOME/quickshell/$repair_config_id"
mkdir -p "$repair_config_dir"
ln -s "$script_dir/fixtures/HostCoreRepairFixture.qml" "$repair_config_dir/shell.qml"
ln -s "$source_root/core" "$repair_config_dir/core"
export STILLSUIT_REPAIR_FIXTURE_ROOT="$script_dir/fixtures"

repair_log="$fixture_tmp/host-core-repair.log"
quickshell --no-color -c "$repair_config_id" > "$repair_log" 2>&1 &
fixture_pid=$!
repair_pid=$fixture_pid

repair_deadline=$((SECONDS + 20))
repair_result=""
while (( SECONDS < repair_deadline )); do
    if ! kill -0 "$repair_pid" 2>/dev/null; then
        printf 'host-core repair fixture exited before IPC became available\n' >&2
        sed -n '1,240p' "$repair_log" >&2
        exit 1
    fi
    if repair_result=$(quickshell ipc --pid "$repair_pid" call \
            stillsuit-host-core-repair run 2>/dev/null); then
        break
    fi
done

if ! jq -e '.ok == true and .checks >= 13' >/dev/null <<< "$repair_result"; then
    printf 'host-core repair fixture failed: %s\n' "$repair_result" >&2
    sed -n '1,240p' "$repair_log" >&2
    exit 1
fi
printf 'host-core repair fixture ok: %s checks\n' \
    "$(jq -r '.checks' <<< "$repair_result")"
if rg -n 'Binding loop|TypeError|ReferenceError|Cannot assign|Failed to load configuration' \
        "$repair_log"; then
    printf 'host-core repair fixture logged an unexpected QML failure\n' >&2
    exit 1
fi
stop_fixture "$repair_pid"
