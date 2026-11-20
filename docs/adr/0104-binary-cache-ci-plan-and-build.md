# The cache plan evaluates ungrafted host systems and passes derivations to build jobs

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

`ci/cache-targets.py plan` finds the heavy packages each host needs and the cache workflow builds and publishes them. Hosts apply `system.replaceDependencies`, which rewrites built outputs, not derivations. Evaluating the grafted toplevel needs import-from-derivation (IFD) of the whole system closure, so the plan step would build every package.

Atuin's flake picks its Rust toolchain with fenix's `fromToolchainFile`, which downloads `channel-rust-<version>.toml` and reads it during eval. That is IFD too, until upstream pins the manifest as a flake input (`fromManifestFile`).

Cachix refuses urllib's default User-Agent. GitHub Actions runs `bash -e {0}` for a default shell but adds `-o pipefail` when a job names `shell: bash` explicitly.

## Decision

- The plan evaluates each host with the replacements forced to an empty list (`UNGRAFTED_TOPLEVEL`). That closure holds the same package builds the host uses.
- IFD would otherwise stay off so any other IFD fails eval at once. For Atuin the plan evaluates with IFD on, and `require_atuin_ifd()` fails the plan once the locked Atuin evaluates without IFD.
- `find()` drops any output already on cache.nixos.org, which also skips nixpkgs builds of the same pname pulled in elsewhere.
- `cached()` sends `User-Agent: dotfiles-cache-targets`.
- The workflow sets `defaults.run.shell: bash` to get pipefail.
- The plan job's `drvs` artifact is uploaded with `compression-level: 0` (the NARs inside are zstd already) and `retention-days: 1`, which leaves time to re-run failed builds. A re-run of the plan job replaces it.
- Build jobs keep the runner's preinstalled toolchains instead of deleting them. A `Disk space` step prints `df -h /` after every build to show the headroom left.

## Consequences

- When `require_atuin_ifd()` fails, delete it and evaluate with `allow-import-from-derivation false` again.
- Until then, any other IFD in a host closure builds inside the plan step instead of failing.
- If disk space runs short, the `Disk space` output is the first place to look before restoring cleanup.

## Where

- `ci/cache-targets.py` (`UNGRAFTED_TOPLEVEL`, `require_atuin_ifd`, `find`, `cached`)
- `.github/workflows/cache.yml` (`defaults.run.shell`, the `drvs` upload step, the `Disk space` step)
