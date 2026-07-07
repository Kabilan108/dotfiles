# slack (app-id: `slack`)

Electron. AT-SPI tree works when launched with `--force-renderer-accessibility`
(baked into the nix wrapper). Tree is large (~500-1300 elements) — always use
`acu ui --find`, never dump the whole tree.

## What works (verified 2026-07-07, codex session 019f3d5e)

- **Open a DM via the tree, no focus needed**: press button "New message" →
  activate the "To:" combo box → select the person's AT-SPI list item →
  verify via the tree (composer label becomes `Message to <name>`, and a
  `Recent history in <name> (direct message...)` element appears).
- **Sidebar carries state semantically**: tree items are labeled
  `<channel> (has unread messages)` / `(has a draft message)` / `(private)` —
  unread triage needs no pixels at all.
- **Semantic scrolling**: the sidebar list container exposes `scrollDown` /
  `scrollUp` as non-default actions — `acu act --action <idx> <container-id>`
  scrolls without the pointer. Check `actions` in `acu ui` output for indices.
- Keyboard path (needs seat focus): `ctrl+k` opens the switcher; type a name,
  Return opens the conversation.

## Quirks

- **`--set-text` is rejected** by the sidebar search field AND the "To:" combo
  box (same as Chromium's omnibox). Hybrid pattern: target/activate the field
  through the tree (`acu act`), then enter literal text with `acu type` —
  which is seat input, so the Slack window must hold seat focus for that step.
- **Element ids churn**: index paths shift when the sidebar scrolls or panels
  open/close (a scroll moved `...0.2.0.0.*` to `...0.2.1.0.*`). Re-run
  `acu ui --find` immediately before every `acu act`; never reuse ids across
  UI changes.
- **Window ids churn on restart**: a Slack relaunch gets a new niri window id.
  Re-resolve with `--app slack` (fails loudly if two Slack windows exist).
