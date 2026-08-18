---
name: helium-browser-use
description: Control a dedicated Helium browser profile through agent-browser and Chrome DevTools Protocol. Use whenever the user mentions Helium, a Helium devtools/CDP instance, the Helium agents profile, or a remote/sietch browser tunnel — prefer this over the generic agent-browser skill for those. Also use to drive the user's Helium browser locally or through an SSH-forwarded CDP endpoint, inspect browser state, open pages in a visible browser, collaborate on local or remote dev-server debugging, take screenshots, read snapshots, manage tabs, profile pages, or validate browser behavior in the Helium profile.
---

# Helium Browser Use

Use `agent-browser` against an already-running Helium CDP endpoint. Treat the browser as shared, stateful infrastructure: other agents or the user may have tabs open in the same profile.

## Start

Load the version-matched agent-browser guide before using its CLI:

```bash
agent-browser skills get core
```

Use `agent-browser skills get core --full` only when you need command reference detail beyond the common workflow.

For local Helium, default to:

```bash
port="${HELIUM_AGENTS_CDP_PORT:-9222}"
curl -fsS "http://127.0.0.1:${port}/json/version"
agent-browser --cdp "$port" get cdp-url --json
```

If CDP is not reachable, tell the user that the Helium CDP-enabled browser needs to be started. Do not launch an unrelated browser as a fallback.

## Tab Discipline

Create your own tab for navigation, form submission, destructive actions, or exploratory browsing. Inspecting an existing tab read-only is fine when the user points you at an already-open stateful page, when duplicating it would add app/server load, or when the task is to diagnose the exact visible browser state — say you're using the existing tab read-only, record its `tabId`, and don't navigate or mutate it unless asked.

Prefer labels that identify the task:

```bash
agent-browser --cdp "$port" tab new --label "<short-task-name>" "<url>"
agent-browser --cdp "$port" tab list --json
```

Track the `tabId` and label you are using. Before acting after navigation or dynamic page changes, re-check the current tab and re-snapshot. Do not close, navigate, or modify tabs you did not create unless the user specifically asks.

In JSON output, tabs are under `.data.tabs`. Run tab creation and tab-list parsing as separate commands: a tab mutation can succeed even if a chained parser fails, leaving an untracked agent-owned tab.

Avoid `agent-browser close --all` against Helium.

## Core Workflow

Use the normal agent-browser snapshot/ref loop in your own tab:

```bash
agent-browser --cdp "$port" snapshot -i
agent-browser --cdp "$port" click @e3
agent-browser --cdp "$port" snapshot -i
```

Useful read-only checks:

```bash
agent-browser --cdp "$port" get url
agent-browser --cdp "$port" get title
agent-browser --cdp "$port" console
agent-browser --cdp "$port" errors
agent-browser --cdp "$port" screenshot
```

Use a filtered CDP target listing when you need to understand what else is open without taking over those tabs. Don't print extension targets, service workers, or WebSocket debugger URLs unless the user explicitly needs them:

```bash
curl -fsS "http://127.0.0.1:${port}/json/list" \
  | jq '[.[] | select(.type == "page") | {title, url}]'
```

Agent-browser may create or focus an agent-owned `about:blank` target even when raw CDP shows other Helium tabs. That is expected. Prefer the agent-owned tab unless the user requested work in a specific existing tab.

If agent-browser reports that `/run/user/$UID/agent-browser` is read-only, request the required sandbox permission and retry. This is a local runtime-socket permission problem, not evidence that Helium or CDP is unavailable.

## State And Privacy

Assume the Helium profile exposes browser state to the agent: bookmarks, cookies, localStorage, extensions, logged-in sessions, internal browser pages, screenshots, and visible form contents may be readable or mutable.

Do not dump private data such as bookmark URLs, cookies, localStorage, account pages, or extension internals unless the user explicitly asks. Do not submit forms, change settings, delete bookmarks, or alter auth state without user intent.

## Long-Running Work And Profiling

Before profiling, tracing, or long waits, verify CDP and record the working tab (`tab --json`, `curl -m 5 .../json/version`). Use short command boundaries and save partial artifacts after each phase. After any reload, route change, or long wait, re-check the active tab and take a fresh snapshot before using refs. If CDP becomes unreachable mid-run, stop issuing page actions, diagnose the endpoint (see references/remote.md for the tunnel case), and tell the user what may still be running in the page.

## Remote Agents

When the agent is running on another machine but should control this Helium browser, read [references/remote.md](references/remote.md). The remote side should connect to a loopback-forwarded CDP port, usually `127.0.0.1:9223`.
