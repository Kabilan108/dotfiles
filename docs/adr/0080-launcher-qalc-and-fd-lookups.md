# Launcher gates and shapes its qalc and fd lookups

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The calculator and file providers shell out to qalc and fd. Sending every query to qalc would turn words such as "7zip", "x264" or "2fa" into math. Home directories link into other volumes, such as `/vault`. fd over a home directory walks caches, build output, Nix store links and dependency trees, and following directory links also follows Nix `result` links into the store and dependency trees, which can hold more matches than fd's result cap.

## Decision

Calc gating: input goes to qalc only when it is a unit conversion (number, unit of one or two words, `to|in|as|into|->`, unit, as in "5 km to mi"), "N% of M", or an expression made only of numbers, operators (`+ - * / ^ × ÷ mod`), postfix `%` and `!`, parentheses, known functions and constants (pi, e, tau, phi) with at least one operator, function, parenthesis or implicit product ("2pi"), ending in an operand. Other words, a bare number, a bare constant and ISO dates are not math.

qalc runs as `qalc -t -u8 -m <qalcTimeoutMs - 500> -- <text>`. `--` ends options so input such as "-v" stays an expression. ASCII output keeps a copied "-2" pasteable, where U+2212 is not.

fd runs with `--follow` and excludes `result`, `result-*`, `node_modules`, `.direnv`, `.git` and `.cache`. Hidden files are skipped and ignore files respected, since under a home directory those are caches, build output and VCS internals. Output is NUL-separated; a timed-out fd can stop mid-record, so only NUL-terminated records count as paths.

File query syntax: words must appear in the file name in order; a glob without "/" matches the whole name; anything with "/" matches the path below the search root, a leading "/" starts a folder name, and with a glob the pattern must reach the end of the path. Spaces mean anything, `*` anything within one name, `**` anything across folders, `?` one character. Matching ignores case unless the text has a capital. fd refuses a name pattern containing "/", so name globs use "." for any character. Rows come only from a result whose text equals the current query, so a slow reply for an older query never shows. fd already matched the path, so a row is kept with score 1 when the fuzzy matcher disagrees, and glob and path queries rank by their literal characters.

The launcher QML fixture builds a search root that links a directory on another volume and holds result links into a store-like tree with more matches than the cap, and its fake fd runs the real fd for patterns containing "needle".

## Consequences

The gating rules decide which inputs ever reach qalc; changing them changes what counts as math. Adding an exclude to fd is the way to hide a new class of generated tree. The fixture layout must keep both link kinds so a change to the fd flags is caught.

## Where

- `packages/stillsuit-shell/src/plugins/builtin/launcher/model/providers/calc.js` (gating rules)
- `packages/stillsuit-shell/src/plugins/builtin/launcher/model/providers/files.js` (`translate`, `fdQuery`, `scoreText`, row scoring)
- `packages/stillsuit-shell/src/plugins/builtin/launcher/Service.qml` (qalc command, fd command, fd output parsing)
- `packages/stillsuit-shell/src/tests/launcher-qml/run.sh` (search tree setup)
