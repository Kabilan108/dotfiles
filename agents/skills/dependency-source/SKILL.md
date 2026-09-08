---
name: dependency-source
description: Inspect dependency or reference-repository source when a task needs implementation details, version-specific behavior, or examples beyond API documentation.
---

# Dependency source

Use `~/.agents/vendored-deps/` as the shared source store, including reference worktrees. Reuse existing sources before fetching another copy.

Resolve the repository from the supplied URL or the dependency's package metadata. Prefer the version used by the current project (lockfile, tag, or commit); use the upstream default branch for an explicitly current upstream question. Record the commit inspected.

Keep clones under `<owner>/<repo>/` and additional worktrees under `_worktrees/<owner>/<repo>/<revision>/`. Fetch updates without resetting someone else's checkout. Inspect status and existing worktrees before changing a checkout; use a separate revision worktree when another task needs a different version. Leave reference worktrees in the store for reuse.

Search the relevant implementation, tests, and examples. Distinguish what the source proves from an inference about runtime behavior. Cite repository links pinned to the inspected revision when answering. Let the task determine the answer's format and whether code examples help.
