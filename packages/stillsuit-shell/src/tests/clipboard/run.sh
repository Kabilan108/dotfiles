#!/usr/bin/env bash

set -uo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
plugin_dir=$(cd -- "$script_dir/../../plugins/builtin/clipboard" && pwd)
failures=()

run() {
    local name=$1
    shift
    printf '== %s\n' "$name"
    if "$@"; then
        printf '== %s: ok\n' "$name"
    else
        printf '== %s: FAILED (exit %s)\n' "$name" "$?" >&2
        failures+=("$name")
    fi
}

no_modern_syntax() {
    ! rg -n '\?\.|\?\?' "$plugin_dir/ClipboardModel.js" "$plugin_dir/Service.qml"
}

run "model" node "$script_dir/model.test.js"
run "collector" python3 "$script_dir/collector_test.py"
run "no ?. or ?? in plugin sources" no_modern_syntax
if command -v quickshell >/dev/null; then
    run "qml fixture" bash "$script_dir/run-qml-fixture.sh"
else
    printf 'quickshell not on PATH: run through `nix develop -c`\n' >&2
    failures+=("qml fixture (quickshell missing)")
fi
if [[ ${CLIPBOARD_E2E:-0} == 1 ]]; then
    run "headless e2e" bash "$script_dir/e2e-headless.sh"
fi

if ((${#failures[@]} > 0)); then
    printf 'clipboard tests failed: %s\n' "${failures[*]}" >&2
    exit 1
fi
printf 'clipboard tests ok\n'
