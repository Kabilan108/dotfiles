# Exhibits

Pick the smallest exhibit that makes the point. Give each one a caption: one sentence on what to notice. A pin or callout on an exhibit is one clause. Several small exhibits beat one large one.

Draw with HTML, CSS and inline SVG. A rendering library is fine when you check its output in the PageBin viewer.

## Which exhibit

| The point is about | Exhibit |
|---|---|
| What changes in runtime control flow | Call tree with change marks |
| Logic or an algorithm | Pseudocode |
| UI structure, state and module boundaries | Component tree |
| File responsibility or a broad refactor | Shallow file tree |
| How parts or services talk | Flow or sequence diagram |
| A lifecycle | State machine, with the screen for each state when the state changes what the user sees |
| What a user sees or does | Mockup of the smallest region; a screenshot for UI that exists |
| A data shape | Schema in the project's own language |
| Existing code | Code excerpt with source and commit |
| A change to existing code | Unified diff, one file per block |
| Measured results | Chart (follow [reports](reports.md)) or a table |
| Several items across several attributes | Table |
| Before and after | Side-by-side pair with the same scale and framing |
| Work over time | Timeline |
| Behaviour in motion | Recording with a poster frame |

## Trees and diffs

Monospace blocks. Mark each row: `+` new, `-` removed, `~` changed, `?` proposed, a space for context. Bold a new symbol. End a row with its location (`path:line`) when it exists or is being added; align locations in a right column. Keep one tree under about 15 rows.

```text
~ <Composer/>                            web/src/composer/Composer.tsx:41
+   <SendLaterMenu/>                     web/src/composer/SendLaterMenu.tsx:12
+     POST /api/scheduled                web/src/api/scheduled.ts:9
    saveDraft()                          web/src/drafts.ts:22
```

Use the same marks for a component tree, a file tree, pseudocode or a call stack when the point is what changes and the surrounding shape already exists. Show the whole block when most of it is new or when omitted context would hide ownership or order.

## Diagrams

- Flow and sequence: at most about 12 nodes; at most 3 columns, so a phone reads it without panning. Short labels on nodes and arrows; detail goes in the caption.
- State machine: place states on a grid, main path on the top row and the ways out below. Every state is reachable; every dead end is final. When the state changes the screen, pair each state with its mockup.
- Arrows never cross labels. Check the render.

## Mockups

Draw the smallest region that makes the point: one card, one menu, one row, designed at 480px wide or less. A full-window mock is an overview; pair it with a narrow crop of the part that matters. Use real labels and data, and match the product's type, colour and spacing. Numbered pins mark what to notice.

## Code

- Excerpt of code that exists: the lines that carry the point, 25 at most, exact text from the file, wrapped in `<figure data-source="path:start-end" data-commit="sha">`. Highlight the lines that carry the point.
- Code that does not exist yet: `<figure data-sketch>`, with "sketch" in the caption.
- Change to existing code: unified diff with its real `@@` hunk header, one file per figure.
- Schema: text in the language that states it (TypeScript, SQL, protobuf, JSON Schema), with `+`/`-` lines for changes. Show the 5 to 10 members that matter and note how many more exist.
- Lines over about 90 characters wrap on a phone; reflow sketches.

```html
<figure data-source="server/src/scheduled/store.ts:58-66" data-commit="80eca63">
  <figcaption><code>store.ts:58</code> claims due rows; two workers never claim the same row.</figcaption>
  <pre><code>…the exact lines…</code></pre>
</figure>
```

`scripts/lint.py --root <repo>` checks that each `data-source` excerpt still matches its file.

## Tables

Use a table when the reader compares several items across several attributes. Six columns or fewer reads on a phone; wider tables sit in a horizontal scroll wrapper. Put the column the reader scans first on the left. Right-align numbers and keep units in the header.
