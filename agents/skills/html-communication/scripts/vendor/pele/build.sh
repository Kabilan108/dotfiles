#!/usr/bin/env bash
# Refresh pele.global.js, the browser build that diagrams.mts ships with PageBin pages.
# Bump the version in package.json, run this, then rerun diagrams.mts on a page with every diagram type you use.
set -euo pipefail
cd "$(dirname "$0")"
if [[ -f bun.lock ]]; then bun install --frozen-lockfile; else bun install; fi
cp node_modules/pele/dist/pele.global.js pele.global.js
jq -r '.dependencies.pele' package.json > VERSION
rm -rf node_modules
