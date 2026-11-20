# Notification fixtures send resident notifications over D-Bus, not notify-send

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

`notify-send` closes its own notification once an action arrives. A fixture that needs a sender to stay alive after an action, as a resident notification's sender does, cannot use it.

## Decision

`send_raw_notification` calls `org.freedesktop.Notifications.Notify` directly with `gdbus` (from PATH, or built from `nixpkgs#glib.bin`), passing the actions and hints such as `resident`. Other cases keep using `notify-send`.

## Consequences

The runner needs gdbus or the ability to build it. If notify-send gains a way to stay open after an action, the raw path could go.

## Where

- `packages/stillsuit-shell/src/tests/notifications/run-fixtures.sh` (`send_raw_notification`)
