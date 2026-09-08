# Slack writing

Always unslop your writing. Be concise and direct.

## Resolve the destination

Use `slack_search_users` for people and `slack_search_channels` for channels. Use a person's user ID as `channel_id` for a DM. For replies, retain the parent message timestamp as `thread_ts`.

The destination is resolved when the intended person or channel and thread position are unambiguous.

## Choose the write

- Use `slack_send_message_draft` when the user wants a draft or has not reviewed the final text.
- Use `slack_send_message` when the user explicitly asks to send the reviewed content.
- Use `slack_schedule_message` when the user supplies a future delivery time; convert it to the tool's accepted Unix timestamp window.

Preserve the exact final text, and use Slack markdown supported by the tool schema.

The write is complete only after the composed message is approved and the tool confirms the destination and returns its channel or message link. Clearly report final message status.
