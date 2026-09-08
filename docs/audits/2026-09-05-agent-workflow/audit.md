# Agent workflow audit, September 5, 2026

> Historical audit/proposal. Superseded where it conflicts with the reviewed source files and [September 8 follow-up](fable-follow-up.md). See the [audit index](README.md) for current entrypoints. Retained for rationale and chronology, not as active agent instructions.

My recommendation is to keep the useful tools, reduce the number of workflows that trigger automatically, and move repeated operational rules into helpers. The biggest debt is conflicting routing, machine-specific facts presented as universal, and duplicated process instructions. Deleting rarely used skills alone would miss most of it.

This is a first-pass assessment for your review. No skills, settings, memories, running services, or remote repositories were changed. The companion [inventory](inventory.md) covers all 30 active personal skill sources and has space for your decisions. [Evidence](evidence.md) records the sampling limits and specific sessions. [Prompt drafts](proposed-prompts.md) makes the proposed behavior concrete without installing it.

## What the archive actually shows

I queried Tracer on Jacurutu and Sietch, deduplicated their overlapping records, and analyzed archived turns dated **August 7 through September 5**. The primary recent window is **August 23 through September 5**.

- 459 unique metadata records before exclusions.
- 238 session archives with in-window content after excluding automatic approval-review sessions and records with no agent turns. 114 originated on Jacurutu and 124 on Sietch; 183 are Codex and 55 Claude.
- 84 of those archives have content in the primary two-week window.
- The corpus includes delegated agents, continuations with inherited history, and scheduled work. These are **session records, not 238 independent human workstreams**.
- Fable 5.1 appears in seven retained records. Astra does not appear in the retrieved model metadata. Recommendations for these models therefore combine your stated preferences with their current official guidance; this is not an empirical Astra-versus-Fable benchmark.

The strongest observable load signals are Coppermind, Unslop, tmux, HTML plans, handoff, browser access, and notifications. That matches a workflow of long investigations, evidence gathering, branch integration, review, and resuming work across machines. The complete counts are in the inventory.

A load count measures reach, not value. Unslop's 55 observed session loads partly follow from its “must always apply” trigger. One milestone-loop session supported a substantial implementation. It would be a mistake to discard the latter for being less frequent.

## Fix factual and routing debt first

### The vault path differs by host

