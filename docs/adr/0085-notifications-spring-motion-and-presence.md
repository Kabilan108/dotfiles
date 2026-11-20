# Notification toasts move on closed-form springs and keep leaving cards in place

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Toast cards enter, restack, get swiped and leave, often while another motion
is still running. Retargeting a keyframe animation mid-flight jumps or loses
velocity. When a card leaves, its neighbours should reflow at once while the
leaving card finishes its exit where it was.

## Decision

Springs are described by perceptual duration and bounce and sampled in closed
form, so a retarget starts from the exact current position and velocity
(`SpringValue`). The math and tokens follow Rune's rune-motion
(`crates/rune-motion/src/{spring,layer,tokens}.rs` at e5a6431), the motion
system Hokum's cards are drawn with. `LAYOUT` (0.38 s, bounce 0.12) is Hokum's
card restack spring; `ENTER` and `EXIT` are Rune's SETTLE pair. The entrance is
Hokum's slide: 48 pt in from the screen edge, faded, at scale 0.97.

Presence: the rendered list keeps a removed key, flagged as exiting, at its
old place until its exit animation ends. A key that comes back first is live
again in the same delegate. A departed key goes after the nearest earlier
neighbour it had. This applies to cards within a deck and to decks within the
toast column: a leaving deck keeps its place and leaves the flow.

The deck's slot owns every position, scale and opacity change; the card only
draws and reports gestures. Collapsed, the newest card sits in front of up to
two narrower cards; hovered, they spread into a list. Until a new card has
mostly faded in (`appear < 0.3`) it takes its measured height at once instead
of growing into it. The overlay leaves `slack` (64 px) left of the cards for a
leftward swipe and their shadows. `surfaceReady` stays false from the moment
the overlay maps until it presents a frame, and springs `hold` until then, so
an entrance starts on screen instead of during the map.

## Consequences

Motion constants come from Hokum and Rune; changing them diverges from that
design reference. Every animated value should go through `SpringValue` so
retargets stay continuous.

## Where

- `packages/stillsuit-shell/src/plugins/builtin/notifications/Motion.js` (`LAYOUT`, `ENTER`, `EXIT`, `ENTER_OFFSET`, `ENTER_SCALE`, `merge`)
- `packages/stillsuit-shell/src/plugins/builtin/notifications/SpringValue.qml`
- `packages/stillsuit-shell/src/plugins/builtin/notifications/NotificationDeck.qml` (slot `fresh`, `lastPlace`)
- `packages/stillsuit-shell/src/plugins/builtin/notifications/NotificationToasts.qml` (`slack`, `surfaceReady`, `relayout`)
- `packages/stillsuit-shell/src/plugins/builtin/notifications/NotificationCard.qml`
