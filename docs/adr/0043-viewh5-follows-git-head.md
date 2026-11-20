# viewh5 installs from Git HEAD without a release-age hold

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Third-party tools wait out a release age before install (pnpm `minimumReleaseAge`, mise `minimum_release_age = "7d"`). viewh5 is Tony's own package.

## Decision

The weekly install-tools job installs viewh5 with `uv tool install -U --from git+https://github.com/kabilan108/viewh5`, following Git HEAD.

## Consequences

A push to viewh5's default branch reaches both machines at the next weekly run, with no hold.

## Where

- `home/services/install-tools.nix` (`update_tool viewh5`)
