# Notification toast notes

- Treat the motion constants in `Motion.js` as borrowed, not tuned here. The spring math and tokens follow Rune's rune-motion (crates/rune-motion/src, spring, layer and tokens, at e5a6431), the motion system Hokum's cards are drawn with: LAYOUT is Hokum's card restack spring, ENTER and EXIT are Rune's SETTLE pair, and the 48 pt, 0.97 scale entrance is Hokum's slide. Changing them diverges from that design reference.
- Route every animated value through `SpringValue.qml`. It samples the spring in closed form, so a retarget starts from the exact current position and velocity; a keyframe animation retargeted mid-flight jumps or loses velocity.
- Keep position, scale and opacity changes in the deck's slot (`NotificationDeck.qml`); `NotificationCard.qml` only draws and reports gestures. A leaving card has to finish its exit in its old place while its neighbours reflow, which only works when the slot owns the motion.
- Keep springs held until `surfaceReady` is true in `NotificationToasts.qml`. It stays false from the moment the overlay maps until it presents a frame; without the hold an entrance plays during the map and is never seen.
