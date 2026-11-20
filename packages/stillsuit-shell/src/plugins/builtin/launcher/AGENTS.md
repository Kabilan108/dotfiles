# Launcher notes

## Engine and service

- Keep the files under `model` free of imports of each other; `Service.qml` imports every module and passes them to the engine's `create`. QML JavaScript files cannot require() one another, and the node tests in `packages/stillsuit-shell/src/tests/launcher` load the same files.
- Do not rely on a frozen row staying unchanged in QML. V4 lets push() and index writes through on frozen arrays, and QML models copy rows, so `activate` matches a row by key and generation and acts on the engine's private snapshot.
- When adding a timer or process to `Service.qml`, stop it on close and add it to `pendingWork`. The launcher service lives for the whole session and must do no work while closed, and the fixtures assert `pendingWork` is false after close. The debounced history write is the one exception.
- Keep the immediate rerun for the first app scan (`_apps` empty) in the DesktopEntries handler. On a fresh process that scan can land while the menu already shows an empty list; later rescans go through the `appsTimer` debounce.
- Capture the current window in `open`, before the menu surface takes focus, and do not read niri's focus flags later. While a layer surface holds keyboard focus niri flags no window as focused, and it debounces focus_timestamp updates, so the newest stamp can still name the previous window. If niri starts flagging focus under layer surfaces and stops debouncing stamps, the capture can shrink to reading is_focused.
- Keep `-u8` and `--` in the qalc command. `-u8` switches qalc's Unicode output off, so a copied "-2" pastes as ASCII instead of U+2212; `--` ends options, so input such as "-v" stays an expression.

## Matching and ranking

- Keep the matcher's scratch buffers plain arrays (`zeroes` in `model/Matcher.js`). Element access on typed arrays is about ten times slower in QML's V4 engine, and the perf test runs under node, so it will not catch the regression.
- When changing a bonus or penalty constant in `model/Matcher.js`, recheck the pruning in `score`. It skips fields using ceilings derived from those constants: penalties only grow with the field index, and every non-zero bonus is at least BONUS_CAMEL_123.
- Keep `leadingRows` in `model/Engine.js` in place of a plain sort. A full comparator sort of a 1,500-row result costs about 15,000 JS calls in V4, and V4's Array sort is not stable, which is why `rowsAt` breaks ties by input index. A plain stable sort gives the same rows, only slower.
- Credit Elephant (abenz1267/elephant, GPL-3.0) when touching the usage boost. `model/History.js` reimplements its CalcUsageScore formula with two differences: related stored queries contribute their best per-record boost instead of a summed count, and the length difference divides as (1 + delta), so results do not depend on map iteration order. `model/providers/apps.js` takes its field order and MIN_SCORE of 30 from Elephant's desktopapplications provider.

## Rows

- Keep `activate` in `model/Engine.js` validating a row against the engine's own snapshot. V4 lets `push()` and index writes through on a frozen array, unlike node, so the deeply frozen row copies alone do not stop a caller from mutating a row. `packages/stillsuit-shell/src/tests/launcher/qml-load-fixture.qml` checks this under V4.
- Give every non-app row an icon named `shell:<name>` with a glyph in `packages/stillsuit-shell/src/ui/icons`. Icon themes that ship only symbolic names cannot resolve the freedesktop names for power, profile, clipboard and similar rows, and the lookup falls back to a letter monogram. App and window rows keep theme icons.
