---
name: jellyfin-remote-api
description: Use when Codex needs to control or inspect a Jellyfin client through Jellyfin's HTTP API, especially the Raspberry Pi Jellyfin Desktop client on tleilax. Covers finding an access token, locating the active remote-control session, sending playback/navigation/message commands, querying media libraries, and fetching the Jellyfin OpenAPI schema.
---

# Jellyfin Remote API

Use Jellyfin's server API for client control after a Jellyfin client is logged in. For the current setup, Jellyfin runs at `http://sietch:8096` and the HDMI client is Jellyfin Desktop on `tleilax`.

## Quick Start

Use the bundled scripts first:

```bash
skill=/home/kabilan/dotfiles/agents/skills/jellyfin-remote-api

# Print token/user/server/client context as JSON.
"$skill/scripts/jellyfin-token.sh"

# Print the active remote-control session id.
"$skill/scripts/jellyfin-session.sh" --id

# Send a message to the TV.
"$skill/scripts/jellyfin-control.sh" message "Codex" "Remote API works"

# Pause, unpause, stop, home, search, or play an item.
"$skill/scripts/jellyfin-control.sh" pause
"$skill/scripts/jellyfin-control.sh" play-item ITEM_ID
"$skill/scripts/jellyfin-control.sh" seek-percent 50
```

The scripts accept these environment overrides:

- `JELLYFIN_URL` default `http://sietch:8096`
- `JELLYFIN_CLIENT_HOST` default `tleilax`
- `JELLYFIN_SESSION_ID` to target a known session directly
- `JELLYFIN_TOKEN` and `JELLYFIN_USER_ID` to bypass token extraction

## Workflow

1. Check sessions with `scripts/jellyfin-session.sh`.
2. Prefer harmless tests first: `message`, `home`, `search`.
3. Use `play-item ITEM_ID` only after selecting a specific media item from an API query.
4. Use `pause` or `stop` after playback tests so the TV is not left playing unexpectedly.

## Important API Shapes

Use `X-Emby-Token: TOKEN` for authenticated calls.

```bash
GET  /Sessions
POST /Sessions/{sessionId}/Message
POST /Sessions/{sessionId}/Command
POST /Sessions/{sessionId}/Playing?playCommand=PlayNow&itemIds=ITEM_ID&startPositionTicks=0
POST /Sessions/{sessionId}/Playing/Pause
POST /Sessions/{sessionId}/Playing/Unpause
POST /Sessions/{sessionId}/Playing/Stop
POST /Sessions/{sessionId}/Playing/Seek?seekPositionTicks=TICKS
GET  /Users/{userId}/Views
GET  /Users/{userId}/Items
```

For Jellyfin 10.11, `playCommand` and `itemIds` must be query parameters for `/Sessions/{sessionId}/Playing`; putting them only in the JSON body can fail or behave incorrectly.
For seek, use lowercase `seekPositionTicks`.

## References

- Read `references/actions.md` for command examples and media-query patterns.
- Run `scripts/jellyfin-schema.sh` to fetch the live OpenAPI schema from `JELLYFIN_URL` when endpoint details are needed.
