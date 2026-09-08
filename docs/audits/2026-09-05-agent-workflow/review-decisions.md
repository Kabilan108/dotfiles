# Review reconciliation, September 6

> Historical audit/proposal. Superseded where it conflicts with the reviewed source files and [September 8 follow-up](fable-follow-up.md). See the [audit index](README.md) for current entrypoints. Retained for rationale and chronology, not as active agent instructions.

This records the user's feedback and the revised proposal. It supersedes conflicting recommendations in the initial audit and inventory. Configured skills have not been changed. User prompt additions now live in [prompt-quick-reference.md](prompt-quick-reference.md). The concrete file-by-file implementation scope is [change-plan.md](change-plan.md); deferred project work is [moberg-follow-up.md](moberg-follow-up.md).

## Settled direction

- The user moved Sietch's vault into `~/notes` proper. Treat the old mismatch as historical evidence; verify the new root during implementation rather than build permanent accommodation for the obsolete layout. Update Coppermind for TaskNotes, the user-confirmed current convention.
- Helium, vault workflows, and provider delegation are available on both Sietch and Jacurutu. Niri remains host-specific. Use small host/harness selectors in the existing sync mechanism.
- Rename HTML authoring to `html-communication` with no compatibility name. Update callers. Keep PageBin transport separate, with publication authorization in one shared policy location. Retain useful rich templates as optional references, reduce the default pull toward them, and include optional semantic structure and a lightweight playground example; remove the inactive-skill dependency. Preserve graceful stateful-control failure handling without mandatory full viewport checks on routine edits.
- Consolidate Executor access into one narrowly triggered skill with Google and Slack references. Shared connection mechanics live once; service-specific operations and authorization stay with their references.
- Remove code-walkthrough, learn, learn-skill, and all six WIP skills. Keep bro unchanged. Terminal Control is human-invoked in both harnesses.
- Keep cross-provider entrypoints isolated by caller harness. Narrow mandatory paired reviews. Fable 5.1 defaults to medium by user preference.
- Skip importing TDD and poteto/arena/swarm initially. Favor domain modeling and project verification recipes. Use a human-invoked babysitting workflow with an explicit awaiting-human state for Moberg.
- Evaluation should be inexpensive: deterministic helper checks where failure is consequential, followed by a week of ordinary usage. No blanket multi-model evaluation or repeated trial runs for prose changes.

## Placement proposal

| Material | Home | Invocation |
|---|---|---|
| Autonomy, good questions, preserving scope and approvals, explicit opt-in delegation | Short replacement sections in `agents/claude/CLAUDE.md` and `agents/codex/AGENTS.md` | Always available |
| Provider model and effort defaults, helper discovery | Corresponding harness global file | When delegation is authorized |
| Process launch, exit status, notification, restart recovery | Shared helper and its command help; tmux skill for persistence mechanics | Operation-driven |
| Cross-provider review details | Claude-only Codex adapter and Codex-only Claude adapter | Explicit cross-provider request |
| Browser choice | Brief global routing rule | Available integrated browser when suitable; Helium when explicitly requested, for session reuse, or as fallback |
| Helium endpoint, tab ownership, connection diagnostics | Helium skill | Actual Helium use |
| General behavioral verification preference | Short global principle | Relevant changes |
| Exact tests, fixtures, launch commands, special test preferences | Project guidance or verification recipe | Relevant project task |
| Moberg implementation/review lifecycle | `/vault/work/moberg/dev-server/.agents/skills/` in the follow-up rollout | Human-invoked workflow |
| Domain glossary | Existing Moberg project documentation | Relevant domain work |
| Detailed empirical review method | Optional review reference, proposal below | Consequential behavioral review |
| Personal writing examples | A few user-edited examples in the owning global or skill section | No separate mandatory example file |

The shared operating policy was a proposed replacement for duplicated global prose, not another installed skill or an additional always-loaded document. The delegation policy is global. Browser-specific examples belong with browser routing. The testing example expresses a global preference, with repo-specific exceptions remaining local. Global files should point to helpers rather than reproduce their operational manuals.

## Revised judgments

**Review packaging.** Remove review-swarm from the global active set; add project-specific review roles only when a real task warrants the expense. Remove review-bot-gate from the active set for now, retaining its corrected evidence principle in the review guidance. For adversarial probing, favor a short optional reference over another global skill. The original census found one archive loading adversarial-probe-review. A follow-up literal user-message search found two distinct direct adversarial-review requests across three archive records (one inherited duplicate), plus a workshop discussion about the idea. This is a lower bound for wording variants, not a complete review frequency measurement. It does not show that the standalone skill adds value over an ordinary request.

**BTCA.** The initial recommendation was too narrow for the user's intent. Rename to `dependency-source`; retain the central store at `~/.agents/vendored-deps` and a reusable, revision-aware source checkout workflow. Resolve the dependency and relevant version from the current task/lockfile, reuse or fetch its source without disturbing unrelated checkouts, inspect implementation and tests, and cite revision-specific evidence. Remove app-startup theater, forced lists, universal full code examples, and automatic main-branch preference. Allow model invocation when dependency implementation evidence is needed; an ordinary API question need not fetch a repo.

**Browser routing.** The earlier unconditional Helium preference was wrong. Put the short selection rule in the globals and operational detail in the selected skill. The archive contains explicit T3-browser requests on August 14 and August 26; those requests do not establish successful use. Extracted tool calls are often truncated generic `exec` wrappers, so the current evidence does not support a T3-versus-Helium usage rate. Keep remote Helium outside the default path pending a concrete need; the user's preference for T3 makes automatic tunneling inappropriate.

