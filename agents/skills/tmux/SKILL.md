---
name: tmux
description: Manage concurrent processes using tmux. Use when running servers, long tasks, or orchestrating multiple agents in separate panes. Essential for sending multi-line text or instructions to other tmux panes safely.
allowed-tools:
  - Bash
---

# Tmux Skill

This skill empowers you to manage multiple concurrent processes (like servers, watchers, or long builds) using `tmux` directly from the `Bash` tool.

Since you are likely already running inside a tmux session, you can spawn new windows or panes to handle these tasks without blocking your main communication channel.

## 1. Verify Environment & Check Status

First, verify you are running inside tmux:

```bash
echo $TMUX
```

If this returns empty, you are not running inside tmux. Use explicit tmux targets such as `session:window.pane` with the helper scripts.

Once verified, check your current windows:

```bash
tmux list-windows
```

If you are outside tmux but need to operate on an existing session, use the helper scripts with explicit tmux targets:

```bash
tmux list-sessions
tmux list-windows -t "session-name"
pane=$(launch-agent -a codex -t "session-name:window-name" -d /repo -- exec --help)
send-to-pane -t "session-name:window-name.pane" /tmp/prompt.txt
poll-agents -t "$pane"
```

Before launching an interactive agent or other long-running CLI in a pane, check the installed CLI's `--help` output in the environment where it will run — for Codex, check both `codex --help` and the specific subcommand (`codex exec --help`, `codex exec review --help`). Agent CLI flags change over time, and a rejected flag can leave the pane in a failed or idle state while the orchestrator keeps waiting.

## 2. Spawn a Background Process

To run a command (e.g., a dev server) in a way that persists and can be inspected:

1.  **Create a new detached window** with a specific name. This keeps it isolated and easy to reference.

    ```bash
    tmux new-window -n "server-log" -d
    ```

    _(Replace "server-log" with a relevant name for your task)_

2.  **Send the command** to that window.
    ```bash
    tmux send-keys -t "server-log" "npm start" C-m
    ```
    _(`C-m` simulates the Enter key)_

## 3. Sending Text to Panes

**Warning**: `send-keys` interprets control sequences. Multi-line text or text with special characters can trigger tmux modes (like `C-r` for search). Use the right method:

| Content Type | Method |
|--------------|--------|
| Simple shell command | `send-keys "cmd" C-m` |
| Single line, may have special chars | `send-keys -l "text"` then `send-keys C-m` |
| Multi-line text or instructions | `send-to-pane -t <target> <file>` |

**Literal mode** (`-l` flag) prevents interpreting escape sequences:

```bash
tmux send-keys -l -t "target" "text with C-r and other chars"
tmux send-keys -t "target" C-m
```

**Multi-line content** — use `send-to-pane`, which wraps `load-buffer` safely:

```bash
cat > /tmp/msg.txt << 'EOF'
Your multi-line content here.
Can include any characters safely.
EOF
send-to-pane -t "target" /tmp/msg.txt
```

## 4. Interacting with Other Agents

When sending instructions to an existing interactive agent pane, inspect it first, send, then verify receipt:

```bash
tmux capture-pane -p -S -80 -t %31
cat > /tmp/instructions.txt << 'EOF'
Fix the authentication bug in src/auth.ts:
1. The token validation is missing null checks
2. Add proper error handling for expired tokens
When done, write findings to /tmp/review.md and say the review file is ready.
EOF
send-to-pane -t %31 /tmp/instructions.txt
tmux capture-pane -p -S -80 -t %31
```

Never use `send-keys` directly for prompts or instructions — the text will likely contain characters that trigger tmux modes. Use `send-keys -l ... C-m` only for a single shell command you want the shell to execute.

Ask peer agents to write results to a file rather than relying on reading their pane — scrollback is finite and long responses get truncated.

## 5. Helper Scripts

For orchestration workflows, prefer these scripts over raw tmux commands:

