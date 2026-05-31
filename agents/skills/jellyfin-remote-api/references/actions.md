# Jellyfin Remote API Actions

## Resolve Context

```bash
skill=/home/kabilan/dotfiles/agents/skills/jellyfin-remote-api
ctx=$("$skill/scripts/jellyfin-token.sh")
token=$(jq -r .token <<<"$ctx")
user_id=$(jq -r .user_id <<<"$ctx")
session_id=$("$skill/scripts/jellyfin-session.sh" --id)
url=${JELLYFIN_URL:-http://sietch:8096}
```

## Inspect Sessions

```bash
curl -fsS -H "X-Emby-Token: $token" "$url/Sessions" \
  | jq '[.[] | {Id, UserName, Client, DeviceName, IsActive, SupportsRemoteControl, SupportedCommands, NowPlayingItem}]'
```

Target the Jellyfin Desktop HDMI client by selecting a session with `SupportsRemoteControl == true`. In this setup it usually appears as `Client: Jellyfin Web`, `DeviceName: Chrome`, and a persistent Jellyfin Desktop device id.

## Commands

Display a transient message:

```bash
curl -fsS -X POST -H "X-Emby-Token: $token" -H 'Content-Type: application/json' \
  -d '{"Header":"Codex","Text":"hello","TimeoutMs":5000}' \
  "$url/Sessions/$session_id/Message"
```

Send a named command:

```bash
curl -fsS -X POST -H "X-Emby-Token: $token" -H 'Content-Type: application/json' \
  -d '{"Name":"GoHome"}' \
  "$url/Sessions/$session_id/Command"
```

Useful names include `GoHome`, `GoToSearch`, `SendString`, `MoveUp`, `MoveDown`, `MoveLeft`, `MoveRight`, `Select`, `Back`, `VolumeUp`, `VolumeDown`, `ToggleMute`, and `DisplayMessage`.

`SendString` requires an argument:

```bash
curl -fsS -X POST -H "X-Emby-Token: $token" -H 'Content-Type: application/json' \
  -d '{"Name":"SendString","Arguments":{"String":"matrix"}}' \
  "$url/Sessions/$session_id/Command"
```

## Playback

Start a specific item:

```bash
curl -fsS -X POST -H "X-Emby-Token: $token" \
  "$url/Sessions/$session_id/Playing?playCommand=PlayNow&itemIds=$item_id&startPositionTicks=0"
```

Pause, unpause, and stop:

```bash
curl -fsS -X POST -H "X-Emby-Token: $token" "$url/Sessions/$session_id/Playing/Pause"
curl -fsS -X POST -H "X-Emby-Token: $token" "$url/Sessions/$session_id/Playing/Unpause"
curl -fsS -X POST -H "X-Emby-Token: $token" "$url/Sessions/$session_id/Playing/Stop"
```

Seek to a position:

```bash
curl -fsS -X POST -H "X-Emby-Token: $token" \
  "$url/Sessions/$session_id/Playing/Seek?seekPositionTicks=$ticks"
```

Use lowercase `seekPositionTicks`; uppercase variants can return `204` without moving playback on Jellyfin 10.11.

## Find Media

List libraries:

```bash
curl -fsS -H "X-Emby-Token: $token" "$url/Users/$user_id/Views" \
  | jq '.Items[] | {Name, CollectionType, Id}'
```

Search items:

```bash
curl -fsS -G -H "X-Emby-Token: $token" \
  --data-urlencode 'SearchTerm=matrix' \
  --data-urlencode 'Recursive=true' \
  --data-urlencode 'IncludeItemTypes=Movie,Episode,Series' \
  --data-urlencode 'Limit=10' \
  "$url/Users/$user_id/Items" \
  | jq '.Items[] | {Name, Type, ProductionYear, Id, SeriesName, IndexNumber, ParentIndexNumber}'
```

Latest movies/episodes:

```bash
curl -fsS -G -H "X-Emby-Token: $token" \
  --data-urlencode 'Recursive=true' \
  --data-urlencode 'IncludeItemTypes=Movie,Episode' \
  --data-urlencode 'SortBy=DateCreated' \
  --data-urlencode 'SortOrder=Descending' \
  --data-urlencode 'Limit=10' \
  "$url/Users/$user_id/Items" \
  | jq '.Items[] | {Name, Type, ProductionYear, Id, SeriesName, IndexNumber, ParentIndexNumber}'
```
