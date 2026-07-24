---
name: coppermind
description: Conventions for working in the coppermind vault - write zones, task format, wiki tiers, redaction policy, and query gotchas. Use whenever reading or writing vault content, managing tasks, filing todos, updating project pages, or writing digest/pipeline output into the vault.
---

# Coppermind Vault Conventions

Only non-discoverable rules live here. Explore the tree yourself for structure; consult `04-projects/manifest.md` for project routing and write zones.

## Write zones (hard rules)

- `04-projects/` = agent zone: write directly. EXCEPTIONS: `*/brief.md` and `moberg/people.md` are curated — propose changes as a small file in `04-projects/_pipeline/proposals/` (name: `YYYY-MM-DD-<target>-<slug>.md`, body: target file + proposed text + one-line rationale).
- `00-bin/`, `01-logs/`, `02-moberg/`, `scratch/` = Tony's zones. Write only when asked in the current session.
- `01-logs/topsecret/` (and anything under a `topsecret/` dir) = sensitive. Never read, list, or reference unless Tony explicitly points you at it.
- Moberg-derived content MUST pass `04-projects/moberg/data-policy.md` (deployment-class redaction) before it lands anywhere in the vault.
- Update the canonical page; never create an adjacent near-duplicate. If a runbook/decision/system page exists for the topic, edit it.

## Tasks

- Format: dataview (`[due:: YYYY-MM-DD]`, `[scheduled:: ...]`, `[completion:: ...]`, `[id:: ]`/`[dependsOn:: ]`). Statuses: ` ` todo, `x` done, `/` in-progress, `-` cancelled.
- NO global filter — every `- [ ]` checkbox is a task (since 2026-07-20). Tags like `#moberg/eboost` are for routing/grouping only.
- Canonical task home: `04-projects/<project>/tasks.md`, sections per workstream. Quick-capture in the weekly log is fine; the daily brief files strays into tasks.md (move the line, keep metadata).
- GOTCHA: the plugin's `globalQuery` hides `01-logs/2024`, `01-logs/2025`, `02-moberg`, and `raindrop` from ALL queries. Don't debug "missing tasks" without checking it (`.obsidian/plugins/obsidian-tasks-plugin/data.json`).
- Weekly log day-sections use pinned-date queries with a rollover clause: overdue/past-scheduled open tasks surface under TODAY's section only.

## Wiki tiers (04-projects/<project>/)

- `tickets/MCP-XXXX.md` — one page per ticket: status, outcome, links (Jira/PRs/repo docs/sessions). Dedup key = ticket id.
- `runbooks/` — gotchas + recipes. `systems/` — how-X-works articles. `decisions/` — append-only, ADR-flavored.
- `briefs/YYYY-MM-DD.md` — daily morning notes (pipeline-written).
- `archives/<slug-YYYY-MM-DD>/` — collections of expensive session artifacts with long-term value (review corpora, generated datasets). Store here instead of regenerating; link from ticket pages.
- Frontmatter contract for agent-managed pages (runbooks/systems/tickets/decisions): `description:` (ONE concise sentence — it's the routing surface, write it like a skill description), `source: auto|curated`, `updated:`, optional `tickets:`, `sessions:`, `last_verified:` (curated only). Keep facts and inference distinguishable in auto pages.
- `sessions:` entries are `<machine>:<session-id>` (e.g. `sietch:019f2411-...`) — the archive is multi-host, so a bare id may not be resolvable with `tracer get` on the machine you're on.

## What belongs in the wiki (the border)

The codebase is ALWAYS the more accurate source for how code works right now. A wiki page that restates code invites the inaccurate-reference failure: a subtly stale page misleads the next agent, which is worse than no page.

- Write down what is **non-obvious and not cheaply recoverable** from the repo in a normal session: why a decision went one way, a debugging root-cause and the hypotheses it killed, an environment gotcha, a constraint that isn't visible in the code that expresses it.
- Do NOT write down what any agent can read directly: API shapes, file inventories, function-by-function walkthroughs.
- Minimize brittle pointers. Name a module or a concept; only cite `file.ts:line` when the exact location IS the non-obvious part (e.g. a comment documenting a unit convention). Assume line numbers rot.
- Separate durable structure from current state. Systems pages describe how a thing works; the live status of in-flight work belongs on the ticket page, and open work belongs in `tasks.md`. When a systems page needs to mention current state, keep it to a short, clearly-labeled note.
- Note branch/version scoping when a page describes something that only exists on one branch.
- Repo paths are written **repo-relative in code spans**, never absolute and never as markdown links: `dev-server/docs/MCP-7162-EDF/`, not `/vault/work/moberg/...` and not `[text](path)`. Obsidian resolves link targets against the vault, so a repo path written as a link becomes a broken vault link.
- Discovery: `rg -m1 '^description:' <dir>/*.md` lists every page's one-liner in one call — do that before reading whole files. (Generated per-dir indexes come with the compile step; descriptions are what they're built from.)

## Meeting notes

- Location: `01-logs/meetings/YYYY-MM-DD-<context>-<slug>.md` (context = moberg/xploit/personal/...). One note per meeting, vault-wide — no per-project meeting dirs.
- Frontmatter contract: `date`, `project` (manifest taxonomy, e.g. `moberg/eboost` — this is how meetings route to projects, NOT tags), `attendees` (plain names; resolve against the project's people.md — no wikilinks needed), `summary` (a tight 2–3 sentence abstract of what happened — problem, key finding/outcome, next step; grep surface for agents, and also opens the body as a `## summary` section above `## notes`), `source: manual|pipeline`, `recording` (artifact path when pipeline-written). Template: `templates/meeting-note.md`.
- Body: `## notes` / `## decisions` / `## follow-ups`. Follow-up checkboxes are query-visible (01-logs is not excluded) — tag them normally; the daily sweep files durable ones into tasks.md.
- Pipeline exception (meeting-minutes agent): it may APPEND one backlink bullet under today's heading in the weekly log — append-only, never edit existing text. This is the only sanctioned automated write to a weekly log.
- Unknown names in pipeline-written `attendees` → propose a people.md addition via `_pipeline/proposals/`, don't add directly.

## Obsidian CLI

Works when Obsidian is running; pipe stderr: `obsidian vault=coppermind eval code="..." 2>/dev/null`. No top-level `await` in eval — use promise chains. Reload plugin config from disk via `disablePlugin`+`enablePlugin`.

## Provenance

Agent-written notes in Tony's zones (when asked) get `source: agent` frontmatter. Weekly-log narrative is never edited by agents, only appended when asked.
