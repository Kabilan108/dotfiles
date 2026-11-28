# CDP agents profile (fallback)

A separate Helium profile, `$HELIUM_AGENTS_PROFILE`, exposes raw CDP on `127.0.0.1:${HELIUM_AGENTS_CDP_PORT:-9222}`. It has none of Tony's daily logins. Use it only when Tony asks for it.

Load the version-matched agent-browser guide first: `agent-browser skills get core`.

```bash
session="<unique-task-worker-id>"
port="${HELIUM_AGENTS_CDP_PORT:-9222}"
curl -fsS "http://127.0.0.1:${port}/json/version" || helium-agents-devtools &
agent-browser --session "$session" --cdp "$port" --pin-tab tab new --label "<short-task-name>" "<url>"
agent-browser --session "$session" --cdp "$port" tab list --json
```

- Pass `--session` and `--cdp` on every command; `--pin-tab` makes a closed tab fail instead of falling back to another agent's tab.
- Tabs are under `.data.tabs` in JSON output. Run tab creation and tab-list parsing as separate commands, so a failed parser doesn't leave an untracked tab.
- When finished, `tab close <tabId>` your own tab, then `close`. `close --all` would close other agents' tabs.

This profile is local to jacurutu: CDP has no authentication, so it is never forwarded to other hosts.
