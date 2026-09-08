---
name: tmux
description: Run persistent development servers or durable shell workers/jobs/scripts, and inspect or send input to an explicitly identified tmux pane.
---

# Tmux

Use ordinary harness process tools when a one-shot command needs no persistence. For durable batch agent work use `agent-run --help`; it records completion and exit status. For interactive agent panes use `launch-agent --help`. These are different launch contracts.

Use explicit targets (`%31`, `session:window.pane`) and record which processes this task owns. Send prompts or multiline text with `send-to-pane -t <target> <file>`; never interpolate a prompt into a shell command or raw send-keys call. Inspect a pane with `tmux capture-pane -p -t <target>`; add `-S -` only when history is needed.

A detached tmux worker survives a coordinator restart but does not wake it. After `agent-run start`, attach `agent-run wait <id> --timeout 0` to the harness's supported background/wait mechanism before doing other work. Retain its handle. A timeout is not completion. After a restart run `agent-run reconcile --repo <repo>` and reattach waits before launching replacements.

Read the result and inspect the diff/verification before `agent-run acknowledge <id>`. File existence and text visible in scrollback do not prove successful exit. `agent-run status` reports worker exit separately from result consumption.

For other persistent processes, use a named detached session/window and capture its logs and exit status. Reconnect to task-owned processes before starting duplicates. Stop only processes covered by the task's cleanup scope; do not terminate the user's terminal or coordinator.
