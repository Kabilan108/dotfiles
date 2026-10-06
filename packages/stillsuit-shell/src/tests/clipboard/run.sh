#!/usr/bin/env bash
# stillsuit.clipboard tests. From the repository root:
#   nix develop -c bash packages/stillsuit-shell/src/tests/clipboard/run.sh
# CLIPBOARD_E2E=1 adds the headless sway run (needs sway and wl-clipboard):
#   nix shell nixpkgs#sway nixpkgs#wl-clipboard nixpkgs#quickshell nixpkgs#jq \
#     nixpkgs#ripgrep nixpkgs#nodejs -c env CLIPBOARD_E2E=1 bash .../run.sh
# STILLSUIT_CLIPBOARD_COLLECTOR=<path> tests a built collector instead of bin/.

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