| Task | Script | Example |
|------|--------|---------|
| Send text to pane | `send-to-pane` | `echo "cmd" \| send-to-pane -t %31` |
| Send file to pane | `send-to-pane` | `send-to-pane -t atlas:review.1 /tmp/prompt.txt` |
| Launch agent pane | `launch-agent` | `pane=$(launch-agent -a codex -t atlas:review -d /path)` |
| Monitor panes | `poll-agents` | `poll-agents -p -t %31 -t atlas:review.2` |

These wrap the tmux boilerplate (temp files, load-buffer, paste-buffer) into single commands. Before relying on them in a new shell or remote host, preflight them — don't assume older flag shapes:

```bash
command -v send-to-pane launch-agent poll-agents
send-to-pane --help
launch-agent --help
poll-agents --help
```

Prefer tmux-native targets (`%31`, `atlas:review`, `atlas:review.2`) over separate session/window flags. The raw tmux commands in the sections below remain useful for understanding what the scripts do and for ad-hoc operations.

When using `poll-agents`, choose a completion sentinel that does not appear literally in the command line or prompt visible in pane scrollback. For example, ask the agent to output "the words PHASE and COMPLETE separated by one space" instead of embedding `PHASE COMPLETE` directly in the prompt.

## 6. Inspect Output (Read Logs)

You can read the output of that pane at any time without switching your context.

**Get the current visible screen:**

```bash
tmux capture-pane -p -t "server-log"
```

**Get the entire history (scrollback):**

```bash
tmux capture-pane -p -S - -t "server-log"
```

_Use this if the output might have scrolled off the screen. It's still limited by the pane's configured history — for long jobs, tee output to a log file and read that instead:_

```bash
tmux new-window -n "job" -d
tmux send-keys -t "job" "long-command 2>&1 | tee /tmp/job.log" C-m
tail -n 80 /tmp/job.log
```

_After launching a long job, verify it actually started (capture the pane or tail the log) before reporting it as running — a bad flag or existing-output error can kill it immediately._

## 7. Interact with the Process

If you need to stop or restart the process:

**Send Ctrl+C (Interrupt):**

```bash
tmux send-keys -t "server-log" C-c
```

**Kill the window (Clean up):**

```bash
tmux kill-window -t "server-log"
```

## 8. Remote tmux over SSH

For jobs in a tmux session on another host, keep the target session/window, log path, and command explicit:

```bash
ssh sietch 'tmux has-session -t jobs'
ssh sietch 'tmux new-window -d -t jobs -n batch-name "bash -lc '\''cd /repo && long-command 2>&1 | tee /tmp/batch-name.log'\''"'
ssh sietch 'tmux capture-pane -p -S -80 -t jobs:batch-name'
ssh sietch 'tail -n 80 /tmp/batch-name.log'
```

If the quoting becomes hard to read, write a script on the remote host and launch that from tmux instead.

## 9. Advanced: Chaining Commands

You can chain multiple tmux commands in a single invocation using `';'` (note the quotes to avoid interpretation by the shell). This is faster and cleaner than running multiple `tmux` commands.

Example: Create window and start process in one go:

```bash
tmux new-window -n "server-log" -d ';' send-keys -t "server-log" "npm start" C-m
```

## Quick Reference

| Task | Command |
|------|---------|
| Create window | `tmux new-window -n "ID" -d` |
| Run command | `tmux send-keys -t "ID" "cmd" C-m` |
| Send literal text | `tmux send-keys -l -t "ID" "text"` |
| Send multi-line | `send-to-pane -t "ID" file` |
| Read output | `tmux capture-pane -p -t "ID"` |
| Interrupt | `tmux send-keys -t "ID" C-c` |
| Kill window | `tmux kill-window -t "ID"` |
| **Send to pane** | `echo "text" \| send-to-pane -t %ID` |
| **Launch agent** | `pane=$(launch-agent -a codex -t atlas:review -d /path)` |
| **Poll agents** | `poll-agents -p -t %ID1 -t %ID2` |
