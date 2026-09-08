# Concrete change plan

Status: proposed implementation scope, September 6. This plan incorporates the user's completed review. It changes no live configuration. [Review decisions](review-decisions.md) are authoritative over the original audit; [Moberg follow-up](moberg-follow-up.md) is separate work.

## Global instructions

Update `agents/claude/CLAUDE.md` and `agents/codex/AGENTS.md` with short replacement sections:

- Preserve the user's explicit opt-in delegation policy, prior decisions, and task authorization through follow-ups. Ask good questions about consequential uncertainty. Preserve unrelated changes and the approved stopping boundary.
- Replace Claude's numeric model rankings and mandatory paired-review rule with task roles. Fable 5.1 defaults to medium; requested Sol work defaults to medium unless otherwise specified. Preserve the selected coordinator. Keep useful existing language/tool conventions rather than wholesale rewriting unrelated preferences.
- Point to the delegation helper's command help. Remove repeated CLI recipes and the thin Claude-wrapper requirement when a direct helper invocation suffices. Use native workers for authorized same-harness delegation, provider CLI helpers for cross-provider work.
- State one proportional verification principle. Keep exact test commands and local exceptions in repositories. Condense Claude's repetitive LSP tutorial to useful guidance conditional on tool availability.
- Replace browser brand defaults with: use an available integrated browser when it meets the task; use Helium for the configured persistent session, required logins, or when integrated tools are unavailable or unsuitable. Honor an explicit browser choice. Determine availability from tools, not a guessed application identity.
- Keep a short conditional link to the shared empirical-review reference for reviews involving concurrency, authorization, parsers, or other consequential behavioral invariants. It does not authorize more workers.
- Consolidate existing PageBin publication preferences without adding an approval gate or implying that permission for one operation authorizes unrelated publication. Reconcile the wording with actual harness settings during implementation.
- Correct vault discovery and replace obsolete task-file assumptions with the current Coppermind/TaskNotes pointer.

“Authorization” means whether the user requested delegation and what the worker may change. It does not mean managing provider credentials or repeatedly checking login. Helpers use the configured CLI environment and report a concrete authentication error only if encountered. Classifier behavior is not an implementation target.

## Shared skills

All paths below are under `agents/skills/` unless stated otherwise.

| Source | Change | Invocation after change |
|---|---|---|
| `html-plans/` | Rename to `html-communication/`; update callers without alias. Free layout and section choices. Retain useful rich templates as explicitly optional references, with a simple semantic skeleton and optional playground example. Remove inactive skill dependency and routine full viewport QA. Keep stateful controls robust. | Model-selected for requested/suitable HTML communication; explicit requests honored |
| `pagebin/` | Keep transport separate; align authorization and update identity. Link command help instead of duplicating CLI manuals where possible. | PageBin operations |
| `btca-local/` | Rename to `dependency-source/`; retain the central store at `~/.agents/vendored-deps` initially. Remove startup UI and forced answer format. Resolve relevant dependency versions and cite revision-specific evidence. Avoid resetting shared checkouts while another task uses them; use revision-specific worktrees when needed. | Dependency-source investigation, or explicit request |
| `executor-access-google/`, `executor-access-slack/` | Consolidate into `executor/` with shared connection guidance and separate service references. Keep narrow service triggers and operation-specific authorization. | Relevant Google/Slack operations |
| `tmux/` | Short positive trigger: persistent servers, durable shell workers, explicitly targeted pane interaction. Retain safe input, process ownership, completion, and recovery guidance; uncommon commands become references. | These specific process tasks |
| `helium-browser-use/` | Keep on both hosts. Own CDP connection, profile/tab ownership and troubleshooting. Remote mode becomes an optional explicit-use reference, with Fleet aliases corrected; no automatic tunnel setup. | Helium requested or selected because its session/capabilities are needed |
| `agent-browser/` | Narrow description to actual CLI browser automation; remove competing Slack search and unconditional browser-priority routing. Remove ineffective local `hidden` metadata. Preserve upstream technical references. | When agent-browser CLI is the chosen browser mechanism |
| `terminal-control/` | Narrow to actual TUI/PTY control; enforce manual invocation in both harnesses. | Human only |
| `coppermind/` | Verify normalized root; replace checkbox task conventions with current TaskNotes schema/workflow after inspecting current configuration. Preserve actual write-zone policy. | Vault work |
| `unslop/` | Keep close to the current original, including its current invocation policy. No broad rewrite or duplicated global replacement. | Existing always-apply behavior |
| `show-me/` (already added upstream) | Preserve the existing source rather than reinstalling; set human-only invocation metadata. Adapt HumanLayer's compact visual explanation skill. Honor tool availability; route substantial HTML through html-communication without mandatory publishing. Preserve source attribution. | Human only |
| `grilling/` (new adapted trial) | Bounded design questions focused on material decisions; no compulsory exhaustive interview, automatic documents, or subagents. | Human only |
| `diagnosing-bugs/` (new adapted trial) | Hypothesis/evidence loop with targeted reproduction when feasible; permit qualified analysis when access is limited. Avoid restating ordinary debugging basics. | Relevant bug investigation |
| `create-verification-skill/` (new adapted trial) | Derive a project recipe from proven launch/check/drive/evidence/cleanup commands. No automatic proliferation after ordinary sessions. | Human only |

Keep `bro` unchanged. Keep fleet, tracer, handoff, frontend-design, niri-computer-use, writing-for-agents, and notify; touch them only for renamed/deleted references, host selection, or a directly conflicting instruction. Notification sending still follows the user's communication authorization.

## Removals and review adapters

