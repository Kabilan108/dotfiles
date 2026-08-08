# Slack writing

## Resolve the destination

Use `slack_search_users` for people and `slack_search_channels` for channels. Use a person's user ID as `channel_id` for a DM. For replies, retain the parent message timestamp as `thread_ts`.

The destination is resolved when the intended person or channel and thread position are unambiguous.

## Write in Tony's voice

Invoke the `write-like-me` skill and compose against it. It owns the register dial, sentence habits, hedging, and Slack mechanics; none of that is duplicated here.

The draft is ready when it passes that skill's checks.

## Choose the write

- Use `slack_send_message_draft` when the user wants a draft or has not reviewed the final text.
- Use `slack_send_message` when the user explicitly asks to send the reviewed content.
- Use `slack_schedule_message` when the user supplies a future delivery time; convert it to the tool's accepted Unix timestamp window.

Describe the chosen tool before calling it. Preserve the exact final text, and use Slack markdown supported by the tool schema.

The write is complete only after the composed message meets the voice criteria and the tool confirms the destination and returns its channel or message link. Report a draft as drafted, a schedule as scheduled, and a send as sent.
