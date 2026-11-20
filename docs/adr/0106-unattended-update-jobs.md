# Unattended update jobs run from store copies, commit only their own files and retry only fetch failures

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The weekly `flake-update` job on sietch runs `bin/flake-update-pr`, which builds three toplevels, each with a 3-hour `BUILD_TIMEOUT`; a failed build is retried once. sietch's `~/dotfiles` checkout can hold anything an agent left there. `nix store diff-closures` colours its output even when writing into a pipe.

`update-app-pins` (Helium, ChatGPT desktop, Grok bot), which runs daily, and `mise-update` run unattended on the `nixos` checkout and push to `origin/nixos`. The checkout may hold unrelated staged or unstaged work. Package builds read the working tree. The per-app updaters need tools such as `dpkg-deb`, `jq`, `gh` and `gpgv` that may not be installed.

## Decision

- `flake-update` runs a store copy of `bin/flake-update-pr`, not the checkout's, with `TimeoutStartSec = "10h"` to cover three builds of up to 3 hours when caches miss.
- All builds share `JOB_BUDGET` of 9 hours, leaving an hour of the unit's 10 for reporting and cleanup. A retry runs only when at least `RETRY_MIN_LEFT` (30 minutes) remains. ANSI escapes are stripped from the `diff-closures` output before it goes into the PR body.
- Commits use `git commit --only -- <pin file>`, so unrelated staged and unstaged work stays out.
- Pushes go to `HEAD:refs/heads/nixos` with no force and no rebase. A rejected push leaves the commits locally for manual recovery.
- `update-app-pins` refuses to run unless the files its builds read (`packages`, `flake.nix`, `flake.lock`, the three updaters) match HEAD.
- A failed `git fetch` exits 75 (EX_TEMPFAIL), and only then. The unit sets `RestartForceExitStatus = [ 75 ]` and `RestartSec = "15m"`, so systemd retries failed fetches and leaves every other failure for Tony.
- Deployment stays manual: the notification asks for a rebuild.
- When a tool is missing, each updater re-execs itself inside `nix shell` with tools from this repo's pinned nixpkgs (`nixosConfigurations.jacurutu.pkgs`), without a system rebuild.
- `update-chatgpt-desktop` pins the immutable versioned `.deb` URL and checks it serves the same bytes (hash) as the latest URL.

## Consequences

Changes to `bin/flake-update-pr` take effect only after a rebuild. `JOB_BUDGET` must stay below the unit's `TimeoutStartSec`; raising `BUILD_TIMEOUT`, the budget or the number of host builds means raising the unit timeout. A diverged `nixos` needs a person to rebase and push. Any new exit path that should retry must use 75.

## Where

- `home/services/flake-update.nix` (`systemd.user.services.flake-update`, `TimeoutStartSec`)
- `bin/flake-update-pr` (`JOB_BUDGET`, `RETRY_MIN_LEFT`, `ANSI_RE` in the build step)
- `home/services/update-app-pins.nix` (`RestartForceExitStatus`, `RestartSec`)
- `bin/update-app-pins` (`build_inputs`, the fetch and push steps)
- `bin/mise-update`
- `bin/update-helium`, `bin/update-chatgpt-desktop`, `bin/update-grok-bot` (tool re-exec)
- `bin/update-chatgpt-desktop` (`version_url`)
