# Wayland modules notes

## niri.nix

- Keep the `niri-unstable` input override to github:niri-wm/niri in `flake.nix`. niri-flake stopped bumping its own pin in August 2026, and fixes such as SHM screencasting on NVIDIA arrive only through ours. Remove the override when niri-flake tracks niri again.
- Build niri from niri-flake's overlay applied to our nixpkgs, never from niri-flake's packages. niri needs the system glibc to load newer Mesa drivers.
- Keep `libdisplay-info_0_2` from `packages/libdisplay-info/0.2.nix` in the overlay. The pinned niri revision requires libdisplay-info 0.2, which newer nixpkgs removed. Remove the vendored package once niri no longer needs 0.2.
- Leave `doCheck = false` on `niri-unstable`. The check phase rebuilds the crate graph for cargo test, about 7 of the 20 minutes niri takes in the cache CI, and upstream CI already runs the tests.
