---
name: nix-flakes
description: Use when setting up a project's dev environment (dev shell, .envrc), creating, packaging, or changing one of Tony's tool flakes, wiring a flake into ~/dotfiles, or pushing a security fix for a runtime or dependency out to those tools.
---

# Tony's tool flakes

The goal is **one patch point**. Tony's tools (pagebin, dictator, disktree, atlas, hark, tracer, siren, …) are flake inputs to `~/dotfiles`. A fix applied once in dotfiles, whether a nixpkgs update or an overlay in `packages/security-overrides.nix`, should reach every tool on the next rebuild. Each tool flake is a **producer** that dotfiles, the **consumer**, builds with its own package set.

Reference implementation: `~/repos/cli/pagebin` (`flake.nix`, `nix/package.nix`, Kabilan108/pagebin#17).

## Producer: the tool's flake

- Put the derivation in `nix/package.nix`, written for `callPackage`. It takes every nixpkgs dependency as an argument: `{ lib, stdenvNoCC, bun, fetchzip }`, never `pkgs.bun` from a captured `pkgs`.
- Expose `overlays.default = final: prev: { <name> = final.callPackage ./nix/package.nix { }; };`. Using `final` makes the consumer's overlaid versions flow in.
- Keep `packages.<system>.default = pkgs.callPackage ./nix/package.nix { }` on the flake's own nixpkgs, so `nix build` and `nix run` still work standalone.
- Add `nix/**` to any CI path filters that gate Nix validation.

## Consumer: wiring into dotfiles

- Add the input with `inputs.nixpkgs.follows = "nixpkgs"`.
- Add `inputs.<name>.overlays.default` to the `overlays` list in `flake.nix`.
- Reference the tool as `pkgs.<name>` everywhere (`home.packages`, `runtimeInputs`). `inputs.<name>.packages.${system}.default` is built from the producer's own nixpkgs instance, so it misses dotfiles' overlays.
- A flake with no overlay yet can be overridden in place (`.overrideAttrs { nativeBuildInputs = [ final.bun ]; }`) as a stopgap. Then file the producer refactor.

Following dotfiles' nixpkgs gives up the producer's Cachix hits, because derivation hashes change. Accept that cost; sietch's binary cache (Kabilan108/dotfiles#28) is the plan for build cost.

## Embedded runtimes and lockfile trust

Overlays reach what the build takes from nixpkgs, and nothing else. Match the fix to where the vulnerable code lives:

- **Compiled-in runtime**, e.g. `bun build --compile`, a static OpenSSL, or a bundled Python or Node. The runtime comes from the derivation's arguments, so the producer pattern above is the fix.
- **Language lockfile**: `Cargo.lock` (`rustls-webpki`, `webpki-roots`), `uv.lock` (`certifi`), `bun.lock`, `go.sum`. Bump the dependency in the tool's repo, land it, then run `nix flake update <name>` in dotfiles. If the dependency choice is open, prefer verifiers that read the system trust store (`rustls-platform-verifier`, `rustls-native-certs`, `truststore`), which pick up nixpkgs' `nss-cacert` on rebuild.
- **Prebuilt binary download.** Only an upstream release fixes it; pin the fixed version and hash.

## Done when

- `nix build` of the producer flake passes, and the binary runs.
- The consumer's overlaid dependency is in the build. Check with `nix derivation show` on `pkgs.<name>` from a dotfiles host, or ask the binary directly (`BUN_BE_BUN=1 <bin> --version` for Bun compiles).
- `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` passes in dotfiles for each host that installs the tool.

## New project dev shell

When a project needs development tools, start from the template in the project root:

```sh
nix flake init -t ~/dotfiles#devshell
```

It writes a `flake.nix` with `devShells.default` for x86_64 and aarch64 Linux, and an `.envrc` holding only `use flake`. Claude's file tools can't read or write `.envrc`, so let the template create it. Secrets stay out of `.envrc`. Add tools to `packages`, `git add flake.nix flake.lock` in a git repo (flakes see only tracked files), then `direnv allow`. Done when `nix flake check` and `direnv exec "$PWD" true` pass.
