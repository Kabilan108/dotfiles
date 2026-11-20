---
name: delete-comment
description: Audit the code comments the comment ban still allows (or a given path), then delete them, file issues for the hacks they excuse, and move their decisions into ADRs.
disable-model-invocation: true
---

# Delete comments

The repo bans code comments ([ADR 0001](../../../docs/adr/0001-ban-code-comments.md)). `scripts/comment-lint` finds them, and `scripts/comment-lint.baseline.json` lists the ones still allowed. This skill clears comments from a scope. Every comment ends up in one of four places: nowhere, an issue, an ADR, or the baseline.

Run every command from the repo root through `direnv exec "$PWD"`. The dev shell provides `COMMENT_LINT_GRAMMARS`.

## 1. Scope

The scope is the paths the user named. Without any, it is every file in the baseline. List the blocks:

```sh
direnv exec "$PWD" scripts/comment-lint list --json <paths> > "$SCRATCH/blocks.json"
```

Each block has an `id` (`path:line` of its first line), `text`, and `inline` (a trailing comment). For `.nix` files, also look in `''` strings for comment lines of the embedded language: a line whose first character is `#` but not `#!`, where `#` isn't data. The linter can't see these, so audit them as extra entries.

Done when every block and embedded comment in scope is listed.

## 2. Classify

Read the code around every comment and grep for any names it mentions. Use [the audit brief](audit-brief.md) for the categories and the output schema. When there are more than about 150 blocks, split them into slices by subsystem and send one read-only subagent per slice. Each agent gets the brief, its slice's blocks file and its own output path. Agents write only to scratch. You file the issues and edit the repo.

Done when `python3 .agents/skills/delete-comment/validate-audit.py <blocks.json> <audit.json> <adr-dir>` prints `OK` for every slice. Before acting, read the least-certain calls the agents report and settle each one yourself.

## 3. Apply

1. Delete every block whose category isn't `keep`:
   `direnv exec "$PWD" scripts/comment-lint delete <id>...`. Delete embedded comments by hand.
2. Run the formatters on the touched files: `nixfmt`, `gofmt -w` and `qmlformat -i`. KDL and other files with no formatter can be left with blank lines after `{` or before `}`. Remove those.
3. `direnv exec "$PWD" scripts/comment-lint verify HEAD` must print no file. It compares each file's syntax tree with comments removed, so any other change shows up. The one exception is a file you meant to change.
4. ADRs. Check `docs/adr/README.md` for an existing ADR on the same subsystem. If there is one, extend it. Otherwise give the new ADR the next free number and add it to the index. Every path under "Where" must exist.
5. Issues. Push the commit you link to first, so the permalinks resolve. Then file one issue per hack with `gh issue create --title ... --body-file ...` and add a link to each one in the PR body.
6. Lock in the drop with `direnv exec "$PWD" scripts/comment-lint baseline`. A `keep` stays in the baseline. Give its reason in the PR.
7. Run `direnv exec "$PWD" prek run --files <changed files>`. For changed Stillsuit, Python or Go code, also run that area's tests (see `docs/testing.md`).

Done when `verify` and the hooks pass, and `git diff --shortstat` shows only deletions plus the new ADRs and the baseline.

## 4. Report

Report counts per category, the issues filed (with links), the ADRs added or extended, the keeps and why, the lines shed (`git diff --shortstat`), and anything you settled against an agent's call.
