---
name: html-communication
description: Create or revise HTML artifacts (like plans, reports, reviews, explainers, work logs, interactive mockups, etc) when the user asks for HTML or when a browsable artifact helps the user inspect information or make a decision.
---

# HTML communication

Lead with exhibits. An exhibit is the element that carries a point: a diagram, chart, table, mockup, call tree, state machine, schema, code excerpt, screenshot or recording. Each section opens with its exhibit; prose names it and says what to notice. Reach for an exhibit before a paragraph, and write prose where no exhibit can carry the point. The vocabulary is in [exhibits](references/exhibits.md).

Compose the page for this subject and reader. Then apply the contract for what the artifact does:

- Proposes what gets built (plan, design, RFC): [plans](references/plans.md).
- States findings or measured results (report, audit, benchmark, review): [reports](references/reports.md).
- Tracks work as it happens (live or implementation log): [logs](references/logs.md).
- Asks the user to choose, in any genre: [decisions](references/decisions.md).
- Holds stateful controls or an explorer: [interactive artifacts](references/interactive-artifacts.md), with an optional [playground outline](references/playground.md).
- Carries images, recordings or other files: [asset bundles](references/asset-bundles.md).

## Page shape

- **Skimmable top layer.** What this is, the outcome or main claims, and what you need from the reader. Depth (evidence, method, raw tables, long excerpts) goes in collapsible sections under the point it supports. A dense subject stays as dense as it needs to be, one level down.
- **Reviewable text.** The user reviews through PageBin's review layer, which anchors comments to selectable text in the page and skips text inside SVG, form fields and scripts. Anything the user might comment on, including a diagram's key labels, also appears as plain text, such as in a caption. Read the feedback with `pagebin review`; see [decisions](references/decisions.md).
- **Freshness line.** A visible `data-freshness` element near the title: when it was updated, the commit or data reviewed, and what this version supersedes.
- **Real code, labelled sketches.** Excerpts carry their source and commit; code that does not exist yet is marked as a sketch (see exhibits).
- Keep useful source links, keyboard-operable controls, and external text rendered as text. Exclude credentials and secrets.

## Lint

Run `python3 <this skill's directory>/scripts/lint.py page.html --root <repo>` before each publish. It reports prose walls, phone-width problems, decisions without a default, charts without a claim, stale code excerpts, broken anchors and secret-like strings. It checks structure, not meaning: a chart can pass and still misstate its data. Warnings are prompts for judgement: fix the ones that hurt the reader, and keep the page as it is where the content justifies it. Name a kept warning in the handoff when it affects whether the reader can trust a claim.

## Publish

Upload the artifact to PageBin unless the user specifies otherwise; explicit local-only requests stay local. Load the version-matched instructions with `pagebin skill` for transport details. Update the existing artifact by its receipt or ID; create a second identity only when wanted. Hand over the viewer URL, which follows updates; a `/raw/…/v/N/` URL is pinned to one version.

Verify the changed behavior proportionally; see [artifact checks](references/verification.md). Return the viewer URL when published, otherwise the local file.
