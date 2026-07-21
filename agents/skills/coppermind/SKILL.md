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
- Pipeline-written pages carry frontmatter: `source: auto|curated`, `updated:`, optional `tickets:`, `sessions:` (tracer ids), `last_verified:` (curated only). Keep facts and inference distinguishable in auto pages.

## Obsidian CLI

Works when Obsidian is running; pipe stderr: `obsidian vault=coppermind eval code="..." 2>/dev/null`. No top-level `await` in eval — use promise chains. Reload plugin config from disk via `disablePlugin`+`enablePlugin`.

## Provenance

Agent-written notes in Tony's zones (when asked) get `source: agent` frontmatter. Weekly-log narrative is never edited by agents, only appended when asked.
