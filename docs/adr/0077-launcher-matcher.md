# Launcher matcher ports fzf FuzzyMatchV2, prunes by score ceilings and is tested for parity

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The launcher scores every candidate on each keystroke inside QML's V4 engine, which is slow for per-character JavaScript loops. Element access on typed arrays is about ten times slower than on plain arrays in V4. Scores need to match fzf's so ranking feels familiar. fzf has a gap-over-match quirk that the traceback's tie-break reads. Omarchy's app search had a case where "contact" loosely matched the Calculator entry's text.

## Decision

Scoring ports fzf's FuzzyMatchV2 (`src/algo/algo.go` at v0.74.4, default scheme). The match start and a `min(index * 5, 50)` field penalty are subtracted, following Elephant. Acronym matching follows Omarchy's `AppSearch.js`. Provenance and licences stay in the file header.

Speed choices:

- Scratch buffers are plain arrays, not typed arrays.
- Native `indexOf` finds the greedy first occurrences (fzf's F) and rejects non-matches before any per-character loop; the DP spans only `F[0]..lastIdx`, like fzf's `asciiFuzzyIndex` trimming.
- Single-character patterns visit occurrences only, making fzf's choice.
- Two-character patterns take `twoCharMatch`, which gives the same score, field, start and positions as the DP while evaluating only occurrences of the two characters. `TWO_CHAR_PATH` exists so tests can compare it with the general DP.
- The DP covers the first `MAX_PATTERN_LENGTH` units; the full pattern must still be a subsequence. Patterns are cut just past `MAX_FIELD_LENGTH`.
- `score()` skips fields that cannot win: penalties only grow with the field index, so the loop stops once no later field can beat the best; a field missing a query character is skipped by mask; when the first query character is never on a boundary in the field, the boundary bonus is lost and no acronym can start, so a lower ceiling applies. Whitespace has no mask bit, so a zero `firstBit` proves nothing.
- `fuzzyMatch` returns -1 early when raw score minus start cannot exceed `mustExceed`.

Case folding keeps indices: `foldCodePoint` lowercases one code point to a string of the same length (final sigma folds to σ; when lowercasing changes length, as "İ" does, the first code point is kept if it has the original width). `classAt` gives a low surrogate its pair's class. The range U+2000 to U+2BFF (general punctuation, arrows, math, box drawing) counts as non-word.

`matcher.test.js` loads `Matcher.js` a second time with `TWO_CHAR_PATH` off and compares both on 60,000 random patterns over small alphabets that include boundary characters, so ties, consecutive runs and the gap-over-match case occur often. A fixed input (`"ab"` against a field of b/a runs) pins one gap-over-match column the tie-break reads. A regression assertion requires "contact" to score 0 against the Calculator entry's fields.

## Consequences

Any change to scoring must keep `twoCharMatch` exactly equal to the general DP. The pruning bounds must be updated with any bonus or penalty constant. The Omarchy case must keep scoring 0; loosening the matcher to allow it is a behaviour change.

## Where

- `packages/stillsuit-shell/src/plugins/builtin/launcher/model/Matcher.js` (`zeroes`, `charClass`, `foldCodePoint`, `foldString`, `prepareQuery`, `fuzzyMatch`, `twoCharMatch`, `score`, `TWO_CHAR_PATH`)
- `packages/stillsuit-shell/src/tests/launcher/matcher.test.js`
