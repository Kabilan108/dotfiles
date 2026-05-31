#!/usr/bin/env bash
set -euo pipefail

jellyfin_url=${JELLYFIN_URL:-http://sietch:8096}
output=${1:-}

if [[ -n "$output" ]]; then
  curl -fsS "$jellyfin_url/api-docs/openapi.json" -o "$output"
  printf '%s\n' "$output"
else
  curl -fsS "$jellyfin_url/api-docs/openapi.json"
fi
