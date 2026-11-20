# Notifications normalize sender identity before presentation

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Senders encode identity and grouping inconsistently. Chromium prefixes native notification bodies with an origin anchor and adds a per-site "Settings" action. Slack titles every message `[workspace] in #channel` or `[workspace] from Name` and puts `Sender: message` in the body. Volume and brightness tools reuse one card through the `x-dunst-stack-tag` or `x-canonical-private-synchronous` hint, not a `replaces_id` they would have to remember.

## Decision

- `liftBrowserOrigin` lifts only the narrow leading anchor form into the source hostname, since it is sender identity, not content.
- `slackMessage` rearranges a Slack card into the sender, the message, and the channel beside the app name, following Hokum.
- `buttonActions` hides the `default` action (a click on the card) and Chromium's Settings button.
- A stack-tagged arrival takes over the card it continues: same key, same place, fresh lifetime. Its predecessor closes.
- `sourceTint` gives each source a stable colour with Hokum's FNV-1a hash mapped onto an oklch hue (lightness 0.76, chroma 0.11).

## Consequences

Changes in Chromium's or Slack's formats fall back to the raw text rather than failing. Two sources that hash to nearby hues look alike.

## Where

- `packages/stillsuit-shell/src/services/NotificationSource.js` (`liftBrowserOrigin`, `slackMessage`)
- `packages/stillsuit-shell/src/services/NotificationModel.js` (`stackTagOf`, `sameStack`)
- `packages/stillsuit-shell/src/services/NotificationPolicy.js` (`buttonActions`, `sourceTint`)
- `packages/stillsuit-shell/src/services/NotificationService.qml` (`stackPredecessor`)
