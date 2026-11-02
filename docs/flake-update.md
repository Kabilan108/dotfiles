# Weekly flake update

A user timer on sietch (`flake-update`, Saturdays around 04:00) runs
`bin/flake-update-pr`. It:

1. Makes a detached worktree of `origin/nixos` in `/tmp`.
2. Builds jacurutu's current toplevel from `nixos`, for the closure diff.
3. Runs `nix flake update`. All three hosts share the root `flake.lock`.
4. Builds the sietch and jacurutu toplevels, retrying a failed build once
   (upstream tests flake), and evaluates tleilax's `drvPath`. sietch can't
   build aarch64, so tleilax only gets evaluated.
5. Pushes `auto/flake-update-YYYY-MM-DD` and opens a PR with the input changes,
   closure diffs and build results. A failed build or evaluation still opens a
   PR. It is a draft titled `[build failing]` and includes the error. A throw
   from `packages/security-overrides.nix` means that override can go.
6. Closes older open `auto/flake-update-*` PRs as superseded and tells Tony
   through Hark (project `dotfiles`). No changes, or a job error, also send a
   notification.

Logs for the last 8 runs live in `~/.local/state/flake-update/runs/` on sietch.

## Before merging: check the locks on jacurutu

sietch runs agents, so treat its lock bumps as untrusted. A compromised sietch
could pin an input to a commit that only exists in a fork, because GitHub
serves fork commits under the upstream repo's URL. The PR description comes
from sietch too, so take the command from this file:

```sh
cd ~/dotfiles && git switch nixos && git pull --ff-only
bin/flake-lock-verify <PR number or branch>
```

Run it from your `nixos` checkout so the script itself comes from a trusted
tree. It compares the PR's `flake.lock` with `nixos`'s.
It matches inputs by path from the root (`home-manager/nixpkgs`), including
paths through `follows`, so pointing an input at another node counts as a
change. For every changed GitHub or GitLab input, it checks that:

- the lock nodes have no fields beyond the ones Nix reads (a legacy `info`
  field overrides `locked`);
- the input's `original` is the one on `nixos`, or the one its declaring
  `flake.nix` gives at the locked rev, with the root `flake.nix`'s overrides.
  Nix reuses transitive originals from the lock without rereading the parent,
  so the PR can't pick them;
- the locked repo, host and dir are the ones `original` names;
- the new rev is reachable from the tracked ref (`original.ref`, or the
  repo's default branch), or equals `original.rev` when the input is pinned;
- the new rev descends from the old rev, when the source didn't change;
- the narHash matches the source the forge serves for that rev. Nix
  substitutes a locked input by narHash and never checks the rev, so this one
  matters.

It also fails if the PR touches anything besides the two lock files.

Exit 0 means every changed input passed. Exit 1 means a failure: don't merge.
Exit 2 means some inputs aren't on GitHub or GitLab (nixos.org channel
tarballs, mostly from ghostty's inputs) and need a look by hand. It prints a
`gh pr merge <n> --merge --match-head-commit <sha>` line. Use it, so you merge
the commit you checked and not something pushed afterwards.

When a build fails because an override in `packages/security-overrides.nix`
went stale, run the check on sietch's commit first. Then add your own commit
on top that drops the override, push it to the PR branch, and merge. The check
fails on any non-lock file, so run it before your fix, not after.

`--no-nar-hash` skips the source downloads. It's faster but weaker.
`--head <ref>` checks a local commit instead of a PR.

## After merging

Pull and rebuild sietch and jacurutu. tleilax takes signed deploys and builds
its own closure. From jacurutu:

```sh
deploy tleilax
```

## Running it by hand

```sh
systemctl --user start flake-update      # the deployed copy
bin/flake-update-pr --no-pr              # build and write the PR body only
bin/flake-update-pr --base <branch>      # update from, and open the PR against, <branch>
```

Tests: `python3 -m unittest tests/test_flake_lock_verify.py`.