**Descriptions.** The tmux description should name its positive invocation cases. Move advice about ordinary shell execution into its body or global process routing. Do not rely on agent-browser's `hidden` field to suppress discovery; it was visible in the actual catalog.

**Questions.** No blanket “never ask questions” rule was identified in the inspected global files. The original draft introduced an unnecessary hypothetical warning. Remove it; retain a positive preference for questions that resolve consequential ambiguity.

## New references

[HumanLayer show-me](https://github.com/humanlayer/skills/blob/main/plugins/show-me/skills/show-me/SKILL.md) selects compact visual forms including pseudocode, call/file/component trees, Mermaid, diffs, and focused HTML. Include an adapted model-invokable version in the initial pass (final review decision). Route its HTML output through html-communication when useful and adapt its `open` command to the environment. It should not turn every explanation into a published report.

[Columbia Pages](https://github.com/davis7dotsh/columbia-pages/blob/main/.skills/columbia-pages/SKILL.md) is a useful example of semantic HTML and optional components. Its simplicity partly comes from a server-provided theme and body-only input contract. Borrow the restrained authoring guidance; do not copy its transport commands, house-theme default, or server assumptions into PageBin.

## Delegation findings

[Sol's report](delegation-wakeups.md) found 27 successful delivered completion events, all with coordinator follow-through, and three failure events. The notification sample cannot count unwatched tmux completions. It supports tmux plus an immediately armed watcher and durable recovery record, not a model reliability ranking. The helper should record actual terminal state and exit code; report existence alone must not imply clean exit. Keep implementation modest: launch/status/wait/reconcile operations, not a new orchestration service.

## Final clarifications from review

- Global browser routing should describe available integrated tools generically, without assuming the agent runs in T3. Keep Helium model-invokable for a task requiring its persistent session or fallback capability. Helium mechanics live in helium-browser-use; agent-browser CLI mechanics remain in agent-browser.
- Both browser-monkey configurations were found and inspected: `agents/claude/agents/browser-monkey.md` and `agents/codex/agents/browser-monkey.toml`. Remove both in the implementation pass; they duplicate browser instructions and assume auto-launched Chrome.
- Delegation authorization refers to the user's permission and worker scope, not provider login. Do not add routine authentication ceremony.
- Preserve the two cross-provider review entrypoints in their respective harness roots; retire implementation/computer-use wrappers once helper coverage replaces them.
- Discover empirical-review guidance through a conditional pointer in each global file and the retained review skills, all pointing to one `agents/references/empirical-review.md`. It is not a separate mandatory skill.
- A durable run record is a per-run JSON/status/log/result directory in the user's state directory. The worker wrapper records actual exit status. Harness-specific wait instructions replace vague “arm watcher” language; Codex wakeup after an ended turn must not be assumed.
- Keep show-me model-invokable (final review decision). Retain the central dependency store. Keep rich HTML templates as an optional starting point rather than replacing all of them.
- Defer Moberg skill implementation to its dedicated follow-up list. General verification-skill creation guidance can be trialed in this pass.

## September 7 alignment

Fetched origin/nixos and rebased successfully onto `50723fcc`; HEAD and origin/nixos have no divergent commits. Audit documents remain untracked and preserved. No skill revisions drafted yet.

- Use `~/.agents/vendored-deps` for both dependency source checkouts and their worktrees. Rebuild the old cache cheaply rather than requiring migration; check for unique edits/active users before retiring it.
- Keep unslop close to its current version and preserve its effect; do not convert it to manual-only or duplicate its checklist in globals. No urgent correctness issue was established that requires changing it.
- show-me already exists upstream. Adjust its invocation metadata in the future pass rather than adding a second copy.
- stillsuit-plugin is currently under `agents/skills/`, despite its project-specific intent. Proposed placement: dotfiles `.agents/skills/stillsuit-plugin/`, after confirming discovery in the supported harnesses. Preserve its current operational guidance.
- Niri's routing already names stillsuit-next. Add only a short pointer for shell/plugin work and any verified compositor-specific gap. Status/containment diagnostics, surface IPC, and workbench fixtures belong with Stillsuit; avoid duplicating them in Niri.
- codex-review includes Astra for peer/oracle-style consultation as well as Sol for bounded reviews. claude-review targets Fable 5.1 at medium.
- Empirical review reference remains `~/dotfiles/agents/references/empirical-review.md`, linked conditionally from globals and review adapters.
- The initial Moberg glossary is a concrete deliverable of the separate Moberg rollout.
- Explicit Helium requests take precedence over the generic integrated-browser preference.

Executor: keep the existing connection and code-execution interface for this skill cleanup. Native host code composition can call Executor's execute tool; it need not duplicate service loops outside Executor. Current upstream MCP host still registers execute/skills/resume, plus optional integration-search tools. Those search tools do not constitute direct exposure of all underlying operations. A direct-MCP migration remains a separate investigation, not a prerequisite for consolidating the skills. No live Executor upgrade or protocol change was performed.

## Draft implementation, September 7

The source revisions are now available, uncommitted, for review. See [implementation-review.md](implementation-review.md) for changed paths, verification, and remaining runtime limits. Niri stays cross-project on Jacurutu: its observed loads span Omasnap, dotfiles, Coppermind and Moberg. Only the Stillsuit plugin skill moved to dotfiles project scope. Executor retains its current interface.