The shared [Coppermind skill](../../../agents/skills/coppermind/SKILL.md#L10) states that the doubled path is universally correct. Live checks found:

| Host | Manifest exists | Alternative checked and absent |
|---|---|---|
| Jacurutu | `~/notes/04-projects/manifest.md` | `~/notes/coppermind/04-projects/manifest.md` |
| Sietch | `~/notes/coppermind/04-projects/manifest.md` | `~/notes/04-projects/manifest.md` |

The skill files have identical hashes across the two machines. Replacing the doubled path globally would fix one machine and break the other. Resolve the root through configured host data and confirm the manifest exists. If both candidates exist, use the configured root rather than silently picking one. Do not move vault data as part of this cleanup.

Also review the skill's checkbox-task model against the recent TaskNotes migration before making it the default for task writes. The archive contains active TaskNotes work, but I did not independently inventory the current task storage on both hosts, so that portion remains an audit follow-up.

### Host selection is currently missing

[bin/sync-agent-skills](../../../bin/sync-agent-skills) sends every shared skill to Claude, Codex, and OpenCode. It selects by agent family, but has no host or capability condition. Sietch currently has `niri-computer-use` linked in both Claude and Codex; Hyprland is installed there and `niri` was not found in the inspected shell PATH.

Extend the existing sync mechanism with the smallest explicit host and harness selectors needed for the current fleet. A short data table is sufficient; add capability abstraction only when a real second implementation needs it. Keep invocation policy beside each skill and translate it for each harness. Start with these distinctions:

| Capability | Where it belongs |
|---|---|
| Niri desktop control | Jacurutu's Niri environment |
| Hyprland desktop control | A future Sietch adapter, only after a real task demonstrates need |
| Helium browser control | Hosts that can run a browser or reach an explicitly configured forwarded browser |
| Vault workflows | Hosts with a verified vault root |
| Fleet access | Hosts with permitted outbound agent SSH routes |
| Provider CLI delegation | Hosts with the requested CLI and working credentials |
| Moberg release/review conventions | Moberg repositories, not every personal project |

Do not make Helium laptop-only. Sietch's browser work can use its own browser or a forwarded laptop browser. The skill must identify which browser is being controlled before deciding what `localhost` means.

Use the same selection data for installation and the human-readable inventory. Keep foreign plugins and generated `.system` skills outside this script's deletion ownership. The current script's protection for unmanaged entries is worth preserving.

### Some review guidance is too strong

[review-bot-gate](../../../agents/skills/review-bot-gate/SKILL.md#L39) treats a green CI run as disproof of a predicted test failure. Require the relevant test, inputs, environment, and commit to match. A passing unrelated suite cannot establish that a finding is false.

[adversarial-probe-review](../../../agents/claude-skills/adversarial-probe-review/SKILL.md) also overstates what a failed reproduction establishes. A probe that does not reproduce a race has not disproved the race unless it exercised the necessary interleaving. Keep separate outcomes for reproduced, disproved by a sufficient check, and unresolved. A reproduced issue still needs a scope and impact decision; “confirmed” should not automatically expand the implementation.

These are assessment defects in the skill text. I am not claiming they caused a particular production defect.

## Keep tmux, but shrink its job

I disagree with deleting tmux outright. It has a useful, narrow role: persistent dev servers, long computations, CLI agent runs that must survive the parent, and inspecting a specific pane you name. The archive includes all of those uses.

The current 176-line guide spends too much space teaching ordinary tmux commands and repeating its quick reference. Preserve explicit targets, safe multiline input, process ownership, and durable completion tracking. Move uncommon commands behind a reference. Ordinary builds and one-shot shell commands should use the harness's process tools when those suffice.

There is a direct contradiction to resolve. Claude's [global instructions](../../../agents/claude/CLAUDE.md#L81) recommend `run_in_background` for long jobs, while `codex-implementation` says not to use that for jobs longer than a couple of minutes. The milestone loop explains that detached tmux needs a watcher that survives or can be restored after a harness restart. Pick one lifecycle contract and reference it.

The right next implementation is a small delegation helper, preferably by extending existing launch helpers after inspecting their contracts. It should return a run ID and record the actual model, effort, repo, process identity, output location, terminal status, and exit code. A report file's existence is not a sufficient completion contract. Resume must retain the chosen model and access boundaries. Restart recovery should discover existing work before launching duplicates.

Terminal Control solves a different problem: observing and driving TUIs in a real PTY. Keep it available for that, but remove “shell process” from its broad trigger. Its Codex metadata already disables implicit invocation; Claude's frontmatter does not. Make the choice consistent. Code walkthrough can leave the active set, with its Navi/OBS details retained as an optional reference if you ever want the workflow again. First update any project review skill that still requires it.

## Preserve Helium's operational knowledge

Keep Helium as a shared skill. Its value is your environment-specific contract: CDP endpoint selection, tab ownership, remote networking, and recovery. Keep the `agent-browser` guide as the version-matched command reference. Do not merge its entire CLI manual into Helium.

Tighten routing:

1. Browser URL, web app, or Electron DOM task: browser/CDP path.
2. Native window, compositor, screenshot outside browser content, or real desktop input: appropriate desktop adapter.
3. Interactive terminal application: Terminal Control when requested.
4. Server lifetime or existing pane inspection: tmux.

The browser description currently competes with Executor for Slack research, and Claude's global browser section still mentions a separate `dev-browser` route. Prefer Executor for message search, Helium for actual browser interaction, and load a special browser reference only when its capability is required.

A useful Helium doctor should distinguish shell/sandbox failure, missing runtime-socket permissions, unreachable CDP, wrong browser host, application URL reachability, authentication, and unsupported frame inspection. The archive contains shell failures before any browser interaction and a PageBin opaque-origin iframe limitation. Neither should be diagnosed as a broken web app.

The manual reverse-tunnel recipe also uses plain `ssh sietch`, while Fleet says agents use `sietch-agent`. Align the reference with Fleet and the existing helper, which already resolves the agent alias.

## HTML plans should preserve evidence and free the design

Keep the capability; consider renaming it `html-report` or `html-artifact` while retaining `html-plans` as a temporary compatibility name. Its job should be to turn the requested content into a readable artifact with stable identity.

Remove the default pull toward the artifact shell and implementation-log template. The current text already calls the template optional, so this is not literally a mandatory-template bug. However, the references and examples repeatedly point back to the same structure. Your report of repeated designs is stronger evidence than the word “optional.” Make templates opt-in, and stop prescribing a risk register, rollout, rollback, glossary, or other sections unless the actual subject needs them.

Keep self-contained assets by default, accessible layout, responsive tables, working navigation, truthful source references, and secrets exclusion. Require rendering checks for new layouts or interactive behavior; avoid repeating a full desktop/mobile/console ceremony for every text-only update to a verified layout. For stateful controls, storage and clipboard failures need graceful fallback, as the August 22 PageBin session demonstrated.

Keep PageBin transport as its own CLI-backed skill. Authoring, publishing, and maintaining a long-running work log are related but separately triggered jobs. Preserve existing artifact identity on updates. Put your publication preference in one shared policy location, with consistent harness settings, rather than having several skills appear to grant overlapping authorization. Your Claude settings already explicitly allow PageBin HTML uploads, so this is consolidation, not a proposal to add another approval step.

For implementation logs, keep only the current state, decisions, validation, next work, and unresolved dependencies. A finished report does not need to become a running log automatically.

## Make review portable, and separate implementation from human review

Promote the method in `adversarial-probe-review` to shared scope. The useful part is deriving attacks from invariants and returning executable evidence. The Claude-specific spawn command belongs in an adapter. Astra can coordinate the same method, and the current agent can conduct a bounded probe when delegation is not enabled.

Keep `claude-review` and `codex-review` as recognizable entrypoints when you explicitly want another provider's opinion. Share their intent packet, finding format, and adjudication rules. Use native delegation for same-harness work; use another CLI when you want that provider, a distinct runtime, or stronger context separation. Codex itself should not need to nest another Codex CLI merely to obtain a worker.

The active delegation skills already say 5.6. Commit `b1b36423` and the August 30 memory-audit session explain the change. The real remaining issue is that their example commands omit a model flag. Their behavior silently follows the global default. Pin `gpt-5.6-sol` when Sol is requested, and maintain Astra/Fable coordinator choices separately. Historical model mentions and UI migration history do not need a search-and-replace.

The universal requirement to pair every GPT review with Fable/Opus was a deliberate recent choice, not accidental baggage. I recommend narrowing it now: require the extra perspective at material API/design decisions and high-risk behavioral changes, or when you request it. Do not make the second review a mandatory tax on every scoped implementation check. Preserve an explicit option for paired review.

Make milestone delegation a human-selected workflow with a shared implementation protocol. For Moberg, use two clocks:

- **Implementation:** complete the approved slice, validate it, perform the appropriate independent review, and prepare a coherent handoff or PR.
- **Team review:** record outstanding human decisions, the reviewed commit, CI evidence, and linked PR dependencies. Resume when reviewer feedback or a new commit changes the state.

“Awaiting human review” is a valid resting state. It does not mean keep a model polling for days, merge independently, or reopen settled architecture to find more work. Linked Moberg PRs also need not be a linear GitHub stack. Preserve that distinction in a project-local adapter.

## Prompting changes for your target models

Use a small shared policy plus thin model-specific guidance. Your freeform prompts already carry valuable domain reasoning and corrections. I would not replace them with a compulsory questionnaire.

For Astra, the official guide highlights sensitivity to skill instructions, unnecessary clarification, excessive testing on small tasks, and delegation that may need explicit direction. That supports deleting conflicting rules, retaining prior authorization through follow-ups, and defining a checkable completion point. It does not justify duplicating the entire official guide into every skill. [Astra guidance](https://developers.openai.com/api/docs/guides/latest-model?model=gpt-6-astra)

For Fable 5.1, retain concise progress updates and explicit scope preservation, favor targeted edits, and separate scratch verification from permanent tests. Its guidance cautions that older anti-formatting rules can now suppress useful structure. Start from the recommended high effort and test lower levels on your actual tasks. If progress disappears, check whether the client displays it before adding more prompt rules. [Fable 5.1 guidance](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5-1)

Keep Sol for bounded implementation, mechanical work, and an additional review perspective when useful. Your August 30 instruction explicitly chose Sol at medium effort. Replace the old numeric “taste/intelligence/cost” table with roles and measured exceptions; its scores cannot represent the current stack and it omits Astra.

The prompt improvement I would ask of you is small: where it matters, state the deliverable and stopping boundary in one sentence. “Investigate and recommend; leave code unchanged.” “Implement through verified local changes; I will deploy.” “Prepare the PR and handoff; pause for human review.” This avoids making the model infer a changing approval boundary from an otherwise rich paragraph. See the concrete drafts in the companion file.

Keep domain-specific test preferences local. The archive includes a dashboard-specific request against test scaffolding, and a separate request for focused upload-hashing coverage. Flattening those into either “always add tests” or “never add tests” would lose your actual intent.

## What to borrow from the references

Borrow individual methods, not entire installations. Both public repositories were inspected at recorded commits; the videos were examined through downloaded English automatic captions, with relevant sections read rather than inferring advice from titles.

| Reference | Fit for your workflow | Adaptation |
|---|---|---|
| Matt: grilling / grill-with-docs | Human-invoked design stress test before unfamiliar or consequential work | Bound the interview to material decisions. Remove mandatory exhaustive questioning and automatic subagent dispatch. |
| Matt: domain-modeling | High value in Moberg, where “archive,” “data object,” “measurement,” and “associated CNS” carry specific meanings | Use existing project documentation; add glossary entries only when ambiguity actually matters. Preserve selective ADRs. |
| Matt: diagnosing-bugs | Strong match for your profiling and deployment investigations | Keep a reproducible feedback loop and falsifiable hypotheses. Allow qualified analysis when production access is missing; do not require a repro before any useful reasoning. |
| Matt: TDD | Useful optional test-first mode | Keep independent expected values and behavioral tests. Remove the requirement to ask you to approve every test boundary. Honor local test conventions. |
| Matt: wait-what | Same purpose as your tiny `bro` command | Pick one name; do not install a duplicate. |
| Matt: writing-for-agents | Already adopted | Keep one reference and adapt the invocation-mechanics notes to each harness. |
| pstack: create-verification-skill | Best new addition for Moberg and desktop work | Build a project-local launch/doctor/drive/evidence/cleanup recipe from proven commands. Prefer `.agents` where your tooling supports it; preserve existing selectors and fixtures. |
| pstack: encode-lessons-in-structure | Best maintenance principle | Use helpers for root resolution, process completion, exact CI-run tracking, and capability selection. Avoid another mandatory principle-reading chain. |
| pstack: eval playbook | Useful before promoting broad prompt changes | Compare old/new instructions on normal-looking tasks in isolated checkouts; judge output quality without revealing the model. Adapt to Tracer. |
| pstack: babysit | Useful distinction between status, bounded repair, and merge-ready | Adapt the human-review resting state to Bitbucket. Do not import its GitHub watcher, stack topology, or merge behavior wholesale. |
| pstack: poteto-mode / arena / swarm | Too much mandatory process as a global default | Retain selected methods for explicit high-effort tasks. No automatic design tournament for every function boundary. |

[Matt library](https://github.com/mattpocock/skills), [pstack library](https://github.com/cursor/plugins/tree/main/pstack). Exact inspected source paths and video timestamps are in [evidence.md](evidence.md).

Theo's strongest applicable advice is to derive skills from your own observed friction, make descriptions describe triggers, and prefer structural fixes for recurring mistakes. His HTML breakdown also separates communication from transport and removes unnecessary workflow prescription. I would adopt those ideas while keeping your evidence requirements. His preferences about browser verification or memory are not reasons to remove checks that protect your actual workflow. [Skills discussion, 28:06](https://www.youtube.com/watch?v=0oXOOlqVu5M&t=1686s), [structure before instructions, 29:06](https://www.youtube.com/watch?v=Jf54k7tFeEc&t=1746s), [HTML simplification, 45:04](https://www.youtube.com/watch?v=e1snsuY4lTI&t=2704s)

## Revisions after the broader video pass

The `summarize` extraction succeeded for all five videos and reproduced the same caption text as the earlier extraction after whitespace normalization. Reading the broader discussions changes the proposed implementation in these ways:

- **Keep availability simple.** Theo describes abandoning a buggy custom skill-management system. For this fleet, extend the working sync script with explicit selectors before designing a registry or management UI. [Breakdown, 3:20](https://www.youtube.com/watch?v=e1snsuY4lTI&t=200s)
- **Use examples to convey preferences.** Replace some abstract writing rules with two or three examples you recognize and edit yourself. The companion draft now includes browser routing and scoped verification examples from your workstreams. [Examples, 14:02](https://www.youtube.com/watch?v=e1snsuY4lTI&t=842s)
- **Trial borrowed methods before installation.** Try the relevant text in one session, checking any dependencies first. Keep deliberate interviews manual; evaluate debugging guidance where ordinary investigation should discover it. [Trying skills, 13:54](https://www.youtube.com/watch?v=0oXOOlqVu5M&t=834s)
- **Measure the intervention and its cause.** For a slow or corrected task, classify time spent on useful investigation, repeated setup, redundant checks, and actual external waiting. Locate the instruction or tool failure behind the correction before adding a rule. Compare matched tasks; task assignment confounds model rankings. [History audit, 19:51–24:13](https://www.youtube.com/watch?v=e1snsuY4lTI&t=1191s)

These are adaptations to your setup. In particular, engineering away a repeatable bug can reduce agent supervision, but it does not replace required human review at Moberg. Keep that organizational decision explicit. [Memory discussion, 24:24–30:20](https://www.youtube.com/watch?v=Jf54k7tFeEc&t=1464s)

## Sequence the cleanup

1. **Correctness:** host-aware vault resolution, review-evidence wording, remote SSH consistency, and explicit delegation model selection.
2. **Availability:** add minimal host and harness selectors; make manual invocation consistent across harnesses; remove Niri from Sietch's default set; retain source and rollback paths.
3. **Simplification:** shrink tmux, relax HTML authoring, consolidate delegation mechanics, and share empirical review. Archive code walkthrough after checking its callers.
4. **Workflow:** split milestone execution from human-review waiting; pilot a project-local Moberg verification recipe.
5. **Evaluate:** try one borrowed method on a real task without installing it globally. Promote it only after it improves the result; then check the relevant cases below.

Use whichever of these six cases exercises the changed instruction: a small source edit, a real browser verification with a failing CDP preflight, a long CLI worker interrupted and resumed, an HTML report, a Moberg PR awaiting a human, and a substantive empirical review. Compare current and revised prompts under the same model and environment. Score correct outcome, scope preservation, unnecessary questions, wrong tool selection, recoverability, and usefulness of the final artifact. Include prompts where the skill should stay inactive, such as a one-shot shell command for tmux or a browser-only task for Niri. Track work added during review against the original request; additional findings should not silently expand the approved change. Measure time and tokens only where the archive or harness actually exposes them. No candidate runs were launched in this audit.

I would not begin by disabling all memory. The August 30 cleanup already removed stale Moberg memories and promoted selected rules to project guidance. Keep short preferences and discovery pointers; put live branch/PR state in dated handoffs or the tracker, operational mechanics in tools, and current code behavior in the repository. Reverify cheap, changeable facts. The two different vault roots demonstrate why both blanket memory trust and blanket memory deletion are poor substitutes for discovery.
