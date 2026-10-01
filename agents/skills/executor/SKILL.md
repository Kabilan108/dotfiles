---
name: executor
description: Access Gmail, Google Calendar, Slack, and Raindrop through the user's configured Executor connections. Use for service searches, summaries, requested operations, and bookmark organization.
---

# Executor access

Keep the current Executor interface and credential boundary. Load its own `execute` guide through the server's skills tool before writing code. That guide describes the deployed interface; do not substitute an assumed upstream API.

Resolve the saved connection when identity matters. Search `google`, `slack_mcp`, or `raindrop_io` for the needed operation, describe the exact match, and call its returned full path. Search rank is not identity. Handle success, error, pagination, and paused execution explicitly; resume only within the user's authorization.

Keep service-call loops and filtering inside Executor when they reduce returned data. A harness code tool can invoke Executor without duplicating those loops outside it.

Read only the service reference needed:

- Gmail search/read: [gmail](references/google/gmail.md).
- Google Calendar: [calendar](references/google/calendar.md).
- Raindrop bookmarks, collections, tags, and highlights: [raindrop](references/raindrop.md).
- Slack search/recaps: [search and recaps](references/slack/search-and-recaps.md).
- Slack drafts/sends/replies: [writing](references/slack/writing.md).

For Google time windows use America/New_York unless specified; for Slack use the authenticated profile's timezone. Report exact coverage and incomplete pages. Include message permalinks when useful. Drafting does not authorize sending.
