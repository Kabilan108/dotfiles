#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
jellyfin_url=${JELLYFIN_URL:-http://sietch:8096}

usage() {
  cat >&2 <<'USAGE'
usage:
  jellyfin-control.sh message HEADER TEXT [TIMEOUT_MS]
  jellyfin-control.sh command NAME [JSON_ARGUMENTS]
  jellyfin-control.sh home
  jellyfin-control.sh search QUERY
  jellyfin-control.sh play-item ITEM_ID
  jellyfin-control.sh seek-ticks TICKS
  jellyfin-control.sh seek-percent PERCENT
  jellyfin-control.sh pause|unpause|stop
  jellyfin-control.sh sessions
USAGE
}

ctx=$("$script_dir/jellyfin-token.sh")
token=$(jq -r .token <<<"$ctx")
session_id=${JELLYFIN_SESSION_ID:-$("$script_dir/jellyfin-session.sh" --id)}

post_json() {
  local path=$1
  local body=$2
  curl -fsS -X POST -H "X-Emby-Token: $token" -H 'Content-Type: application/json' -d "$body" "$jellyfin_url$path"
}

case "${1:-}" in
  sessions)
    curl -fsS -H "X-Emby-Token: $token" "$jellyfin_url/Sessions" \
      | jq '[.[] | {Id, UserName, Client, DeviceName, IsActive, SupportsRemoteControl, NowPlayingItem, PlayState}]'
    ;;
  message)
    [[ $# -ge 3 ]] || { usage; exit 2; }
    timeout=${4:-5000}
    body=$(jq -n --arg header "$2" --arg text "$3" --argjson timeout "$timeout" \
      '{Header:$header, Text:$text, TimeoutMs:$timeout}')
    post_json "/Sessions/$session_id/Message" "$body"
    ;;
  command)
    [[ $# -ge 2 ]] || { usage; exit 2; }
    args=${3:-{}}
    body=$(jq -n --arg name "$2" --argjson args "$args" \
      'if ($args == {}) then {Name:$name} else {Name:$name, Arguments:$args} end')
    post_json "/Sessions/$session_id/Command" "$body"
    ;;
  home)
    post_json "/Sessions/$session_id/Command" '{"Name":"GoHome"}'
    ;;
  search)
    [[ $# -eq 2 ]] || { usage; exit 2; }
    body=$(jq -n --arg query "$2" '{Name:"GoToSearch"}')
    post_json "/Sessions/$session_id/Command" "$body"
    sleep 1
    body=$(jq -n --arg query "$2" '{Name:"SendString", Arguments:{String:$query}}')
    post_json "/Sessions/$session_id/Command" "$body"
    ;;
  play-item)
    [[ $# -eq 2 ]] || { usage; exit 2; }
    curl -fsS -X POST -H "X-Emby-Token: $token" \
      "$jellyfin_url/Sessions/$session_id/Playing?playCommand=PlayNow&itemIds=$2&startPositionTicks=0"
    ;;
  seek-ticks)
    [[ $# -eq 2 ]] || { usage; exit 2; }
    curl -fsS -X POST -H "X-Emby-Token: $token" \
      "$jellyfin_url/Sessions/$session_id/Playing/Seek?seekPositionTicks=$2"
    ;;
  seek-percent)
    [[ $# -eq 2 ]] || { usage; exit 2; }
    session=$(curl -fsS -H "X-Emby-Token: $token" "$jellyfin_url/Sessions" \
      | jq '.[] | select(.Id == "'"$session_id"'")')
    item_id=$(jq -r '.NowPlayingItem.Id // empty' <<<"$session")
    if [[ -z "$item_id" ]]; then
      echo "no active NowPlayingItem for session $session_id" >&2
      exit 1
    fi
    user_id=$(jq -r .user_id <<<"$ctx")
    duration=$(curl -fsS -H "X-Emby-Token: $token" "$jellyfin_url/Users/$user_id/Items/$item_id" \
      | jq -r '.RunTimeTicks // 0')
    seek=$(jq -n --argjson duration "$duration" --argjson percent "$2" \
      '($duration * $percent / 100) | floor')
    curl -fsS -X POST -H "X-Emby-Token: $token" \
      "$jellyfin_url/Sessions/$session_id/Playing/Seek?seekPositionTicks=$seek"
    ;;
  pause|unpause|stop)
    endpoint=$1
    endpoint=${endpoint^}
    curl -fsS -X POST -H "X-Emby-Token: $token" "$jellyfin_url/Sessions/$session_id/Playing/$endpoint"
    ;;
  *)
    usage
    exit 2
    ;;
esac
