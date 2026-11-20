# Flake inputs follow nixpkgs unless a binary cache match matters more, and niri builds against our nixpkgs

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Most inputs set `inputs.nixpkgs.follows = "nixpkgs"`. A few inputs need a different choice because of security fixes, cache hits or a stale upstream pin.

- ghostty's own nixpkgs shipped brotli 1.2.0 (CVE-2026-111497).
- niri needs the system's glibc to load newer Mesa drivers. niri-flake stopped bumping its `niri-unstable` pin in August 2026. The pinned niri revision requires libdisplay-info 0.2, which newer nixpkgs removed. niri's `checkPhase` rebuilds the crate graph for `cargo test`: about 7 of the 20 minutes niri takes in the cache CI. Upstream CI runs the tests.
- Atuin publishes builds to atuin.cachix.org made with its own nixpkgs and toolchain.
- `bun build --compile` embeds the bun that builds pagebin.

## Decision

- ghostty (tag v1.4.0) follows the system nixpkgs, so it gets the system glibc, Mesa ABI and security fixes.
- niri-flake overrides `niri-unstable` to `github:niri-wm/niri`, so fixes such as SHM screencasting on NVIDIA arrive. niri-flake's overlay is applied to our nixpkgs, so niri uses the system glibc, and `programs.niri.package` is `niri-unstable` from that overlay. The overlay adds `libdisplay-info_0_2` from `packages/libdisplay-info/0.2.nix`, and `niri-unstable` has `doCheck = false`. niri-flake supplies the NixOS module; niri's `config.kdl` lives in Home Manager as a manual file.
- niri.cachix.org is disabled (`niri-flake.cache.enable = false`), since it never has a build against our nixpkgs (`docs/security-hardening.md`).
- atuin does not follow nixpkgs, so the release matches atuin.cachix.org. Its pin stays on a release tag that CI has cached.
- pagebin comes in through its overlay, so it builds with this overlay set's bun.
- Extra substituters: kabilan108.cachix.org holds CI builds from YubiKey-signed deploy tags (`.github/workflows/cache.yml`); ghostty.cachix.org and atuin.cachix.org hold those flakes' own builds.

## Consequences

Moving atuin off a cached release tag means compiling it locally. Making ghostty unfollow nixpkgs would bring back its bundled dependencies. The niri override stays until niri-flake tracks niri again. Remove the vendored libdisplay-info once the niri revision no longer needs 0.2. niri's tests don't run in our CI.

## Where

- `flake.nix` (`inputs.ghostty`, `inputs.niri-flake`, `inputs.atuin`, the `overlays` list)
- `configuration.nix` (`nix.settings.extra-substituters`)
- `modules/nixos/wayland/niri.nix` (`nixpkgs.overlays`, `niri-flake.cache.enable`)
- `packages/libdisplay-info/0.2.nix`
