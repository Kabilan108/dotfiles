#!/usr/bin/env bash
# Boots the plugin workbench headless, then asserts the acceptance target:
# a plugin can be created, edited, broken, and restored without a restart, and
# every fixture switches with the real core reporting no errors.
set -euo pipefail
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_dir=$(cd -- "$test_dir/../.." && pwd)
package_dir=$(cd -- "$source_dir/.." && pwd)
sandbox=$(mktemp -d /tmp/stillsuit-workbench-test.XXXXXXXX)
launcher_pid=""
cleanup() {
    local status=$?
    if [[ $status -ne 0 && -f $sandbox/shell.log ]]; then grep -v "WARN scene" "$sandbox/shell.log" | tail -40; fi
    if [[ -n $launcher_pid ]]; then kill -TERM "$launcher_pid" 2>/dev/null || true; wait "$launcher_pid" 2>/dev/null || true; fi
    pkill -f "sway -c $sandbox/sway.conf" 2>/dev/null || true
    rm -rf -- "$sandbox"
    exit "$status"
}
trap cleanup EXIT

export STILLSUIT_WORKBENCH_PACKAGED_SOURCE="$source_dir"
workbench=("$package_dir/bin/stillsuit-workbench" --source "$source_dir" --sandbox "$sandbox" --plugins "$sandbox/plugins" --theme "$package_dir/design-lab/themes/catppuccin-mocha.json")
"${workbench[@]}" --headless run > "$sandbox/launcher.log" 2>&1 &
launcher_pid=$!

status() { "${workbench[@]}" status 2>/dev/null; }
call() { "${workbench[@]}" call "$@" 2>/dev/null; }
wait_for() {
    local description=$1 expression=$2 attempt
    for attempt in $(seq 1 200); do
        if status | jq -e "$expression" > /dev/null 2>&1; then return 0; fi
        if ! kill -0 "$launcher_pid" 2>/dev/null; then cat "$sandbox/launcher.log"; echo "launcher exited while waiting for $description"; exit 1; fi
        sleep 0.1
    done
    echo "timed out waiting for $description"; status | jq . ; exit 1
}

wait_for "workbench readiness" '.ready == true and .fixture == "default"'
status | jq -e '(.plugins | to_entries | map(select(.value.state == "error")) | length) == 0' > /dev/null
status | jq -e '.modelsApplied | index("stillsuit.battery") != null and index("stillsuit.audio") != null' > /dev/null

for fixture in $(call stillsuit-workbench fixtures | jq -r '.[]'); do
    [[ $(call stillsuit-workbench select "$fixture") == ok ]]
    wait_for "fixture $fixture" ".fixture == \"$fixture\" and .ready == true"
    status | jq -e '(.services | to_entries | map(select(.value.state != "loaded")) | length) == 0' > /dev/null
done
[[ $(call stillsuit-workbench select battery-low) == ok ]]
[[ $(call stillsuit-surface open stillsuit.battery '{}') == ok ]]
wait_for "battery panel" '.selectedPanel == "stillsuit.battery"'
[[ $(call stillsuit-surface close stillsuit.battery) == ok ]]

plugin="$sandbox/plugins/probe"
mkdir -p "$plugin"
manifest='{"schemaVersion":1,"id":"stillsuit.probe","name":"Probe","version":"0.1.0","apiVersion":"1","kinds":["bar-widget"],"entryPoints":{"barWidget":"Widget.qml"},"scope":{"barWidget":"per-output"},"barWidget":{"defaultSection":"right","allowMultiple":false,"order":1}}'
write_widget() {
    printf 'import QtQuick\nimport Stillsuit.Ui\nShellBarCluster {\n    required property var context\n    required property string outputId\n    theme: context.theme\n    iconName: "agent"\n    label: "%s"\n}\n' "$1" > "$plugin/Widget.qml"
}
write_widget first
printf '%s\n' "$manifest" > "$plugin/manifest.json"
wait_for "probe discovery" '.plugins["stillsuit.probe"].visual["bar-widget"] == "loaded"'
first_revision=$(status | jq '.catalogRevision')
write_widget second
wait_for "probe edit" ".catalogRevision > $first_revision and .plugins[\"stillsuit.probe\"].visual[\"bar-widget\"] == \"loaded\""
printf '{ broken' > "$plugin/manifest.json"
wait_for "probe containment" '.plugins["stillsuit.probe"] == null and .ready == true and .plugins["stillsuit.bar"].visual.bar == "loaded"'
printf '%s\n' "$manifest" > "$plugin/manifest.json"
wait_for "probe recovery" '.plugins["stillsuit.probe"].visual["bar-widget"] == "loaded"'

[[ $(call stillsuit-workbench notify "Workbench" "toast") == ok ]]
[[ $(call stillsuit-workbench select default) == ok ]]
wait_for "final state" '.ready == true and .fixture == "default"'
if grep -q "ERROR qml\| ERROR:" "$sandbox/shell.log"; then grep "ERROR" "$sandbox/shell.log"; exit 1; fi
echo "workbench: fixtures, real core, plugin create/edit/break/restore without restart: ok"
