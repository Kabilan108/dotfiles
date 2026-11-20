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

collector_contract() {
    python3 - "$plugin_dir/ClipboardModel.js" "$script_dir/../../../bin/stillsuit-clipboard-collector" <<'PY'
import ast
import json
import subprocess
import sys
from pathlib import Path

constants = {}
for statement in ast.parse(Path(sys.argv[2]).read_text()).body:
    if not isinstance(statement, ast.Assign) or not isinstance(statement.targets[0], ast.Name):
        continue
    name = statement.targets[0].id
    if name in {"MIME_RE", "BLOB_GONE"}:
        value = statement.value.args[0] if name == "MIME_RE" else statement.value
        constants[name] = ast.literal_eval(value)
model = json.loads(subprocess.check_output([
    "node", "-e", """
const context = {};
require('node:vm').runInNewContext(require('node:fs').readFileSync(process.argv[1], 'utf8'), context);
console.log(JSON.stringify({mime: context.MIME_PATTERN.source, gone: context.COPY_BLOB_GONE}));
""", sys.argv[1],
], text=True))
assert model["mime"].replace(r"\/", "/") == constants["MIME_RE"], "model and collector MIME patterns differ"
assert model["gone"] == constants["BLOB_GONE"], "model and collector blob-gone exit codes differ"
PY
}

run "model" node "$script_dir/model.test.js"
run "model and collector constants match" collector_contract
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
