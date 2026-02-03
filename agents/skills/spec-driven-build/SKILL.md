---
name: spec-driven-build
description: "Orchestrate multi-phase feature builds from a detailed spec using worktrees and subagents. Use when the user has a spec and wants to build it in parallel phases with isolated worktrees, coordinated merges, and visual verification. Triggers on: 'build from spec', 'orchestrate build', 'run the phases', or when an ORCHESTRATOR.md exists."
---

# Spec-Driven Build Orchestrator

Coordinate multi-phase feature builds from a spec file. The orchestrator does NOT write code — it creates worktrees, launches subagents, monitors progress, reviews output, merges branches, and verifies results.

## Required Skills

- **worktrunk** — for `wt` CLI worktree management (create, switch, list worktrees)
- **tmux** — for understanding tmux concepts. For orchestration, prefer the helper scripts (`launch-agent`, `send-to-pane`, `poll-agents`) over raw tmux commands — they handle the boilerplate.
- **handoff** — for context overflow recovery

## Workflow Overview

1. Create isolated git worktrees for each phase
2. Launch Claude Code subagents in tmux panes
3. Send structured prompts with file boundaries
4. Monitor for completion
5. Review output
6. Merge branches
7. Verify results visually

## Phase Execution Steps

### Step 1: Create worktree

```bash
cd <repo-root>
wt switch --create --base <base-branch> <branch-name>
wt switch <base-branch>  # switch back
```

IMPORTANT: Always use `--base <base-branch>` to ensure the worktree branches from the correct base. Without it, `wt` may default to branching from `main`.

### Step 2: Launch subagent in tmux

Launch subagents in the current window so you can monitor them alongside your own pane:

```bash
pane_id=$(launch-agent -d <repo-root>/.worktrees/<sanitized-branch> -t <task-list-id> -n "phase-N")
```

This creates a split pane, cd's to the worktree, and starts claude with `--dangerously-skip-permissions`. The pane ID is printed to stdout for use with `send-to-pane` and `poll-agents`.

Once claude starts in the pane, send the task prompt:

### Step 3: Structure the subagent prompt

Pipe the prompt directly to `send-to-pane`:

```bash
cat << 'EOF' | send-to-pane "$pane_id"
<prompt content here>
EOF
```

Template:

```
You are implementing Phase N of <project>.

**Your task:** Read task #<ID> via TaskGet for full details. Also read <spec-file> for complete requirements.

**Specific section:** [what to implement]

**Files you should create/modify:**
- [explicit list]

**Files you must NOT modify:**
- [explicit list — prevents merge conflicts]

**Key implementation details:**
- [3-5 non-obvious bullet points]

**Rules:**
- DO NOT enter plan mode. Implement directly.
- Only format/lint files you created or modified — do not reformat unrelated code.
- If you hit a blocker you cannot resolve in 3 attempts, print "BLOCKED: <reason>" and stop.
- If you are approaching context limits, invoke the handoff skill to write a HANDOFF.md in the worktree root before stopping.

**When done:**
1. Run lint
2. Run build
3. Commit with descriptive message
4. Call TaskUpdate with taskId "<ID>", status "completed"
5. Print "PHASE COMPLETE"
```

### Step 4: Monitor completion

Use `poll-agents` to watch for completion:

```bash
# Single check
poll-agents "$pane_id"

# Poll until done (checks every 30s, also monitors git activity)
poll-agents -p -i 30 -w <worktree-path> --since <base-commit> "$pane_id"

# Monitor parallel phases
poll-agents -p -i 30 "$pane_2a" "$pane_2b"
```

The script checks for "PHASE COMPLETE" (success) and "BLOCKED:" (failure) in pane output. It also reports `EXITED` if a pane dies.

You can also check manually:
- TaskList (check task status)
- `git -C <worktree-path> log --oneline -3` (check for new commits)

### Step 5: Review

- `git -C <worktree-path> diff --stat HEAD~1`
- Read key files to sanity-check

