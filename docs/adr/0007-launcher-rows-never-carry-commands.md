---
paths:
  - packages/stillsuit-shell/src/plugins/builtin/launcher/model/Engine.js
  - packages/stillsuit-shell/src/plugins/builtin/launcher/Service.qml
---

# Launcher providers return validated intents and only the service executes them

Launcher rows pass through QML models, which copy them and let fields be edited, and they end in app launches, window focus, session actions and URL opens. Providers therefore never return a command line: the engine's `activate` returns an intent whose type and fields are listed in `INTENT_FIELDS`, or null, and `packages/stillsuit-shell/src/plugins/builtin/launcher/Service.qml` is the only place that turns an intent into a process or IPC call. Letting each provider build its own command was simpler, but it would have made every provider and every row field part of the execution surface.

## Consequences

A new action needs an intent type in `INTENT_FIELDS` and a handler in the service before any provider can return it.
