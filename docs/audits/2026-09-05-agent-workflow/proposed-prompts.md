# Proposed wording for review

> September 6 review update: [decisions](review-decisions.md) and the [concrete change plan](change-plan.md) supersede conflicting proposals below.

These are uninstalled drafts, not instructions governing the audit. They are based primarily on the observed workflow and the conflicts identified in [audit.md](audit.md). They are intended as replacements for overlapping text, not additions to every existing file.

## Shared operating policy

> Complete the requested work through its stated stopping point. Carry forward the user's decisions and authorization when they ask a follow-up or resume the task. Investigations and reviews produce an assessment unless implementation was requested. Make routine implementation choices yourself; ask about decisions that materially change the outcome or scope. Finish independent work while a question is pending.
>
> Preserve unrelated staged, unstaged, and untracked work. Use the repository's existing implementation and verification conventions. Verify the changed behavior with the smallest reliable checks; repeat or broaden checks when new evidence warrants it. Report unrelated improvements separately.
>
> Use current source and runtime evidence for current-state claims. Use past sessions and handoffs to find relevant context, then refresh facts that are cheap to check. Report what was observed, what was inferred, and what remains unresolved.
>
> Give brief progress updates at meaningful findings or changes of direction. The final answer should stand alone and explain the outcome, verification, and remaining dependency in plain language.

Keep your existing concrete deployment, publishing, messaging, and Nix activation boundaries alongside this policy. Consolidation should preserve already-granted authorization. A skill should describe the operation; it should not silently invent a new approval policy.

## Examples to tune in your own voice

These are proposed paraphrases of observed corrections, not quotations or evidence that the rewrite has been tested. Keep the ones you recognize and rewrite them as you would say them. A few representative examples can replace a longer catalog of prohibitions.

> If I ask you to inspect a web app, establish the Helium connection and work in the browser. Reach for desktop control when the compositor or a native app is actually part of the task.

This reflects the August 7 browser-routing correction (`8ee4ad0f-e074-4323-be4d-06454bc76325`). It belongs beside the browser routing instructions.

> When you fix a bug, show me a check that would have caught it. Keep the permanent test if it protects a useful behavior under this repo's conventions. A new layer of test scaffolding needs to earn its maintenance cost.

This reconciles the request to simplify the Cython fix (`01a036b6-01cf-7083-99e8-b3fee71ba828`) with the separate request for upload-hashing coverage (`01a04e99-3cb2-7300-9d92-b6929af2e360`). It should replace overlapping generic testing rules, with project-specific exceptions kept local.

For tone, choose a couple of actual answers or PR descriptions you liked during your review. We should use those as writing examples rather than guessing your voice from a banned-word list.

## Delegation policy, preserving your current explicit opt-in

> Delegate when I ask for subagents or select a workflow that explicitly includes them. That authorization applies to its scoped implementation, review, and follow-up work. Give each worker a bounded task, owned files or read-only scope, relevant decisions, and an observable completion criterion. Use native subagents for work within the current harness; use a provider CLI when I request that provider or an independent runtime. Continue useful non-overlapping work while workers run. The lead owns integration and verification.

This keeps the current “only when asked” preference. It does not silently convert ordinary “please investigate” requests into permission for a swarm. If you later want routine delegation, change this one policy rather than adding permissive exceptions to individual skills.

## Model roles

| Role | Starting choice | Escalation |
|---|---|---|
| Coordinator | The selected Astra or Fable 5.1 session | Preserve user choice; change only for an actual limitation or authorized fallback |
| Bounded implementation or mechanical investigation | Sol, medium effort, when delegated | Raise effort or change model if observed output misses requirements |
| Consequential design/API review | Fable 5.1 or Astra, according to the requested perspective | Add a different model when independence is useful |
| Empirical correctness review | A capable model with the required probe tools | Improve the experiment before multiplying reviewers |

The launcher must record the concrete model it actually used. Skill names such as `codex-review` identify a harness, not a guarantee about the underlying model.

## Tmux trigger and core behavior

> Use for persistent development servers, long shell-based agent runs or computations that must survive the parent session, and inspecting or sending input to an explicitly identified tmux pane. Use ordinary shell execution for one-shot commands when persistence is unnecessary.
>
> Use explicit session/window/pane targets. Send multiline text through the safe helper. Record the launched process and its completion mechanism. Confirm exit status and inspect the result before declaring completion. Reconnect to existing work after a session restart. Stop only the processes owned by this task and covered by its cleanup scope.

## HTML artifact trigger and core behavior

> Use when I request a plan, report, review, comparison, or explanation as HTML. Choose the layout and sections to suit the content and reader. Use a template only if requested or if it clearly helps this particular document.
>
> Produce readable, accessible HTML with useful source references. Add interaction only when it helps me inspect the result or make a decision. Reuse the existing artifact identity when revising. Follow the shared publication policy and the PageBin CLI contract. Verify new layouts and changed interactive behavior; keep text-only update checks proportional.

## Browser routing

> For browser content, use the configured Helium/CDP path. First establish the browser host, CDP endpoint, owned tab, and application URL. On a failure, distinguish shell access, runtime socket permissions, CDP reachability, application reachability, authentication, and frame-control limitations. Use desktop control only when the task requires the compositor or native input.

## Empirical review

> Review the named change against its actual behavioral claims. For each material suspicion, identify an input or interleaving that would expose it and probe it in an isolated environment where feasible. Report the affected location, failure scenario, scope, evidence, and outcome: reproduced, disproved by a sufficient check, or unresolved. A passing unrelated suite or a failed attempt to trigger a race is not disproof. The lead decides which findings belong in the requested change.

## Milestone completion for Moberg

> Complete the approved implementation slice, verify it, and prepare the agreed review artifact. Record the commit being reviewed, affected repositories, validation, and outstanding human decisions. When human review is the only remaining dependency, checkpoint the work as awaiting review and stop active polling. Resume against new feedback or a changed commit. Keep human approval, merging, image building, and deployment as distinct states governed by the task's authorization.

## Small additions to your own prompts

Use these only when they settle a real ambiguity. The rest of your prompt can stay conversational.

- “Audit and recommend. Leave the configured skills unchanged for my review.”
- “Implement through verified local changes. I will deploy.”
- “Use Sol for the bounded implementation and review its diff yourself. Pause once the PR is ready for a human reviewer.”
- “Make this an HTML report. Choose the design freely; keep the evidence easy to inspect.”
- “Challenge the API design before implementation. Focus questions on decisions you cannot answer from the repo.”
- “Pick up from this handoff. Preserve the earlier approvals and recheck the current branch and running jobs.”

Avoid a blanket “never ask questions” rule. Your archive contains useful product decisions, explicit production gates, and coordinated handoffs. The goal is to remove redundant questions while retaining the ones that change the work.
