---
name: codex-computer-use
description: Ask Codex CLI (gpt-5.6) to run local app verification that needs browser automation, desktop control, screenshots, app launching, or independent runtime inspection. This is how gpt-5.6 is invoked for computer-use work, and the preferred route for browser verification on this machine. Use when the user asks to test a flow, verify UI behavior, inspect a running app, capture screenshots, or report confirmation and feedback about implemented behavior.
---

# Codex Computer Use

Use Codex as a separate local verification agent when the task needs real UI interaction, screenshots, browser or desktop state, or an independent runtime check outside the current agent's context. On this machine, gpt-5.6 via `codex exec` is the preferred agent for browser-use tasks — reach for it before spawning Claude browser subagents.

Do not use this for ordinary code reading, typechecking, linting, or tests the current agent can run directly. Launching apps or browsers to verify requested work is fine without asking; ask first only if the run could disrupt the user's environment beyond that, such as closing their apps, changing system settings, or acting on real accounts or data.

## Local Tooling

Codex has the shared skills from this machine's skills root — route it to the right one in the prompt:

- **Browser work**: tell Codex to load the `helium-browser-use` skill and connect to the running Helium CDP endpoint (`${HELIUM_AGENTS_CDP_PORT:-9222}`). It must open its own labeled tab and never run `close --all`. If the CDP endpoint is not reachable, launch the CDP-enabled agents instance with `helium-agents-devtools` (run in the background, then re-check `/json/version`) rather than falling back to another browser.
- **Desktop / native app verification**: tell Codex to load the `niri-computer-use` skill and use its `acu` CLI (`acu doctor`, `acu state`, `acu shot`, `acu focus/click/type/key`, plus raw `niri msg`) and prefer compositor-native inspection and navigation before synthetic input.

Codex's computer-use features are not reliably available on Linux — prefer the skills above where they fit the task.

## Workflow

1. Identify the user-visible behavior to verify and the local app URL, command, or browser target.
2. Start the app or confirm the user already has it running.
3. Create a temporary artifact directory for Codex's report, log, and screenshots.
4. Run `codex exec` with a self-contained verification prompt.
5. Read Codex's report and inspect attached screenshots or logs when available.
6. Confirm the important claims yourself when practical before reporting the result.

Use this command shape:

```bash
ARTIFACT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codex-computer-use.XXXXXX")"
REPORT="$ARTIFACT_DIR/report.md"
PROMPT="$ARTIFACT_DIR/prompt.md"
LOG="$ARTIFACT_DIR/codex.log"
```

```bash
codex exec -C "$PWD" -s workspace-write \
  -c sandbox_workspace_write.network_access=true \
  -c model_reasoning_effort=medium \
  -o "$REPORT" - < "$PROMPT" > "$LOG" 2>&1
```

`network_access=true` is required under `workspace-write` — without it Codex cannot reach the CDP endpoint or a local dev server. Always pass `-s` and effort explicitly; the config defaults are `danger-full-access` and `high`.

Pick effort by task shape:

- `medium`: well-defined tasks — a known workflow with concrete steps and pass/fail criteria
- `high` or `xhigh`: exploration — open-ended debugging, unfamiliar UI, or "poke around and tell me what's broken"

Use `-s read-only` when Codex only needs to inspect a running app and save nothing.

Verification flows are slow — launch in a detached tmux session (`tmux new-session -d -s codex-cu-$$ "codex exec ... > \"$LOG\" 2>&1"`) rather than Bash `run_in_background`, so the run survives a Claude session restart; the final message lands in `$REPORT` via `-o` only on clean completion, so wait on that file, not the tmux session.

## Verification Prompt

Keep the prompt operational. Name the skill Codex should load, give exact steps with pass/fail criteria, and set screenshot paths under the artifact directory:

```text
Load the <helium-browser-use | niri-computer-use> skill first, then verify the requested UI/runtime behavior.

Target:
- URL or app command: <target>
- starting state: <state>
- credentials or test data: <only safe, explicit test data>

Checks:
- <behavior to verify>
- <states to inspect>
- save screenshots to <ARTIFACT_DIR>/<name>.png

Boundaries:
- do not act on real accounts or data unless explicitly instructed
- perform outward-facing actions (submit, send, post) at most once, and only when explicitly instructed
- do not change unrelated settings
- do not close or modify tabs you did not create
- do not commit or edit source files

Report:
- steps performed
- screenshots or artifacts created
- observed behavior
- pass/fail verdict
- issues, uncertainty, or follow-up checks
```

## Follow-ups

To steer a run or ask for another check against the same browser/desktop state, resume the session. Codex prints a `session id:` line in its output frontmatter — resuming by id keeps follow-ups pinned to this run even if other Codex sessions ran in between:

```bash
SESSION_ID="$(sed -n 's/^session id: //p' "$LOG" | head -1)"
codex exec resume "$SESSION_ID" -o "$REPORT" "<correction or next check>"
```

## Reporting Back

Separate observed behavior from inferred causes. Include artifact paths for screenshots or logs that Codex captured.

If Codex could not launch or inspect the target app, report the exact blocker and continue with any direct verification the current agent can perform.
