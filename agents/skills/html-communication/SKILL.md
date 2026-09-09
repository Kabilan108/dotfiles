---
name: html-communication
description: Create or revise HTML artifacts (like plans, reports, reviews, explainers, work logs, interactive mockups, etc) when the user asks for HTML or when a browsable artifact helps the user inspect information or make a decision.
---

# HTML communication

Choose the composition, visual style, and sections for this subject and reader. Start with ordinary semantic HTML. Templates are optional starting points, not the house style: use them when their structure helps this artifact. Rich examples remain in `templates/artifact-shell.html` and `templates/implementation-log.html`.

Use self-contained HTML/CSS/SVG for small artifacts. When images, recordings, or other assets make separate files useful, use an explicit PageBin bundle; read [asset bundles](references/asset-bundles.md). Keep useful source links. Keep tables readable, controls keyboard-accessible, and external text safely rendered. Exclude credentials and secrets. Use interactions when they help compare choices or inspect state; read [interactive artifacts](references/interactive-artifacts.md) for stateful controls. An optional [playground outline](references/playground.md) supports focused explorers.

For a requested live log, keep the current state, verification, outstanding dependency, and next action accurate. Checkpoint meaningful changes before long operations; reconstruct from the existing log and actual run state after a restart. A report is not a process completion signal.

Always upload the artifact to PageBin unless the user specifies otherwise. Load its version-matched instructions with `pagebin skill` for transport details. Update the existing artifact using its receipt or ID; create a second identity only when wanted. Explicit local-only requests stay local.

Verify the changed behavior proportionally; see [artifact checks](references/verification.md). Return the stable viewer URL when published, otherwise the local file.
