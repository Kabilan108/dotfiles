#!/usr/bin/env bash
# Launcher model suite. The QML load check needs quickshell on PATH (the repo
# dev shell has it); set STILLSUIT_LAUNCHER_REQUIRE_QML=1 to fail instead of
# skipping when it is missing.

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

for test_file in syntax query matcher history providers engine perf; do
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
