# Ban code comments; record decisions as ADRs

Status: Accepted. 2026-11-20.

## Context

Before this change the repo had 1,903 comment blocks (4,103 comment lines) in 352 files. An audit sorted them:

- 997 restated the code.
- 30 were stale or commented-out code.
- 30 excused a workaround in our own code that could be fixed.
- 862 recorded a reason the code could not show.
- 20 had to stay.

The excuses are the costly kind. A comment that explains a hack lets the hack stand, and the next change copies it. Decision comments are worth keeping, but scattered across files they can't be found, reviewed or retired, and many had already gone partly stale.

## Decision

Code carries no comments. Each kind of comment has its own destination:

- A reason the code can't show goes in an ADR under `docs/adr/`, or in the existing doc that owns the subsystem.
- A workaround we could fix becomes a GitHub issue, and the comment goes.
- Anything that only restates the code, or is stale, is deleted.

`scripts/comment-lint` enforces the ban in the `comment-lint` commit hook. It parses files with tree-sitter (Nix, shell, Python, QML, JS/TS, Go, Lua, KDL, TOML, YAML, JSONC). It does not count tool directives as comments: shebangs, `shellcheck`, PEP 723 blocks, LuaLS `---@` annotations, lint suppressions, `go:` pragmas and schema hints. Comments inside Nix `''` strings are outside its reach. The audit removed them by hand.

The ban works as a ratchet. `scripts/comment-lint.baseline.json` records each file's allowed comment lines, and a file outside it allows none. A commit fails when a file goes over its count. It also fails when a file drops below its count without lowering the baseline, which `scripts/comment-lint baseline` does. `baseline --reset` can raise counts, and a commit that uses it must say why.

These comments stay in the baseline:

- MIT attribution headers on code adapted from Omarchy Quattro, fzf and html-plan, which `docs/attribution/omarchy-quattro.md` requires.
- Release labels on SHA-pinned actions in `.github/workflows/cache.yml`.
- The edit-region markers in `hitl-loop.template.sh`.

The atuin hook files in `agents/opencode/plugins/atuin.ts` and `agents/pi/agent/extensions/atuin.ts` are excluded outright. They are `atuin hook install` output, and a reinstall rewrites them.

## Consequences

Whoever wants to explain code writes an ADR, a doc, a better name or an issue. The baseline only shrinks unless someone resets it on purpose. Python docstrings are not comments to this rule, and nothing in it limits them. The `delete-comment` skill (`.agents/skills/delete-comment`) repeats the audit for whatever comments the baseline still allows, or for a directory brought in later.

## Where

- `scripts/comment-lint`
- `scripts/comment-lint.baseline.json`
- `prek.toml` (`comment-lint` hook)
- `flake.nix` (`COMMENT_LINT_GRAMMARS`, `tree-sitter` in the dev shell)
- `.agents/skills/delete-comment/SKILL.md`
