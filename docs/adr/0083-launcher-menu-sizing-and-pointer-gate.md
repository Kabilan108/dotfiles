# Launcher menu narrows short lists and ignores a resting pointer

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The power and profiles views list a handful of rows; at the standard width the
frame reads as mostly empty space. The menu appears centered on the output, so
a pointer already resting there would select a row as soon as rows appear.

## Decision

Power and profiles use `compactWidth`. On open the menu resets `pointerGate`,
and a hovered row is only selected once the pointer has actually moved.

## Consequences

New short single-purpose views should join `compactView`.

## Where

- `packages/stillsuit-shell/src/plugins/builtin/launcher/Menu.qml` (`compactView`, `open`, `pointerGate`)
