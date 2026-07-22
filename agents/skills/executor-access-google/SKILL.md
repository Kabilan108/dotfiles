---
name: executor-access-google
description: Access the user's Gmail and Google Calendar through Executor. Use when the user asks to search or summarize their inbox or email, inspect Gmail labels or threads, or list and summarize their schedule or calendar.
---

# Executor Google Access

Keep Executor as the credential boundary.

## Access

1. Load Executor's `execute` guide through its skills tool before writing Executor code.
2. Inside Executor, list saved connections when identity matters, then search the `google` namespace for the needed operation.
3. Select the match by exact tool name, inspect it with `tools.describe.tool`, and call the returned full path. Treat search rank as discovery order only.
4. Handle both branches of the `{ ok, data | error }` result and resume a paused execution only when the user's request authorizes the pending operation.

Access is ready when the live Google connection and every tool used in the run have been resolved and described.

## Branches

- For Gmail search, reading, label breakdowns, or summaries, read [references/gmail.md](references/gmail.md) before calling Gmail tools.
- For calendar listings or schedule summaries, read [references/calendar.md](references/calendar.md) before calling Calendar tools.

## Report

Use `America/New_York` unless the user supplies another timezone. State the inclusive start, exclusive end or retrieval time, calendars or mailbox surfaces covered, and any incomplete pages or tool errors. Summarize the minimum personal detail needed for the request.

The run is complete when every result page in scope has been processed, exact time filtering has been applied to individual records, and the response distinguishes verified data from coverage limits.
