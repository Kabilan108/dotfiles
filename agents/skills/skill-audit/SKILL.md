---
name: skill-audit
description: Run a periodic evidence-based audit of the agent skills using the usage-analysis pipeline — refresh transcript data, segment findings by model and harness, propose skill revisions and cuts. Use when the user asks to audit skills, refresh the skill audit, check which skills are earning their keep, or mine transcripts for skill/workflow improvements.
---

# Skill Audit

Periodic audit of `agents/skills/` against real usage data. The goal is a lean skill set that is revised (or cut) based on evidence, not taste. Rounds 1–2 live in PR #5 and `~/.local/share/skill-audit/`; the ongoing lightweight mechanism is `bin/tracer-digest` (weekly, sietch — see issue #8).

## Ground rules

- **Segment everything by model + harness.** Skill behavior differs materially between gpt-5.x versions and between Opus/Fable. Never generalize a finding across models; a behavior can be a 28% problem on gpt-5.5 and 0% on gpt-5.6. Hooks are claude-harness-only; codex-side fixes go in `agents/codex/AGENTS.md`.
- **User approves cuts.** Build the evidence table, propose keep/cut/merge with rationale, and ask before deleting. Skills younger than ~a month get a pass — no exposure, no verdict.
- **Public repo.** No client or work-project names in commits, PR bodies, or skill text. Full unsanitized reports stay under `~/.local/share/skill-audit/`.
- **Don't commit `usage-analysis/`** — it contains raw session data and is gitignored where it stands.

## Pipeline

All scripts live in `usage-analysis/scripts/` (see its README for constraints):

1. **Refresh sources** — additive rsync of the tracer archive, `~/.codex/sessions`, `~/.claude/projects`, history, and usage-data from local and sietch into `usage-analysis/sources/{local,sietch}/`. Never `--delete`: rotated-out upstream history must survive in the snapshot.
2. **Rebuild** — `python usage-analysis/scripts/build_dataset.py`. Deterministic; carries `primary_model` (most frequent non-haiku model per session) through scores, candidate sets, briefs, and LLM packets.
3. **Index invocations** — `python usage-analysis/scripts/skill_invocations.py` → `eda/skill_invocations.csv`. Counts distinct sessions per skill per channel (claude Skill tool / slash markers / codex SKILL.md reads with read-verbs only). Raw marker counts are inflated by context re-echoes — only session counts are meaningful. `skill_dev_session` flags sessions that edited skill files.
4. **LLM review batch** — `python usage-analysis/scripts/run_llm_review_batch.py --limit 48 --parallel 6 --skip-existing --category ...`. Spark only (`gpt-5.3-codex-spark`, read-only sandbox, `--ephemeral`), per the usage-analysis README. Round-robin the failure-mode categories plus `control_sample`.
5. **Synthesize** — aggregate stop-hook and skill recommendations *per (provider, primary_model)*; check deterministic incidence (repeated-command %, missing-verification %) in `eda/candidate_scores.jsonl` for the same segments. A recommendation is actionable only when the LLM theme and the deterministic metric agree within a segment.
6. **Propose** — per-skill evidence table (usage sessions, model split, corrections, pre/post trend vs the last revision date), then keep/cut/revise verdicts. AskUserQuestion for cuts and any hook. Deferred hook evidence goes to a GitHub issue with explicit revisit thresholds (see issue #9 for the shape).
7. **Land** — logical commits on the audit branch; targeted, voice-preserving edits over rewrites. Update `agents/skills/README.md` when the set changes.

## What past rounds learned

- Codex misses skills systematically unless `agents/codex/AGENTS.md` routes to them; claude misses are rarer and usually description/trigger wording.
- Usage counts alone justify cuts (≤3 sessions in 4+ months) but not revisions — revisions need a named failure mode observed in transcripts.
- Post-revision usage trend is the check on the previous round: compare invocation sessions before/after the revision commit date.
