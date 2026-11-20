---
paths:
  - scripts/comment-lint
  - scripts/comment-lint.baseline.json
  - scripts/notes-check
  - prek.toml
---

# Ban code comments; keep reasons in notes and ADRs

Comments that explain a hack let the hack stand, and comments that record a reason go stale where nobody reviews them. An audit on 2026-11-20 found 1,903 comment blocks: 997 restated the code, 30 were stale, 30 excused a fixable workaround, and 862 gave a reason. Code now carries no comments. A reason goes in the first place that can hold it: the code (a name, a constant, an assertion), a test, a note in the subsystem's `AGENTS.md`, or an ADR here. An excused workaround becomes a GitHub issue. Keeping comments and policing their quality lost because nothing can check a comment against the code beside it.

## Consequences

- `scripts/comment-lint` enforces the ban in a commit hook with tree-sitter. `scripts/comment-lint.baseline.json` lists each file's allowed comment lines and only shrinks, unless someone runs `comment-lint baseline --reset` and says why.
- The baseline keeps MIT attribution headers (`docs/attribution/omarchy-quattro.md` requires them), release labels on SHA-pinned actions in `.github/workflows/cache.yml`, and the edit markers in `agents/skills/diagnosing-bugs/scripts/hitl-loop.template.sh`. The atuin hook files under `agents/` are excluded because `atuin hook install` rewrites them.
- Tool directives (shebangs, `shellcheck`, PEP 723, LuaLS annotations, lint suppressions) and Python docstrings are not comments to this rule. Comments inside Nix `''` strings are beyond the linter and are removed by review.
- A reason no longer sits on the line it explains, so agents must read the `AGENTS.md` files above a file before editing it. `scripts/notes-check` fails a commit when a note or ADR names a path that is gone.
- The `delete-comment` skill repeats the audit.
