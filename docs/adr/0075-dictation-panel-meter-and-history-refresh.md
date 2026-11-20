# Dictation panel meters only when open and refreshes history after idle

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The dictation panel is `keepLoaded`, so an instance exists on every output.
A finished recording lands in the transcript history only after the daemon
returns to idle.

## Decision

Only the opened panel binds to the Dictator level meter and scan position;
hidden panels read empty values and do no work per scan tick. The service
restarts its history refresh timer when the state moves from non-idle to idle
or error.

## Consequences

A panel that shows the meter must set `opened`.

## Where

- `packages/stillsuit-shell/src/plugins/builtin/dictation/Panel.qml` (`levels`, `scanPos`)
- `packages/stillsuit-shell/src/plugins/builtin/dictation/Service.qml` (`onStateChanged`)
