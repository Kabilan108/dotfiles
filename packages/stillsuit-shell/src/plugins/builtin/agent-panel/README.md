# Agent panel

This built-in plugin contributes one global service and no bar item. The
service forwards the five HostContext v1 agent-panel actions. It does not
accept prompts, commands, paths, or launch settings. Niri's `Mod+Grave` binding
still calls the fixed `stillsuit-agent-panel` `toggle` IPC method.

The source now uses the normal resident Ghostty application
`com.mitchellh.ghostty`, with the exact window title `Stillsuit Agent`.
`+new-window` forwards a fixed command attaching directly to tmux target
`=stillsuit-agent`. Hide closes only matching windows; terminate closes those
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

The fixtures cover bounded map/close waits, concurrent forwarding, exact
app-ID/title selection, tmux title ownership, and survival of unrelated
windows, processes, and similarly named real tmux sessions.
