---
name: helium-browser-use
description: Control Helium when the task calls for an intentionally shared browser session or its saved logins.
---

# Helium Browser Use

This is a dedicated, isolated agent profile, not Tony's daily browser; drive it freely within the task.

Use `agent-browser` against an already-running Helium CDP endpoint. Treat the browser as shared, stateful infrastructure: other agents or the user may have tabs open in the same profile.

## Start

Load the version-matched agent-browser guide before using its CLI:

```bash
agent-browser skills get core
```

Use `agent-browser skills get core --full` only when you need command reference detail beyond the common workflow.

For local Helium, default to:

```bash
session="<unique-task-worker-id>"
port="${HELIUM_AGENTS_CDP_PORT:-9222}"
curl -fsS "http://127.0.0.1:${port}/json/version"
agent-browser --session "$session" --cdp "$port" --pin-tab get cdp-url --json
```

If CDP is not reachable, start the CDP-enabled agents instance yourself: run `helium-agents-devtools` in the background, then re-check `/json/version`. Do not launch an unrelated browser as a fallback.

## Tab Discipline

Use a unique task/worker session and pass both `--session` and `--cdp` on every command. Enable `--pin-tab` on the first command so a closed tab fails instead of falling back to someone else's tab. Sessions isolate active-tab selection; cookies and storage still belong to the shared profile.

Create your own tab unless the user explicitly asks you to continue in an existing tab.

Prefer labels that identify the task:

```bash
agent-browser --session "$session" --cdp "$port" tab new --label "<short-task-name>" "<url>"
agent-browser --session "$session" --cdp "$port" tab list --json
```

Track the `tabId` and label you are using. Before acting after navigation or dynamic page changes, re-check the current tab and re-snapshot. Do not close, navigate, or modify tabs you did not create unless the user specifically asks.

In JSON output, tabs are under `.data.tabs`. Run tab creation and tab-list parsing as separate commands: a tab mutation can succeed even if a chained parser fails, leaving an untracked agent-owned tab.

When finished, close only your owned tab with `tab close <tabId>`, then close your session with `close`, using the same session and CDP flags for both. Avoid `close --all` against Helium.

## Core Workflow

Use the normal agent-browser snapshot/ref loop in your own tab:

```bash
agent-browser --session "$session" --cdp "$port" snapshot -i
agent-browser --session "$session" --cdp "$port" click @e3
agent-browser --session "$session" --cdp "$port" snapshot -i
```

Useful read-only checks:

```bash
agent-browser --session "$session" --cdp "$port" get url
agent-browser --session "$session" --cdp "$port" get title
agent-browser --session "$session" --cdp "$port" console
agent-browser --session "$session" --cdp "$port" errors
agent-browser --session "$session" --cdp "$port" screenshot
```

Use raw CDP target listing when you need to understand what else is open without taking over those tabs:

```bash
curl -fsS "http://127.0.0.1:${port}/json/list"
```

Agent-browser may create or focus an agent-owned `about:blank` target even when raw CDP shows other Helium tabs. That is expected. Prefer the agent-owned tab unless the user requested work in a specific existing tab.

If agent-browser reports that `/run/user/$UID/agent-browser` is read-only, request the required sandbox permission and retry. This is a local runtime-socket permission problem, not evidence that Helium or CDP is unavailable.

## State And Privacy

Assume the Helium profile exposes browser state to the agent: bookmarks, cookies, localStorage, extensions, logged-in sessions, internal browser pages, screenshots, and visible form contents may be readable or mutable.

Do not dump private data such as bookmark URLs, cookies, localStorage, account pages, or extension internals unless the user explicitly asks. Do not submit forms, change settings, delete bookmarks, or alter auth state without user intent.

## Remote Agents

When remote control of this Helium browser is explicitly needed, read [references/remote.md](references/remote.md). The remote side should connect to a loopback-forwarded CDP port, usually `127.0.0.1:9223`.