Remove active source directories for `code-walkthrough`, `learn`, `learn-skill`, `review-swarm`, and `review-bot-gate`. Remove all six `agents/wip-skills/` entries. Extract the small optional playground example before removal. Update live callers; historical audit evidence can retain old names.

- Keep `agents/claude-skills/codex-review/`: Claude's explicit entrypoint for a Codex/Sol review or Astra peer consultation for second opinions, code review, and design discussion. Replace launch/wait boilerplate with the helper.
- Keep `agents/codex-skills/claude-review/`: Codex's explicit entrypoint for a Claude/Fable 5.1 second opinion (medium by default). Same helper contract, provider-specific options.
- Both refer to `agents/references/empirical-review.md` for deeper behavioral probing. Add a condition at the reference site: consult it for a material suspected invariant violation. Normal review remains normal review; no mandatory probe for every finding.
- Retire `agents/claude-skills/adversarial-probe-review/` after preserving its useful method in that shared reference. Correct the distinction between reproduced, sufficiently disproved, and unresolved.
- Retire `agents/claude-skills/codex-implementation/` once helper discovery and concise task-packet guidance replace its unique content.
- Retire `agents/claude-skills/codex-computer-use/` after routing authorized cross-provider browser work through the generic provider helper and the selected browser's instructions.
- Retire `agents/claude-skills/milestone-delegation-loop/`; preserve requirements in the separate Moberg follow-up. A completed implementation can rest awaiting human review.
- Remove `agents/claude/agents/browser-monkey.md` and `agents/codex/agents/browser-monkey.toml`, plus any actual registration references. Both were inspected; they duplicate browser mechanics and assume automatic Chrome startup. Codex is pinned to GPT-5.4. No replacement specialist agent is needed.

Reference discovery is explicit: a short conditional pointer in the two global files covers ordinary review prompts; the two review skills point to the same document for cross-provider reviews. Referenced documents do not need a skill name or catalog entry. Use a stable installed path under `~/dotfiles/agents/references/`, and resolve it for the actual host.

## Delegation helper and completion

Inspect and reuse `bin/launch-agent` where its contract fits. Implement a small companion `bin/agent-run` if interactive launching and batch lifecycle differ enough to justify separate commands. Proposed operations: `start`, `status`, `wait`, `reconcile`; names are an interface proposal, not existing commands.

Store each run under `${XDG_STATE_HOME:-~/.local/state}/agent-runs/<run-id>/` with a JSON record, prompt, log, and result. Write terminal records atomically. Keep metadata private to the user and exclude credentials. Minimum record:

```json
{
  "id": "20260906-example",
  "repo": "/path/to/repo",
  "provider": "codex",
  "model": "gpt-5.6-sol",
  "effort": "medium",
  "state": "running",
  "tmux_target": "agent-runs:example.0",
  "coordinator_session": "when-available",
  "worker_session": null,
  "exit_code": null,
  "result": "result.md"
}
```

Also record timestamps, scope/access options, and whether the coordinator has consumed the result. A shell wrapper captures actual exit status even if the provider produces no report. An unrecorded exit or vanished process is `unknown/interrupted`, never inferred success from a file's existence. A result can be complete but not yet reviewed.

“Immediately arm a watcher” becomes concrete harness-specific instructions:

1. Start the durable tmux worker and receive its run ID.
2. Before moving on, start `agent-run wait <id>` through the harness's supported background/wait mechanism and retain that handle.
3. On completion, inspect status and result, review the diff where relevant, and acknowledge consumption.
4. On a resumed coordinator, reconcile that task's records and reattach waits for unfinished runs before launching duplicates.

For Claude, the planned adapter uses its background Bash notification mechanism. For Codex, use the actual available process tool's yielded handle and wait/poll path. Do not claim that every Codex host can inject an unsolicited turn after the coordinator ends: validate that capability in the actual runtime, and otherwise keep a managed wait active or explicitly checkpoint the limitation. Tmux and a JSON file cannot themselves wake a stopped coordinator.

These instructions replace vague lifecycle wording; agents should not have to invent the protocol. Focused checks use trivial shell workers, not paid nested-model trials: success, nonzero exit, missing report, coordinator reconnect, and duplicate prevention. Verify provider flags and resume behavior separately against installed CLI help.

## Installation and checks

Extend `bin/sync-agent-skills` with a small host selector and preview/dry-run support. Keep Niri on Jacurutu; shared browser/vault/dependency/provider capabilities on both hosts. Preserve current ownership protection for foreign plugins and `.system` skills. Apply real manual-invocation metadata for Claude and Codex. No generic metadata registry or new management UI.

Check renamed references, frontmatter, generated link targets, and deletion scope. Exercise sync in temporary targets first. Keep review adapters visible only to their caller harness. Any OpenCode reference updates should be mechanical consistency fixes, not an unrequested redesign of its model policy.

After the user reviews the source changes, activation/sync can be handled as a separate explicit step. No Nix rebuild is part of this plan. Observe ordinary usage for a week after adoption; use Tracer for targeted failures rather than running a token-heavy evaluation suite for every prose edit.

## September 7 additions

- Relocate the newly added shared `agents/skills/stillsuit-plugin/` to project-local `.agents/skills/stillsuit-plugin/` after validating harness discovery. Keep Niri focused on compositor interaction, with a conditional pointer to shell-specific guidance.
- Dependency cache and all reference worktrees live under `~/.agents/vendored-deps`. Inspect the old store for unique work before removal; no mandatory migration.
- Preserve unslop's current behavior and avoid new global prose rules that fight it.
- Executor skill consolidation retains the deployed interface; direct MCP exposure is not assumed or introduced in this pass.
