# Launcher model checks run under QML V4, with node limits only catching gross regressions

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The launcher model files run in production under Quickshell's QML engine (V4), loaded as classic scripts with no module system. V4 lacks some modern syntax and, unlike node, lets `push()` and index writes through on a frozen array. Node's JIT is far faster than V4, so timings measured in node say little about per-keystroke cost in the shell. In V4, `Date.now()` has 1 ms resolution, and a later, larger catalog's `prepare_ms` includes V4 growing its heap; a fresh process prepares 1,500 apps in about 150 ms.

## Decision

- `syntax.test.js` rejects syntax V4 lacks and any module plumbing other than the guarded `module.exports`, and runs each file as a classic script with no `module` or `require` in scope.
- `perf.test.js` uses a loose 8 ms median budget (16 ms p95) only to catch gross regressions.
- `qml-load-fixture.qml`, run by `qml-load.sh`, loads every model file in V4 and asserts the real per-keystroke budgets at 400 and 1,500 apps, timing every prefix of each word for three rounds and rounding each figure down to a whole ms.
- The engine returns deeply frozen row copies, and the V4 fixture checks that a row mutated through `push()` is still refused by `activate()`.

## Consequences

Budget changes belong in the QML fixture, not the node test. The QML check needs quickshell on PATH; `STILLSUIT_LAUNCHER_REQUIRE_QML=1` makes its absence fail (see `docs/testing.md`). Activation must keep validating rows against the engine's own snapshot, since freezing alone does not stop mutation in V4.

## Where

- `packages/stillsuit-shell/src/tests/launcher/syntax.test.js`
- `packages/stillsuit-shell/src/tests/launcher/perf.test.js` (`BUDGET_MS`)
- `packages/stillsuit-shell/src/tests/launcher/qml-load-fixture.qml` (`measure`, frozen row check)
- `packages/stillsuit-shell/src/tests/launcher/qml-load.sh`
- `packages/stillsuit-shell/src/plugins/builtin/launcher/model/Engine.js` (`plainCopy`, `activate`)
