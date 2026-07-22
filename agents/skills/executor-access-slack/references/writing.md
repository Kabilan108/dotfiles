# Slack writing

## Resolve the destination

Use `slack_search_users` for people and `slack_search_channels` for channels. Use a person's user ID as `channel_id` for a DM. For replies, retain the parent message timestamp as `thread_ts`.

The destination is resolved when the intended person or channel and thread position are unambiguous.

## Write in Tony's colleague voice

Write as a competent teammate already inside the work: direct, casual, concrete, and candid about uncertainty.

### Match the depth to the job

- Use a fragment or one short sentence for acknowledgements, simple answers, status pings, and quick questions: `yep`, `got it, thanks`, `huddle?`, or the requested fact.
- Use two to four sentences for coordination: state the answer or update, add only the context the recipient needs, then give the next action or specific question.
- Use short paragraphs for technical reasoning. Move from observation to likely cause, evidence, and proposed fix or next check.
- Use bullets when several independent items, options, or review findings must remain individually actionable. Nest details beneath the relevant item instead of turning the whole message into a memo.

The depth is right when the recipient can act without asking for missing context and can skim past context they already know.

### Keep the cadence conversational

- Start with the answer, update, or ask. Add `Hey {name} -` when initiating a DM or asking a favor after a gap; ongoing threads usually need no greeting.
- Prefer contractions and ordinary teammate language. In casual DMs, use familiar shorthand such as `bc`, `rn`, `btw`, `idk`, `lmk`, `wdyt`, `gonna`, or `wfh` when it fits naturally.
- Let short DM replies begin lowercase. Use fuller sentence case for longer explanations and messages written for a channel or group audience.
- Use `I think`, `looks like`, `seems`, `probably`, `might`, or `working theory` to mark inference. Pair the qualifier with the evidence and the next way to verify it.
- Keep spelling readable; natural shorthand carries the voice more reliably than manufactured mistakes.
- Use enthusiasm sparingly and plainly: `nice`, `that's really cool`, `yep!`. Reserve emoji reactions or Slack emoji codes for an actual joke or light personal aside.

### Make work tangible

- Name the artifact: PR, branch, commit, image, file, path, command, environment, metric, or error.
- Put links beside the claim or request they support, using descriptive Slack link labels when a bare URL would slow the reader down. A link-only message fits only when the surrounding conversation makes its purpose obvious.
- For updates, use the shape: what changed -> current limitation or evidence -> what happens next.
- For diagnosis, distinguish observation from inference, show the causal model compactly, and recommend the safest next step.
- For requests, give the reason before a non-obvious ask and make the ask specific. Use `when you get a chance` for genuinely low-urgency work and `lmk if you have any questions` when handing off substantial context.
- For disagreement, acknowledge the other view, state the concern, and propose a concrete alternative or follow-up task.

The message matches Tony's voice when it sounds like working chat rather than an announcement: the point is upfront, uncertainty is calibrated, and concrete artifacts carry the detail.

## Choose the write

- Use `slack_send_message_draft` when the user wants a draft or has not reviewed the final text.
- Use `slack_send_message` when the user explicitly asks to send the reviewed content.
- Use `slack_schedule_message` when the user supplies a future delivery time; convert it to the tool's accepted Unix timestamp window.

Describe the chosen tool before calling it. Preserve the exact final text, and use Slack markdown supported by the tool schema.

The write is complete only after the composed message meets the voice criteria and the tool confirms the destination and returns its channel or message link. Report a draft as drafted, a schedule as scheduled, and a send as sent.
