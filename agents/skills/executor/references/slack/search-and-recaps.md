# Slack search and recaps

## Establish scope

1. Resolve and describe `slack_read_user_profile`; omit `user_id` to identify the authenticated user and timezone.
2. Use `slack_search_public` for public-only scope. Use `slack_search_public_and_private` when the user explicitly asks for their Slack, all conversations, DMs, or private-channel coverage. That explicit request supplies consent for the private search; otherwise ask before expanding beyond public channels.
3. Build modifier-based queries. Semantic search may be unavailable. For an authored-message recap, use `from:<@USER_ID>` plus date modifiers. To include Monday, for example, use `after:` with the preceding Sunday date.

Scope is established when the authenticated user, timezone, channel visibility, author filter, and exact time window are known.

## Search exhaustively

1. Set `include_context: true` for conversational summaries and bound `max_context_length` to control payload size.
2. Paginate until the returned pagination information has no cursor or explicitly says no more pages.
3. Parse the MCP envelope before summarizing: Slack results may arrive as JSON serialized inside `data.content[].text`, with the readable results and pagination fields inside that JSON.
4. Count only numbered search results as matches. Context lines and `[See result above]` references explain a hit but are not additional hits.
5. Deduplicate by channel ID and message timestamp.
6. Use `slack_read_thread` for a thread hit and `slack_read_channel` for a terse DM, isolated link, or missing conversational context. A channel read can legitimately show that no additional context exists.

Retrieval is complete when every search page is exhausted and every ambiguous hit has been expanded or marked context-limited.

## Summarize conversations

- Group by person or channel, then by topic; do not narrate message-by-message chronology unless requested.
- Distinguish what the user said from context supplied by other participants.
- Preserve decisions, commitments, blockers, handoffs, and concrete status values.
- State that exact-author search omits huddles, reactions, deleted messages, and conversations where the user did not post.

The recap is complete when every distinct hit belongs to one topic and the coverage note matches the actual search surface.
