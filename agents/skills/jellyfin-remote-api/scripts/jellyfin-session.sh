#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
jellyfin_url=${JELLYFIN_URL:-http://sietch:8096}
mode=json

if [[ "${1:-}" == "--id" ]]; then
  mode=id
fi

ctx=$("$script_dir/jellyfin-token.sh")
token=$(jq -r .token <<<"$ctx")

sessions=$(curl -fsS -H "X-Emby-Token: $token" "$jellyfin_url/Sessions")

if [[ -n "${JELLYFIN_SESSION_ID:-}" ]]; then
  session=$(jq --arg id "$JELLYFIN_SESSION_ID" '.[] | select(.Id == $id)' <<<"$sessions")
else
  session=$(jq '
    [.[] | select(.SupportsRemoteControl == true)]
    | sort_by((.NowPlayingItem != null), (.IsActive == true))
    | reverse
    | .[0]
  ' <<<"$sessions")
fi

if [[ -z "$session" || "$session" == "null" ]]; then
  echo "no remote-control Jellyfin session found" >&2
  exit 1
fi

if [[ "$mode" == "id" ]]; then
  jq -r .Id <<<"$session"
else
  jq '{Id, UserName, Client, DeviceName, DeviceId, IsActive, SupportsRemoteControl, SupportedCommands, NowPlayingItem, PlayState}' <<<"$session"
fi
