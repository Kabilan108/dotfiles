# The menu-host fixture shapes headless sway around missing input and parked-surface stalls

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The menu-host fixture runs MenuHost under a headless wlroots sway with two outputs. Facts it has to work around:

- The headless seat has no pointer and starts without a keyboard. A short-lived virtual keyboard per `wtype` call adds and removes the seat's keyboard capability around every keystroke.
- With no DISPLAY and a live session bus address, D-Bus can autolaunch a session whose portals mount FUSE file systems in the fixture runtime.
- A compositor sends no frame callbacks to a surface it does not show. A parked menu surface that last committed under a window (for example a fullscreen one) stops rendering, so the shown state never reaches the compositor.
- The compositor can focus the shown surface and send it keys before the surface grows.

## Decision

- Presses go through the scrim's press handler at points inside and outside the content.
- One idle `wtype -s 600000` keyboard stays up for the whole run.
- sway starts with DISPLAY unset and `DBUS_SESSION_BUS_ADDRESS` pointing at a socket that does not exist.
- The probe toplevel floats at 600,300, clear of the output's top-left corner, so the parked 1x1 menu surface stays visible and keeps getting frame callbacks, except in the deliberate fullscreen stall case.
- The fixture checks that a stalled surface is remapped within 100 ms of presenting, and that the content holds focus from present on, before it grows.

## Consequences

Tests that need pointer input cannot run on this seat. If Qt Wayland or sway change how unexposed surfaces are handled, the stall test is the first to show it.

## Where

- `packages/stillsuit-shell/src/core/MenuHost.qml` (`remapTimer`)
- `packages/stillsuit-shell/src/tests/menu-host/run.sh` (sway config, environment, wtype keyboard)
- `packages/stillsuit-shell/src/tests/menu-host/fixture-shell.qml` (`checkPresses`, `checkPresentBeforeGrowth`, `checkStalledOpen`)
