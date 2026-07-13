---
name: html-plans
description: Author, publish, verify, and maintain plans, reports, reviews, explainers, and live implementation logs as durable PageBin artifacts.
---

# HTML plans

Use this skill for a browsable plan, report, review, technical explainer, implementation log, or PageBin publication. The goal is a trustworthy engineering artifact with a stable URL, not HTML for its own sake.

## Route the artifact

- Use Markdown for prose, headings, code, Mermaid, and ordinary tables.
- Use static HTML when visual hierarchy, diagrams, comparisons, annotated snippets, or dense navigation materially improve comprehension.
- Use interactive HTML only when controls, simulation, review state, or export creates a feedback loop. Read `references/interactive-artifacts.md`.
- Use playground or visual-explainer for a dedicated explorer or deep visual diagram, then return here to publish.

## Artifact contract

State the title, purpose, audience, status, updated time, summary, scope, non-goals, evidence provenance, decisions, risks, open questions, and verification. Mark uncertainty and unverified claims.

Never include credentials, private tokens, cookies, environment dumps, or secrets. PageBin links are unlisted capabilities: anyone with the URL can view the artifact.

Read exactly the relevant recipe: `references/plan-recipe.md`, `references/review-recipe.md`, `references/explainer-recipe.md`, or `references/report-log-recipe.md`. For custom HTML, also read `references/visual-primitives.md`. Adapt `templates/artifact-shell.html` when useful rather than filling it mechanically.

## Authoring

- Prefer one self-contained file with inline CSS, JavaScript, and SVG. No external requests by default.
- Put throwaway work in the scratchpad and durable artifacts under `docs/<ticket-or-topic>/`.
- Use semantic headings, real tables, keyboard-focusable controls, contrast, responsive layouts, and reduced-motion support.
- Use exact file and line references for code claims. Keep snippets focused.
- Add navigation for four or more substantial sections.
- Stateful interactions require reset and export or copy actions.
- Use `--sandbox standard` for Markdown, Mermaid, or interactive HTML. Use `strict` only for inert HTML.

## Publish once and preserve identity

PageBin infers repository, project, host, branch, commit, source path, title, type, and status. Override incorrect inference.

```sh
pagebin publish /absolute/path/plan.html --type plan --status draft --verify --json
```

Artifacts are long-lived by default. Add `--ttl` only when intentionally temporary. Capture the JSON result; PageBin also stores a protected local receipt.

```sh
pagebin update /absolute/path/plan.html --json
```

File-only update uses the receipt. An ID or viewer URL also works. Do not republish an existing file unless the user wants a second artifact and `--force-new` is appropriate.

## Live implementation logs

Start from `templates/implementation-log.html` or the report/log recipe. Track current state, completed work, verification, blockers, next action, decisions, and deviations.

```sh
tmux new-session -d -s pagebin-watch "pagebin watch /absolute/path/implementation-log.html --json"
```

Shell background jobs can die after an agent tool call. Verify with `pgrep -af 'pagebin watch'`; checkpoint-style `pagebin update <file>` is usually simpler.

## Verify and deliver

Read `references/verification.md`. At minimum:

```sh
pagebin verify <viewer-url-or-id> /absolute/path/artifact.html --json
```

Inspect custom HTML at desktop and narrow widths. Check console errors, navigation, tables, code wrapping, diagrams, controls, reduced motion, and secrets. Publication success does not prove research completeness.

Return the stable viewer URL prominently. For a long-running job, use notify once at completion or when blocked on required human input.
