# Temporary pins and backports carry their own removal condition

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Three upstream problems need local workarounds until upstream ships a fix.
Zotero 10 bundles Firefox 140 ESR, which reached end of life on 2026-10-13, so nixpkgs marks it insecure.
nixos-unstable commit f4a03c0 makes Rust `-sys` crates link system libraries, and packages that never listed those libraries fail to build.
nix-direnv 3.2.0 makes cached shells repeatedly invalidate each other through profile timestamps; the fix is nix-community/nix-direnv#790. nixpkgs still shipped 3.2.0 when this record was written.

## Decision

- `permittedInsecurePackages` allows `firefox-esr-140-bin-unwrapped-140.17.0esr`.
- `packages/rust-system-libs.nix` copies the nixpkgs master fixes as an overlay. tabiew gets sqlcipher and zstd from NixOS/nixpkgs@7e94c72bfc. Each override throws once nixpkgs includes its fix, detected by zstd already being in `buildInputs`.
- nix-direnv is pinned to 3.1.2 from source.

## Consequences

The Rust overlay removes itself by failing evaluation once it is obsolete. The other two need a manual check: drop the Zotero permit once nixpkgs' Zotero moves to a supported ESR, and drop the nix-direnv pin once a release includes #790.

## Where

- `flake.nix` (`nixpkgs.config.permittedInsecurePackages` in `makeSystem`)
- `packages/rust-system-libs.nix` (`addInputs`, `tabiew`)
- `home/shell.nix` (`nixDirenvUnresholved`, `nixDirenv`)
