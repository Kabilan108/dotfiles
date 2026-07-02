---
name: commit
description: Creates logical commits from uncommitted changes
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git reset:*), Bash(git diff:*), Bash(git branch:*), Bash(git log:*), Bash(git ls-files:*), Bash(git rev-parse:*), Bash(file:*), Bash(ls:*), Bash(find:*)
context: fork
---

## Context

- Current git status: !`git status`
- Current git diff (staged and unstaged changes): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -10`

## Your task

Based on the requested scope and the state above, create a series (stack) of logical git commits. Make sure that each commit is holistic — don't commit a new library separately from the code that uses it. Aim for no more than 3 commits unless it definitely makes sense to go beyond that.

Before staging:

- Identify the repo root for the requested scope. In nested workspaces, run git commands with `git -C <repo> ...` and commit each repo separately.
- Inspect staged and unstaged changes separately (`git status --short`, `git diff --stat`, `git diff --cached --stat`). Treat pre-existing staged changes as user-owned until proven related; unstage unrelated paths with `git reset -- <path>` or stage the intended paths explicitly.
- Leave out local and generated churn — env/config files like `public/env-config.js` or `.env`, local agent config, build outputs, and unrelated lockfile rewrites — unless the diff proves this commit needs them.

## Reminders

- Write a good commit message with an excellent first line, bullet point list in summary.
- Check staged files for binaries and large files before each commit: `git diff --cached --numstat` shows binaries as `-	-`; check sizes of anything suspicious. Under no circumstances commit binaries or large (1mb+) files — stop, warn about them, and wait for me to decide, even if pre-commit hooks pass.
- Do not delegate committing to review-only subagents; make and verify commits yourself.
- After committing, report the commit hashes, verification status, and anything intentionally left uncommitted.
