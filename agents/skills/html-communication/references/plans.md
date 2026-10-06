# Plans

A plan is a tree of claims. Closed, the tree is the summary; the reader opens it one level at a time.

| Level | Answers | The claim is | Exhibit |
|---|---|---|---|
| Title | What is this? | the change and the place, 3 to 7 words | none |
| 1 | What can someone now do or see? | a behaviour | mockup, or a state machine if it has a lifecycle |
| 2 | How does that work? | one entrypoint, rule or record | call tree, schema or short code |
| 3 | Where? | `path:line · symbol` | code excerpt or sketch |

## Header

- `h1`: a title naming the change and the place ("Scheduled Send in PostBox"), not a sentence.
- A change stat: "Proposed · 9 files · +5 new · ~4 changed".
- The freshness line.
- **Why**: the user's own words, quoted and trimmed with "…", never paraphrased. Collapsed by default.

## The tree

```html
<body data-genre="plan">
<main>
  <details class="claim">
    <summary>The user can pick a send time in the composer.</summary>
    …one exhibit…
    …decisions for this claim…
    <details class="claim">
      <summary>"Send later" saves the message with a time. It does not send.</summary>
      …
    </details>
  </details>
  <details class="claim" data-aux="shared"><summary>Shared: one new table.</summary>…</details>
  <details class="claim" data-aux="scope"><summary>Not changing: normal send, drafts, the mail provider.</summary>…</details>
</main>
```

- **Split the top level by behaviour**: what a user or caller can now do or see. The reader judges a behaviour without reading code; a split by file, layer or order of work makes them read code to judge it.
- **A claim is one sentence that can be true or false**, about 12 words. "A user can hold 50 scheduled messages at most.", not "Message limit".
- **One exhibit per claim.** A second exhibit is a second claim.
- **At most 5 children per claim and 3 levels.** A small change gets a small tree: two or three claims, with children only where the how or the where is not obvious.
- **Number the claims** in their summary text (1, 1.2, 1.2.1), so answers and comments can cite them.
- **Two closing branches.** After the behaviours, add `data-aux="shared"` for anything several claims depend on (a new table, a shared module), shown once instead of repeated, and `data-aux="scope"` listing what the change leaves alone, so a wrong boundary is easy to spot. Both stay unnumbered.
- For a change with no visible behaviour, such as a refactor, the level-1 claims are guarantees: "Nothing a caller sees changes.", "Each store has one owner."
- The tree replaces a TL;DR, a steps list and section headings. Read the level-1 claims aloud: they tell the whole change.

## Decisions

A decision sits on the claim it changes: after the exhibit, before child claims. Ask only about forks that change what gets built, usually 2 to 5 per plan, and default the rest. Markup and reading answers: [decisions](decisions.md).

## Steps

1. Read the code first: entrypoints, records and screens the change touches, with exact paths and lines, and the user's words.
2. Write the level-1 claims and read them aloud. Fix them before anything else.
3. Add the how and where claims, then the exhibits, then the decisions.
4. Lint, publish, and check the page closed, with each claim open, and at each decision.
5. Hand it over in one line: how many decisions, and that the checked options are your recommendations.
6. Read the review with `pagebin review` (see [decisions](decisions.md)) and apply the answers. Refer to claims by number. When the answers change the shape of the plan, update the page and hand it over again.
