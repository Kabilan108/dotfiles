# Bar keeps widget slots stable and routes presses around widgets

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The bar draws one window per output and fills three sections with widget
slots. `ScriptModel` requires unique values. Recreating a slot destroys its
widget and that widget's state. A press on empty bar space should dismiss open
panels, but a press on a widget should not.

## Decision

The host supplies `Quickshell.screens` as `outputScreens`; it stays the only
source of output objects, and the bar reads no host globals.
`registrationsFor(section)` collapses the same registration object listed
twice into one slot, since the host hands out one record per plugin. Section
lists are computed once per registration change instead of per output, and
`ScriptModel` diffs them so an unchanged registration keeps its slot and
widget.

The full-bar `MouseArea` sits under the widgets, so widgets receive their own
presses first. A press that reaches it inside a visible widget's slot (a
disabled widget or an unhandled button) does nothing; anywhere else it calls
`surfaceDismissPanels()`.

## Consequences

Registration identity must stay stable for unchanged plugins, as
`host-contract.md` requires, or every change recreates widgets.

## Where

- `packages/stillsuit-shell/src/plugins/builtin/bar/Bar.qml` (`outputScreens`, `registrationsFor`, `leftRegistrations`, `stillsuit-bar-dismiss` `handlePress`)
