#!/usr/bin/env bash
# Vendors the Material Symbols Rounded SVGs listed in manifest.tsv.
# Source: https://github.com/google/material-design-icons (Apache-2.0).
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
base="https://raw.githubusercontent.com/google/material-design-icons/master/symbols/web"
while IFS=$'\t' read -r icon symbol; do
    [[ -n $icon ]] || continue
    curl -fsSL -o "$icon.svg" "$base/$symbol/materialsymbolsrounded/${symbol}_24px.svg"
done < manifest.tsv
