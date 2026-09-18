---
name: agent-browser
description: Use agent-browser for isolated headless browsing when no suitable integrated browser is available, or for Electron and other CDP targets.
allowed-tools: Bash(agent-browser:*), Bash(npx agent-browser:*)
---

Run `agent-browser` for instructions; load `agent-browser skills get core` for its version-matched workflow guide.

Use a unique task/worker session for background browsing, reuse it across commands, and close only that session when finished.

For shared CDP browsers, use your own tab with `--pin-tab` and repeat `--session` and `--cdp` on every command. Close only your owned tabs. Follow helium-browser-use for Helium.
