# Agent panel

This built-in plugin contributes one global service and one bar widget per
output. The service forwards the five HostContext v1 agent-panel actions. It
does not accept prompts, commands, paths, or launch settings.

`stillsuit-agent-panel` owns the `stillsuit-agent` tmux session and the exact
Ghostty app ID `io.stillsuit.AgentPanel`. Closing the window leaves tmux and
Codex running. Only `terminate` ends the session. New sessions start in
`$HOME`; neither IPC nor helper arguments can choose a working directory.
Tmux lookups and mutations use the exact target `=stillsuit-agent`, so a session
such as `stillsuit-agent-extra` is never treated as the panel session.

Hide and replacement actions wait up to five seconds for the exact Niri window
IDs and recorded Ghostty PID to disappear. The helper sends TERM to that PID
only while its argv contains `--class=io.stillsuit.AgentPanel`. A timeout fails
the action with exit 75 and does not launch another Ghostty over the old one.

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

The fixture suite uses delayed fake Niri and Ghostty exits to check the wait
barriers. It also starts real tmux sessions on a temporary socket and confirms
that a lone `stillsuit-agent-extra` session is ignored and survives panel
termination.
