---
name: executor-access-slack
description: Access the user's Slack through Executor. Use when the user asks to search, read, or summarize their Slack messages, channels, DMs, and threads, or to draft, send, or schedule Slack communication.
---

# Executor Slack Access

Keep Executor as the credential boundary.

## Access

1. Load Executor's `execute` guide through its skills tool before writing Executor code.
2. Inside Executor, resolve the saved `slack_mcp` connection and search that namespace for the needed operation.
3. Select matches by exact tool name, inspect each with `tools.describe.tool`, and call the returned full path. Treat search rank as discovery order only.
4. Handle both branches of the `{ ok, data | error }` result. When execution pauses, resume only if the user's request authorizes the pending Slack read or write.

Access is ready when the live Slack connection, current user identity, and every tool used in the run have been resolved.

## Branches

- For searches, recaps, channel reads, or thread reads, read [references/search-and-recaps.md](references/search-and-recaps.md) before calling Slack tools.
- For drafts, immediate sends, replies, or scheduled messages, read [references/writing.md](references/writing.md) before calling Slack tools.

## Report

Use the authenticated profile's timezone unless the user supplies another. Return permalinks for messages the user may need to open or verify. Keep participant and channel details proportional to the request.

The run is complete when all pages in scope have been processed, terse messages have enough surrounding context to interpret, and the response names any inaccessible conversations or unsupported operations.