### Step 6: Merge

**NEVER use `wt merge`.** It has multiple failure modes:

- Defaults to merging into `main` instead of your base branch
- Pre-commit hooks can fail on non-standard file formats (e.g., JSONC tsconfig files)
- Failed merges can rebase your branch onto the wrong target, corrupting state

Always merge manually:

```bash
cd <repo-root>
git merge --ff-only <phase-branch>  # use ff-only when possible (sequential phases)
# OR
git merge <phase-branch> -m "Merge <phase-branch> into <base-branch>"  # when branches diverged (parallel phases)
```

After merging, if the project uses hot-reload dev servers, changes are picked up automatically.

### Step 7: Visual verification

Use Chrome MCP tools (if available) to navigate to the dev server and verify the UI renders correctly. Check server logs for errors.

## Parallel Execution Rules

- Max 2 subagents in parallel
- Each parallel agent must have **strict file boundaries** — no overlapping file modifications
- Infrastructure/shared code phase must complete first before parallel phases
- Merge parallel branches sequentially: first one ff-only, second one regular merge
- After merge, run `bun install` (or equivalent) if new dependencies were added

## Prompt Crafting Best Practices

### Do

- Reference spec file path — don't paste spec content into the prompt
- Reference task ID — tell them to `TaskGet` for full details
- Set explicit file boundaries to prevent conflicts
- List 3-5 non-obvious details they might miss
- Include a "when done" checklist (lint, build, commit, update task, print sentinel)
- Tell them which shared components already exist

### Don't

- Paste the entire spec into the prompt
- Give vague instructions like "implement the views"
- Let subagents modify shared files after the infrastructure phase
- Run more than 2 subagents in parallel

## Recommended Hooks for TypeScript Projects

When using worktrunk (`wt`) with TypeScript projects, configure `.config/wt.toml`:

```toml
[pre-commit]
lint = "cd <project-dir> && bun run lint"

[pre-merge]
build = "cd <project-dir> && bun run build"
```

This catches lint errors early (fast, on every commit) and type errors before merge (slower but ensures merged code compiles). Note that JSONC files (like tsconfig.json with comments/trailing commas) may trip JSON-strict lint rules — configure your linter to exclude them.

## Task List Coordination

Share the task list across all sessions via `CLAUDE_CODE_TASK_LIST_ID` env var in the subagent launch command. This lets:

- The orchestrator track progress across all phases
- Subagents read their own task details and update status on completion
- Dependencies between tasks to be respected

## Troubleshooting

- **Subagent stuck**: Read tmux pane output. If permission issue, verify `--dangerously-skip-permissions` was passed. Send follow-up messages in the same pane if needed.
- **Build fails in worktree**: `node_modules` may not be installed. Tell subagent to run the package manager install first.
- **Merge conflicts**: Shouldn't happen if file boundaries enforced. If they do, resolve manually.
- **Port conflicts after restart**: Use `ss -tlnp | grep <port>` to find the PID, then `kill <pid>`.
- **Worktree branched from wrong base**: Delete and recreate with explicit `--base` flag.
- **Corrupted branch state from failed merge**: Use `git reflog <branch>` to find the original commit, then `git reset --hard <commit>`.

## Context Overflow

If a subagent or the orchestrator itself is approaching context limits:

1. The subagent should invoke the **handoff** skill to write a `HANDOFF.md` in the worktree root
2. The subagent should print `BLOCKED: context overflow, see HANDOFF.md` and stop
3. The orchestrator launches a new subagent in the same worktree:
   ```bash
   new_pane=$(launch-agent -d <same-worktree-path> -t <task-list-id> -n "phase-N-cont")
   ```
4. Send the continuation prompt:
   ```bash
   echo 'Read HANDOFF.md and continue from where the previous agent left off. The spec is at <spec-path>.' | send-to-pane "$new_pane"
   ```
5. The new subagent should read HANDOFF.md first, verify context, then resume from the "In Progress" or "Remaining Work" section
