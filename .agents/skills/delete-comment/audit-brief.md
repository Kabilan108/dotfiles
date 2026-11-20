# Comment audit brief

You are auditing every code comment in one slice of Tony's dotfiles repo. The repo
bans comments (`docs/adr/0001-ban-code-comments.md`). Classify each comment so the lead
can delete it and put what it knew in the right place. You are read-only on the
repo: write only to the paths the lead gives you, run no git command that changes
state, and file no issues.

The lead gives you a blocks file, an audit output path, a drafts directory, and the
commit SHA for permalinks. The blocks file lists comment blocks with `id`
(`path:line` of the first line), `path`, `line`, `end_line`, `inline`, and `text`.
Read the code around every block and grep for the names it mentions.

## Categories

- `tautology`: restates what the code, its names or its structure already show,
  or what a test or an existing doc already states. Section banners, narration,
  upstream sample-config text.
- `stale`: wrong for the current code, or commented-out code. Confirm by reading.
- `excuse`: explains away a hack in our code that we could fix: a workaround kept
  "for now", a retry over a race, duplicated logic, a swallowed error, a TODO. It
  becomes a GitHub issue.
- `reason`: says something true that the code does not show. Give it a `home`, the
  first on this list that can hold it:
  1. `code`: one small change would make the code say it (a rename, a named
     constant, an assertion). Record the change in `code_items`.
  2. `test`: a test that fails when someone "fixes" the workaround would hold it,
     and the area has a runner it fits. Record it in `test_items`.
  3. `note`: an upstream bug and when the workaround can go, where a number came
     from, a security or ordering reason, a cross-file invariant. Goes in a nested
     `AGENTS.md`.
  4. `adr`: a decision that is hard to reverse, surprising without context, and the
     result of a real trade-off with a rejected alternative. Expect very few.
  Choose `code` or `test` only when the item is small and specific; otherwise it is
  a note.
- `keep`: deleting it would change behaviour or break a licence duty: a tool
  directive the linter missed, a header a script prints as its usage text, an
  attribution notice. Give the evidence in `reason`.

When a comment mixes kinds, the strongest action wins: excuse, then reason, then
stale, then tautology.

For `.nix` files, also classify comment lines inside `''` strings (a first
character of `#` that is not `#!` and is not data). Add them with `"embedded": true`.

## Notes

A note goes in the `AGENTS.md` of the deepest subsystem directory that contains
every file it is about. Read the existing `AGENTS.md` there first and draft only
what it lacks. Write drafts to `<drafts>/notes/<repo-dir>/AGENTS.md`. Never target
`agents/codex`, `agents/claude`, `agents/antigravity`, `agents/opencode`, `agents/pi`,
`agents/skills`, `agents/*-skills` or `.agents/skills`; notes about files there go to
`agents/AGENTS.md`.

Each note is one bullet of one to three sentences: the rule as an instruction, the
reason with its versions, numbers and links, and when it can go. Backtick repo
paths, relative to the note's directory or from the repo root. Do not backtick file
names from other projects, because `scripts/notes-check` treats them as repo paths.

## ADR drafts

Write to `<drafts>/adr/<slug>.md` in the format `docs/adr/README.md` gives. Check
`docs/adr/` first; a decision that changes an existing ADR is not yours to make, so
report it.

## Issues

One per hack, in `issues`: a sentence-case title naming the hack, and a body under
200 words with what the code does and why it is a hack, the comment in a quote
block, a permalink per location
(`https://github.com/Kabilan108/dotfiles/blob/<SHA>/<path>#L<start>-L<end>`), and a
one or two sentence direction for the fix.

## Output

```json
{
  "comments": [
    {"id": "path:12", "category": "tautology", "reason": "≤15 words"},
    {"id": "path:40", "category": "excuse", "reason": "...", "issue": "kebab-key"},
    {"id": "path:77", "category": "reason", "home": "note", "target": "dir/AGENTS.md", "reason": "..."},
    {"id": "path:90", "category": "keep", "reason": "usage() prints lines 2-9 of $0"}
  ],
  "issues": [{"key": "kebab-key", "title": "...", "body": "markdown", "ids": ["path:40"]}],
  "code_items": [{"file": "repo/path", "change": "...", "fact": "...", "ids": ["path:55"]}],
  "test_items": [{"file": "test file", "asserts": "...", "fact": "...", "ids": ["path:60"]}]
}
```

Every id in the blocks file appears exactly once in `comments`.

Writing style: plain, specific, active voice, sentence-case headings, no em dashes,
no filler, no puffery, no bold labels.

## Done when

`python3 .agents/skills/delete-comment/validate-audit.py <blocks file> <audit file> <drafts dir>`
prints `OK`. Then reply with counts per category and home, the issues, any ADR
draft and why it passes the three tests, and up to five calls you were least sure
about. Do not paste the JSON.
