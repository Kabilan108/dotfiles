# Agent panel

This built-in plugin contributes one global service and one bar widget per
output. The service forwards the five HostContext v1 agent-panel actions. It
does not accept prompts, commands, paths, or launch settings.

`stillsuit-agent-panel` owns the `stillsuit-agent` tmux session and the exact
Ghostty app ID `io.stillsuit.AgentPanel`. The first open starts a custom
single-instance Ghostty process whose direct default command attaches to the
exact tmux target `=stillsuit-agent`. Hide closes the terminal surface but
leaves both Ghostty and tmux running. Reopen asks that exact Ghostty instance
for a new window, avoiding another process and GTK startup. Hide never ends
either process. `terminate` ends both, while stale-session recovery replaces
them as needed. New sessions start in `$HOME`; neither IPC nor helper arguments
can choose a working directory. A session such as `stillsuit-agent-extra` is
never treated as the panel session.

Niri does not provide a hidden-window or scratchpad action, and the packaged
Ghostty does not expose its quick-terminal toggle as an external command.
Reopen must still create and map a new terminal surface. The helper waits up to
five seconds for that surface to appear before releasing its lock, so concurrent
opens cannot request duplicate windows.

Hide waits up to five seconds for the exact Niri window IDs to disappear.
Terminate and stale-session replacement also wait up to five seconds for the
recorded Ghostty PID to exit. The helper sends TERM only while that PID's argv
contains `--class=io.stillsuit.AgentPanel`. A timeout fails the action with exit
75 and does not launch another Ghostty over the old one.

The helper reads `$XDG_CONFIG_HOME/stillsuit/agent-panel.json` when it needs to
start Codex. If `XDG_CONFIG_HOME` is unset, it reads
`$HOME/.config/stillsuit/agent-panel.json`. Lane A must materialize this default:

```json
{
  "model": "gpt-5.6-sol",
  "reasoningEffort": "low",
  "serviceTier": "fast"
}
```

The file must be a regular JSON file with exactly those three string keys.
Allowed models are `gpt-5.6-sol`, `gpt-5.6-terra`, and `gpt-5.6-luna`.
Allowed efforts are `low`, `medium`, `high`, `xhigh`, `max`, and `ultra`.
Allowed service tiers are `fast` and `priority`. An absent file uses the same
defaults in memory. An invalid file fails the launch without starting Codex.

The package wrapper must put `bash`, `coreutils`, `gnugrep`, `jq`, `niri`,
`tmux`, `util-linux`, `ghostty`, and `codex` on the helper's runtime `PATH`.
`bash` runs the script and `flock` comes from `util-linux`; the remaining
commands are invoked by name. Install the helper
as `bin/stillsuit-agent-panel`, include this plugin root in the store-backed
registry, and configure the host's five agent-panel actions to execute the
helper with exactly one corresponding literal action.

The fixture suite uses delayed fake Niri maps and delayed Niri and Ghostty exits
to check the wait barriers. It verifies that hide and concurrent reopen reuse
one Ghostty process without duplicate window requests. It also starts real tmux
sessions on a temporary socket and confirms that a lone
`stillsuit-agent-extra` session is ignored and survives panel termination.
