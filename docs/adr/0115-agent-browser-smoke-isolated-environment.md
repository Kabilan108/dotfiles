# agent-browser-smoke runs with a scrubbed browser environment

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

`bin/agent-browser-smoke` exercises the installed headless browser without shared profiles or accounts. `AGENT_BROWSER_*` variables can turn on auto-connect, auth restoration or a shared profile, and `DISPLAY`/`WAYLAND_DISPLAY` would attach it to the desktop.

## Decision

The smoke test drops every `AGENT_BROWSER_*` variable and both display variables from its environment, then sets only the configured executable.

## Consequences

A new `AGENT_BROWSER_*` setting never leaks into the smoke run; one the test needs must be set explicitly.

## Where

- `bin/agent-browser-smoke` (the `env` built in `main`)
