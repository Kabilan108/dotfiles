#!/usr/bin/env bash
set -euo pipefail

jellyfin_url=${JELLYFIN_URL:-http://sietch:8096}
client_host=${JELLYFIN_CLIENT_HOST:-tleilax}

if [[ -n "${JELLYFIN_TOKEN:-}" ]]; then
  jq -n \
    --arg server_url "$jellyfin_url" \
    --arg client_host "$client_host" \
    --arg token "$JELLYFIN_TOKEN" \
    --arg user_id "${JELLYFIN_USER_ID:-}" \
    '{server_url:$server_url, client_host:$client_host, token:$token, user_id:$user_id}'
  exit 0
fi

remote_script='
set -euo pipefail
log=$(find ~/.local/share/jellyfin-desktop/profiles -path "*/QtWebEngine/Local Storage/leveldb/*.log" -type f -printf "%T@ %p\n" | sort -nr | awk "NR==1 {print substr(\$0, index(\$0,\$2))}")
if [ -z "$log" ]; then
  exit 2
fi
token=$(grep -a -o -E '\''AccessToken":"[0-9a-f]+'\'' "$log" | tail -n1 | cut -d "\"" -f 3)
user_id=$(grep -a -o -E '\''UserId":"[0-9a-f]+'\'' "$log" | tail -n1 | cut -d "\"" -f 3)
device_id=$(grep -a -o -E '\''_deviceId[^[:alnum:]]+[A-Za-z0-9_=+-]+'\'' "$log" | tail -n1 | sed -E "s/.*[^A-Za-z0-9_=+-]([A-Za-z0-9_=+-]+)$/\1/" || true)
printf "%s\n%s\n%s\n" "$token" "$user_id" "$device_id"
'

mapfile -t values < <(ssh -o BatchMode=yes "$client_host" "$remote_script")
token=${values[0]:-}
user_id=${values[1]:-}
device_id=${values[2]:-}

if [[ -z "$token" || -z "$user_id" ]]; then
  echo "failed to extract Jellyfin token/user id from $client_host" >&2
  exit 1
fi

jq -n \
  --arg server_url "$jellyfin_url" \
  --arg client_host "$client_host" \
  --arg token "$token" \
  --arg user_id "$user_id" \
  --arg device_id "$device_id" \
  '{server_url:$server_url, client_host:$client_host, token:$token, user_id:$user_id, device_id:$device_id}'
