---
name: html-communication
description: Create or revise visual artifacts, either exhibits in a T3 thread (diagrams, charts, mockups) or standalone HTML pages on PageBin (plans, reports, reviews, logs). Use when the user asks for HTML, a visual, PageBin or a link to share, or when an exhibit would carry a point better than prose.
---

# HTML communication

Lead with exhibits. An exhibit is the element that carries a point: a diagram, chart, table, mockup, call tree, state machine, schema, code excerpt, screenshot or recording. Each section opens with its exhibit; prose names it and says what to notice. Reach for an exhibit before a paragraph, and write prose where no exhibit can carry the point. The vocabulary is in [exhibits](references/exhibits.md).

## Where it goes

In a T3 thread, the thread is the default. Publish a standalone page to PageBin when:

- the user says pagebin, link, share or "not in the thread";
- someone other than the user will read it;
- the user will review it in writing: decisions to pick, comments to anchor, recordings or other attachments to inspect;
- it is long-lived: a plan or log the user returns to over several days.

Outside T3, publish to PageBin; explicit local-only requests stay local.

Each artifact has one home. A PageBin page stays on PageBin, and the thread gets its viewer URL, plus an exhibit written for the thread when one helps. A delegated task reports its findings to the lead and renders or publishes only when its brief says so.

## In the thread

Pick the exhibit from [exhibits](references/exhibits.md); T3's own tools say how to render it. Two rules they leave out:

- **Questions** for the user go in the reply text as numbered decisions, each with your recommended answer, so the user can answer in chat or by quoting. A form inside a rendered frame cannot save answers.
- **The rendered exhibit is the deliverable.** Point at PageBin links and repo files; a local scratch file is out of reach from the user's phone.

The page shape, scripts and publishing below are for PageBin pages.

## PageBin page

Compose the page for this subject and reader. Then apply the contract for what the artifact does:

- Proposes what gets built (plan, design, RFC): [plans](references/plans.md).
- States findings or measured results (report, audit, benchmark, review): [reports](references/reports.md).
- Tracks work as it happens (live or implementation log): [logs](references/logs.md).
- Asks the user to choose, in any genre: [decisions](references/decisions.md).
- Holds stateful controls or an explorer: [interactive artifacts](references/interactive-artifacts.md), with an optional [playground outline](references/playground.md).
- Carries images, recordings or other files: [asset bundles](references/asset-bundles.md).

### Frame

PageBin shows the page edge to edge over white, and none of a thread's theme variables exist there. Give every page its own frame:

- Pick a palette that suits this page, name its variables yourself, and set the background and text colour on `html` or `body`. A page that follows the reader's light/dark setting defines both palettes.
- Keep text at least 16px from the screen edge on a phone: pad `body`, `main` or the outer wrapper.

### Page shape

- **Skimmable top layer.** What this is, the outcome or main claims, and what you need from the reader. Depth (evidence, method, raw tables, long excerpts) goes in collapsible sections under the point it supports. A dense subject stays as dense as it needs to be, one level down.
- **Reviewable text.** The user reviews through PageBin's review layer, which anchors comments to selectable text in the page and skips text inside SVG, form fields and scripts. Anything the user might comment on, including a diagram's key labels, also appears as plain text, such as in a caption. Read the feedback with `pagebin review`; see [decisions](references/decisions.md).
- **Freshness line.** A visible `data-freshness` element near the title: when it was updated, the commit or data reviewed, and what this version supersedes.
- **Real code, labelled sketches.** Excerpts carry their source and commit; code that does not exist yet is marked as a sketch (see exhibits).
- Keep useful source links, keyboard-operable controls, and external text rendered as text. Exclude credentials and secrets.

### Build and lint

Before each publish, run in order, with `scripts/` in this skill's directory:

1. `node scripts/diagrams.mts page.html` renders `language-mermaid` blocks with Pele and copies the pinned build to `<page dir>/pele/`.
2. `node scripts/highlight.mts page.html --root <repo>` colours code blocks (see [exhibits](references/exhibits.md)).
3. `python3 scripts/lint.py page.html --root <repo>` reports prose walls, a missing frame, CSS variables the page never defines, phone-width problems, unhighlighted code, unrendered diagrams, decisions without a default, charts without a claim, stale code excerpts, broken anchors and secret-like strings.

The lint checks structure, not meaning: a chart can pass and still misstate its data. Warnings are prompts for judgement: fix the ones that hurt the reader, and keep the page as it is where the content justifies it. Name a kept warning in the handoff when it affects whether the reader can trust a claim.

### Publish

Load the version-matched instructions with `pagebin skill` for transport details, and add `--assets <page dir>/pele` when the page has diagrams. Update the existing artifact by its receipt or ID; create a second identity only when wanted. Hand over the viewer URL, which follows updates; a `/raw/…/v/N/` URL is pinned to one version.

Verify the changed behavior proportionally; see [artifact checks](references/verification.md). Return the viewer URL when published, otherwise the local file.
