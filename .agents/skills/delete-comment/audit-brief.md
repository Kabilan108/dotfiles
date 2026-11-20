# Comment audit brief

You are auditing every code comment in one slice of Tony's dotfiles repo (a NixOS
flake with the Stillsuit Quickshell desktop, scripts, and agent tooling). The repo
bans comments (docs/adr/0001-ban-code-comments.md). Your job is to classify each comment so the lead can delete it, file
an issue, or move it into an ADR. You are **read-only on the repo**: write only to
the paths the lead gives you. Do not edit, delete, or format repo files, and do not file
issues or run git commands that change state.

The lead gives you a blocks file, an audit output path, an ADR draft directory,
and the commit SHA for permalinks.

Your input: the blocks file, a list of comment blocks with `id`
(`path:line`, the block's first line), `path`, `line`, `end_line`, `inline`
(a trailing comment after code), and `text`. Adjacent full-line comments are one
block. Read the surrounding code for every block. Read whole files when they are
small; at least read the code each comment sits on and grep for names it mentions.

## Categories

- **tautology**: restates what the code, its names, or its structure already show.
  Section banners, "Imports", narration of the next line, test narration a test
  name or assertion already carries, upstream sample-config boilerplate ("Find
  more information on the wiki").
- **stale**: wrong for the current code. It names a function, file, flag, option,
  behaviour or version that no longer exists or no longer matches, or it is
  commented-out code. Confirm by grepping or reading before calling it stale.
- **excuse**: it explains away a hack in *our* code that we could fix: a
  workaround kept "for now", a sleep or retry papering over a race, duplicated
  logic, a swallowed error, a known-wrong behaviour, a TODO/FIXME/XXX, "temporary",
  "until X lands" where X has landed or is ours to do. The code deserves a fix, so
  the comment becomes a GitHub issue.
- **decision**: records a non-obvious reason the code is the way it is, which the
  code cannot show: an upstream bug or quirk the code correctly works around, an
  invariant, a security or threat-model choice, an ordering constraint, a
  measured number, a rejected alternative. A workaround for someone else's bug
  that is the right call is a decision, with its removal condition if it has one.
- **keep**: deleting it would change behaviour, or it is a tool directive the
  extractor missed. Examples: a script that prints its own header as `--help`
  (`sed`/`grep`/`awk` on `$0` or `BASH_SOURCE`), a fixture whose comment is test
  input, a pragma. Give the evidence in `reason`. Expect very few.

When a comment mixes kinds, pick the one with the strongest action:
excuse > decision > stale > tautology. A decision's half that only restates the
code does not need to survive.

## Comments inside Nix strings

If your slice has `.nix` files, also scan their `''` strings for comment lines of
the embedded language (shell, Python, etc.), lines whose first non-space character
is `#` but not `#!`. Skip lines where `#` is data (markdown headings, config
formats, CSS). Classify each such line or run of lines as an extra entry with
`"embedded": true` and `id` = `path:line` of its first line. Embedded comments are
not in your input file.

## Output

Write the audit output path:

```json
{
  "comments": [
    {"id": "path:12", "category": "tautology", "reason": "≤15 words"},
    {"id": "path:40", "category": "excuse", "reason": "...", "issue": "kebab-key"},
    {"id": "path:77", "category": "decision", "reason": "...", "adr": "kebab-slug"},
    {"id": "path:90", "category": "decision", "reason": "...", "documented_in": "docs/backups.md"},
    {"id": "path:120", "category": "keep", "reason": "usage() prints lines 2-9 of $0"}
  ],
  "issues": [
    {"key": "kebab-key", "title": "Sentence-case title naming the hack", "body": "markdown", "ids": ["path:40"]}
  ],
  "adrs": [
    {"slug": "kebab-slug", "title": "Sentence-case title", "ids": ["path:77"]}
  ]
}
```

Every id in your input appears exactly once in `comments`. Use `documented_in`
instead of an ADR only when an existing repo doc (docs/, AGENTS.md, a skill,
a README) already states the same reason; name the file.

### Issues

One issue per hack, not per comment: group comments that excuse the same
workaround. The body has: what the code does now and why it is a hack, the
original comment text in a quote block, a permalink for each location
(`https://github.com/Kabilan108/dotfiles/blob/<SHA>/<path>#L<line>`
or `#L<start>-L<end>`), and a direction for the fix (one or two sentences, no
implementation plan). Keep it under 200 words.

### ADRs

Write each ADR draft to `<adr-dir>/<slug>.md`. Before drafting, check
`docs/adr/README.md`: if an ADR already covers the subsystem, draft an addition to it
and name the existing file in the draft's first line. One ADR per decision or tight
cluster of decisions about one subsystem; fold related comments together rather
than writing one ADR per comment. Format:

```markdown
# <Sentence-case title stating the decision>

Status: Accepted. Recorded from code comments on <date>.

## Context

<the constraint, quirk, or problem; concrete facts, versions, numbers>

## Decision

<what the code does about it>

## Consequences

<what follows: removal conditions, costs, what must stay true>

## Where

- `path/to/file` (`symbolName` or the setting it governs)
```

Name files and symbols in "Where", not line numbers, since lines will shift. Keep
the original comment's facts: versions, numbers, bug links, upstream issue IDs.
Do not invent facts the comment and code do not support.

Writing style for ADRs and issues: plain, specific, active voice, sentence-case
headings, no em dashes, no filler ("It is important to note"), no puffery
("robust", "crucial", "seamless"), no inline bold labels. Say what the mechanism
does, with names and numbers.

## Done when

`python3 .agents/skills/delete-comment/validate-audit.py <blocks file> <audit file> <adr-dir>`
prints `OK ...`. Then reply with: counts per
category, number of issues and ADRs, and up to five comments you were least sure
about (id + one line why). Do not paste the JSON back.
