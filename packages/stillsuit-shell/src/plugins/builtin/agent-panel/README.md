# Agent panel

This built-in plugin contributes one global service and no bar item. The
service forwards the five HostContext v1 agent-panel actions. It does not
accept prompts, commands, paths, or launch settings. Niri's `Mod+Grave` binding
still calls the fixed `stillsuit-panel` `toggle` IPC method.

The source now uses the normal resident Ghostty application
`com.mitchellh.ghostty`, with the exact window title `Stillsuit Agent`.
`+new-window` forwards a fixed command attaching directly to tmux target
`=stillsuit`. Hide closes only matching windows; terminate closes those
windows and that exact session. Neither action terminates the shared Ghostty
process or unrelated terminals. Session names with similar prefixes do not match.

The helper sets tmux `set-titles off` only on this session, including an existing
session, so the fixed title remains the reliable Niri identity. Other sessions
retain their own title policy. Window map/close waits are bounded and serialized
under a lock to prevent duplicate dispatch during concurrent opens.

The user-level systemd drop-in makes normal Ghostty resident without putting
resident flags in global application settings. The matching Niri title rule
and Mod+Return forwarding command remain in the separate, unapplied
`docs/plans/stillsuit-shared-ghostty-niri.patch`. The current 60% geometry is
preserved. Deploy the helper, resident service, and Niri patch together only
after approval; this source verification does not start the resident service.

The helper reads `$XDG_CONFIG_HOME/stillsuit/agent-panel.json` when it needs to
start the agent. If `XDG_CONFIG_HOME` is unset, it reads
`$HOME/.config/stillsuit/agent-panel.json`. Lane A materializes this default:

```json
{
  "command": ["codex", "--yolo", "--model", "gpt-5.6-sol",
              "--config", "model_reasoning_effort=low", "--config", "service_tier=fast"],
  "workingDirectory": "~/dotfiles"
}
```

The file must be a regular JSON object with exactly those two keys. `command`
is an argv array of non-empty strings; each element becomes one argument to
the agent, so it is never parsed as shell. `workingDirectory` must name an
existing absolute directory after `~` expansion. Any agent can be configured
this way; the panel machinery is "one floating Ghostty window attached to the
`stillsuit` tmux session running that command, or reattach if it is already
running". An absent file uses the defaults in memory. An invalid file fails
the launch without starting anything.

The package wrapper prefixes `bash`, `coreutils`, `gnugrep`, `jq`, `niri`,
`tmux`, `util-linux`, and `ghostty` onto the helper's `PATH`; the configured
agent resolves against the session `PATH` the tmux server inherits.
Install the helper
as `bin/stillsuit-panel`, include this plugin root in the store-backed
registry, and configure the host's five agent-panel actions to execute the
helper with exactly one corresponding literal action.

The fixtures cover bounded map/close waits, concurrent forwarding, exact
app-ID/title selection, tmux title ownership, and survival of unrelated
windows, processes, and similarly named real tmux sessions.
