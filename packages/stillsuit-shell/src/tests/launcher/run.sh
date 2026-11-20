#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

for test_file in syntax query matcher history providers engine remmina perf; do
    node "$script_dir/$test_file.test.js"
done

if command -v quickshell > /dev/null 2>&1; then
    bash "$script_dir/qml-load.sh"
elif [[ ${STILLSUIT_LAUNCHER_REQUIRE_QML:-0} == 1 ]]; then
    echo "launcher QML fixture: quickshell not on PATH" >&2
    exit 1
else
    echo "launcher QML fixture: skipped (quickshell not on PATH; run inside nix develop)"
fi

echo "launcher suite: ok"
