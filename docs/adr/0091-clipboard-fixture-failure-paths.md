# Clipboard fixtures run real collector paths under the service PATH and forced write failures

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

`wl-paste` and `wl-copy` exec `cat`. A collector wrapper whose PATH lacks coreutils loses every capture and re-copy under the service's exact PATH, while a full developer PATH hides the fault. The QML fixture fails history saves by making the state directory read-only, and the collector's `gc` would tighten that directory's mode again.

## Decision

When `STILLSUIT_CLIPBOARD_COLLECTOR` names a built wrapper, `e2e-headless.sh` runs it under `env -i` with a PATH holding only wl-clipboard, and fails if that directory contains `cat`, since the check would then prove nothing. The durable fixture instance replaces `gc` with a no-op so it cannot undo the read-only directory; the gc-gate instance records each gc call instead.

## Consequences

The wrapper must keep coreutils in its PATH. Fixture instances that force write failures must not run the real gc.

## Where

- `packages/stillsuit-shell/src/tests/clipboard/e2e-headless.sh` (minimal PATH block)
- `packages/stillsuit-shell/src/tests/clipboard/run-qml-fixture.sh` (durable and gc-gate instances)
