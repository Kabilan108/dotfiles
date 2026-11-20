# Launcher model test notes

- Put per-keystroke budget changes in `qml-load-fixture.qml`, not `perf.test.js`. Production runs the model under Quickshell's QML engine (V4), and node's JIT is far faster, so the node test's 8 ms median and 16 ms p95 only catch gross regressions.
- Keep `measure` in `qml-load-fixture.qml` timing every prefix of each word for three rounds and rounding figures down to whole milliseconds. `Date.now()` has 1 ms resolution in V4, so single timings and fractions carry no information.
- Do not read the 1,500-app `prepare_ms` that `qml-load-fixture.qml` logs as the cost of preparing that catalog. It runs after the 400-app catalog in the same process, so it includes V4 growing its heap; a fresh process prepares 1,500 apps in about 150 ms.
- Keep `syntax.test.js` running each model file as a classic script with no `module` or `require` in scope and allowing only the guarded `module.exports`. Quickshell loads these files as classic scripts with no module system, and V4 lacks some modern syntax that node accepts.
