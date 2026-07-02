---
name: deslop
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git branch:*), Bash(git log:*), Bash(git grep:*), Bash(rg:*)
description: Audit and clean a git diff for AI code slop. Use when the user asks to deslop, clean up staged or branch changes, remove redundant comments/defensive code/style drift, or tidy agent-written code before commit.
---

Check the diff and remove all AI-generated slop introduced in these changes.

Scope:

- If the user names a base ref (or passed one as $1), diff against that ref.
- If the user mentions staged changes, inspect `git diff --cached`.
- Otherwise inspect both staged and unstaged changes.
- Preserve unrelated user changes; don't expand into broad refactors.

Remove:

- Extra comments that a human wouldn't add or that are inconsistent with the rest of the file
- Extra defensive checks or try/catch blocks that are abnormal for that area of the codebase (especially if called by trusted / validated codepaths)
- Casts to any to get around type issues
- Redundant wrappers, helpers, options, or fallback paths with no concrete caller
- Any other style that is inconsistent with the file

Keep:

- Boundary validation for untrusted input
- Comments capturing non-obvious intent, invariants, or tradeoffs
- Compatibility shims that have an actual caller

If the user asks for an audit only, don't edit — report findings with file paths and a short rationale instead.

Report at the end with only a 1-3 sentence summary of what you changed
