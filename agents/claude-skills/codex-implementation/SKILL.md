---
name: codex-implementation
description: Ask Codex CLI (gpt-5.5) to implement scoped code changes in the current repository, then have the current agent inspect the resulting diff and verification. This is how gpt-5.5 is invoked for implementation work. Use when the user asks to delegate implementation to Codex or gpt-5.5, when the model-selection rubric routes the work to gpt-5.5, or when a bounded task would benefit from another coding agent producing a patch.
---

# Codex Implementation

Use Codex as a separate implementation agent for bounded code changes. The current agent remains responsible for scoping the task, reviewing the diff, running or checking verification, and explaining the final result.

Use this when the user asks for Codex or delegation, or when a bounded task would benefit from a parallel implementation agent producing a patch. Do not let Codex commit, push, deploy, or edit global config unless the user explicitly asked for that.

## Workflow

1. Pin the current state with `git status --short` and note any user changes already present.
2. Define the implementation scope: files or behavior to change, files to avoid, constraints, and verification commands.
3. Create a temporary artifact directory for Codex's report and log.
4. Run `codex exec` with repo write access, capturing the full output to the log.
5. After Codex exits, inspect `git status` and `git diff`.
6. Run the cheapest reliable verification yourself when practical.
7. Report what Codex changed, what the current agent verified, and any remaining risks.

Use this command shape:

```bash
ARTIFACT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codex-implementation.XXXXXX")"
REPORT="$ARTIFACT_DIR/report.md"
PROMPT="$ARTIFACT_DIR/prompt.md"
LOG="$ARTIFACT_DIR/codex.log"
```

```bash
codex exec -C "$PWD" -s workspace-write -c model_reasoning_effort=medium \
  -o "$REPORT" - < "$PROMPT" > "$LOG" 2>&1
```

Always pass `-s` and `-c model_reasoning_effort` explicitly. `~/.codex/config.toml` defaults to `danger-full-access` and `high` effort, so an invocation that omits them runs unsandboxed and over-thinks.

Pick effort by task shape:

- `low`: mechanical grunt work (renames, format fixes, boilerplate)
- `medium`: clear-spec implementation — the default
- `high`: genuinely hard bounded problems, or a redo after `medium` missed the bar

Add `-c sandbox_workspace_write.network_access=true` when the task needs network inside the sandbox (package installs, fetching dependencies).

For runs expected to exceed a couple of minutes, do NOT tie the run to the Claude process with Bash `run_in_background` — background children die with the Claude session, and a restart orphans a half-applied change. Launch in a detached tmux session so the run survives harness restarts:

```bash
tmux new-session -d -s "codex-impl-$$" \
  "codex exec -C \"$PWD\" -s workspace-write -c model_reasoning_effort=medium \
   -o \"$REPORT\" - < \"$PROMPT\" > \"$LOG\" 2>&1"
```

The final message lands in `$REPORT` via `-o`, and only on clean completion — wait on that file (background until-loop), not on the tmux session. If the tmux session has exited but `$REPORT` is missing, the run was interrupted: inspect `$LOG` and `git status`/`git diff` for partial changes before rerunning. Abort with `tmux kill-session -t <name>`.

Use `-s danger-full-access` only when the requested task truly needs unrestricted local access and the user has already authorized that class of work.

## Implementation Prompt

Codex already loads the global `AGENTS.md` (comment policy, language preferences, uv/bun conventions), so include only project-specific constraints — do not restate global conventions.

Keep the prompt direct and self-contained:

```text
Implement the scoped change below in this repository.

Scope:
- <files or behavior to change>
- <files or areas to avoid>

Constraints:
- preserve existing user changes
- keep the change narrowly focused
- do not commit, push, deploy, or edit global config

Verification:
- run <command> if practical
- if verification cannot run, explain why

Report:
- files changed
- behavioral summary
- verification run and result
- anything blocked or uncertain
```

Include relevant requirements, failure examples, screenshots, logs, or test names. Avoid long conversational framing; Codex responds better to a concrete task and constraints.

## Follow-ups and Steering

Codex prints a `session id:` line in its output frontmatter. Extract it from the log — resuming by id keeps follow-ups pinned to this run even if other Codex sessions ran in between:

```bash
SESSION_ID="$(sed -n 's/^session id: //p' "$LOG" | head -1)"
```

Send corrections or next steps to the same session instead of starting a cold run:

```bash
codex exec resume "$SESSION_ID" -o "$REPORT" "<correction or next step>"
```

## Review After Codex

Always inspect Codex's diff before telling the user the work is done. Revert only Codex-created mistakes when you are sure they are not user changes.

If Codex leaves the repo in a worse state or changes unrelated files, stop and report the issue with the diff summary.

If `codex` is not installed or the command fails, report the error and offer to implement the change directly instead.
