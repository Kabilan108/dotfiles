---
name: delete-comment
description: Audit the code comments the comment ban still allows (or a given path), delete them, and move what they knew into code, tests, notes, ADRs or issues.
disable-model-invocation: true
---

# Delete comments

The repo bans code comments ([ADR 0001](../../../docs/adr/0001-ban-code-comments.md)). `scripts/comment-lint` finds them, and `scripts/comment-lint.baseline.json` lists the ones still allowed. This skill clears comments from a scope. Each comment's content ends up in one place: nowhere, the code, a test, a subsystem `AGENTS.md` note, an ADR, an issue, or the baseline.

Run every command from the repo root through `direnv exec "$PWD"`. Keep working files in a directory that outlives the session, such as a sibling of the worktree, and delete it when the PR merges.

## 1. Scope

The scope is the paths the user named. Without any, it is every file in the baseline. List the blocks:

```sh
direnv exec "$PWD" scripts/comment-lint list --json <paths> > "$WORK/blocks.json"
```

For `.nix` files, also look in `''` strings for comment lines of the embedded language. The linter can't see these, so audit them as extra entries.

Done when every block and embedded comment in scope is listed.

## 2. Classify

Use [the audit brief](audit-brief.md) for the categories, the homes for a reason, and the output schema. Read the code around every comment. When there are more than about 150 blocks, split them by subsystem and send one read-only subagent per slice with the brief, its blocks file, an output path and a drafts directory. You file the issues and edit the repo.

Done when `python3 .agents/skills/delete-comment/validate-audit.py <blocks.json> <audit.json> <drafts-dir>` prints `OK` for every slice. Read the least-certain calls the agents report and settle each one yourself.

## 3. Apply

1. Delete every block whose category isn't `keep`: `direnv exec "$PWD" scripts/comment-lint delete <id>...`. Delete embedded comments by hand.
2. Run the formatters on the touched files (`nixfmt`, `gofmt -w`, `qmlformat -i`), and remove blank lines left after `{` or before `}` in files with no formatter.
3. `direnv exec "$PWD" scripts/comment-lint verify HEAD` must name no file you didn't mean to change. It compares syntax trees with comments removed.
4. Notes: merge each draft into the `AGENTS.md` of its directory. `direnv exec "$PWD" scripts/notes-check` must pass.
5. ADRs: an agent's ADR draft is a proposal. Show it to the user before adding it under `docs/adr/`.
6. Code and test items: apply the small ones in a second commit, with the area's tests, so the first commit stays comment-only. File the rest as one issue per subsystem with a checklist.
7. Issues for excuses: push the commit the permalinks name, then `gh issue create --title ... --body-file ...` per hack, and list them in the PR body.
8. Lock in the drop with `direnv exec "$PWD" scripts/comment-lint baseline`. A `keep` stays in the baseline; give its reason in the PR.
9. Run `direnv exec "$PWD" prek run --files <changed files>`.

Done when `verify`, `notes-check` and the hooks pass.

## 4. Report

Report counts per category and home, the issues filed (with links), the notes and ADRs added, the keeps and why, the lines shed (`git diff --shortstat`), and anything you settled against an agent's call.
