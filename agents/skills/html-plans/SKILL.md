---
name: html-plans
description: Author, publish, verify, and maintain plans, reports, reviews, explainers, and live implementation logs as durable HTML artifacts using pagebin.
---

# HTML plans

Use this skill for a browsable plan, report, review, technical explainer, implementation log, or other HTML artifacts. Artifacts are published and shared via the `pagebin` CLI.

## Guidelines

- Use interactive HTML only when controls, simulation, review state, or export creates a feedback loop. Read `references/interactive-artifacts.md`.
- Use the playground skill for dedicated explorers or deep visual diagrams, then return here to publish.
- Never include credentials, private tokens, cookies, environment dumps, or secrets. `pagebin` links are unlisted capabilities: anyone with the URL can view the artifact.
- Depending on the user's request, there may be a relevant recipe to follow to produce the HTML artifact, such as `references/plan-recipe.md`, `references/review-recipe.md`, `references/explainer-recipe.md`, or `references/report-log-recipe.md`. For custom HTML, also read `references/visual-primitives.md`. Adapt `templates/artifact-shell.html` when useful rather than filling it mechanically.

## Authoring

- Prefer one self-contained file with inline CSS, JavaScript, and SVG. No external requests by default.
- Use semantic headings, real tables, keyboard-focusable controls, interactive visualizations, contrast, responsive layouts, and reduced-motion support.
- Use exact file and line references for code claims. Keep snippets focused.
- Add navigation for four or more substantial sections.
- Stateful interactions require reset and export or copy actions.
- Use `--sandbox standard` for Markdown, Mermaid, or interactive HTML. Use `strict` only for inert HTML.

## Publish once and preserve identity

`pagebin` infers repository, project, host, branch, commit, source path, title, type, and agent. Override incorrect inference.

```sh
pagebin publish /absolute/path/plan.html --type plan --verify --json
```

Artifacts are long-lived by default. Add `--ttl` only when intentionally temporary. Capture the JSON result; `pagebin` also stores a protected local receipt.

```sh
pagebin update /absolute/path/plan.html --json
```

File-only update uses the receipt. An ID or viewer URL also works. Do not republish an existing file unless the user wants a second artifact and `--force-new` is appropriate.
Update the existing artifact after meaningful milestones, decisions, or deviations so it remains an accurate record of the work.

## Live implementation logs

Start from `templates/implementation-log.html` or the report-log recipe. Track current state, completed work, verification, blockers, next action, decisions, and deviations.

```sh
tmux new-session -d -s pagebin-watch "pagebin watch /absolute/path/implementation-log.html --json"
```

Shell background jobs can die after an agent tool call. Verify with `pgrep -af 'pagebin watch'`; checkpoint-style `pagebin update <file>` is usually simpler.

## Verify and deliver

Read `references/verification.md`. At minimum:

```sh
pagebin verify <viewer-url-or-id> /absolute/path/artifact.html --json
```

Inspect custom HTML at desktop and mobile widths. Check console errors, navigation, tables, code wrapping, diagrams, controls, reduced motion, and secrets. Publication success does not prove research completeness.

Return the stable viewer URL prominently. For a long-running job, use notify once at completion or when blocked on required human input.
