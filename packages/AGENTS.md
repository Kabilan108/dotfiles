# Packages notes

- Only extract the ChatGPT desktop and Grok Bot Debian packages (`chatgpt-desktop.nix`, `grok-bot.nix`): no ELF, ASAR, launcher or feature patches, and never run their dpkg maintainer scripts, which add an apt source and an AppArmor profile. A fix that needs patching goes upstream or into our launcher.
- Keep the `unset` lines in the ChatGPT launcher. Desktop sessions can carry Codex, XDG and library-path variables that would redirect the app's Electron profile and Codex configuration away from the intended defaults.
- Keep the `deps` list in `helium.nix` in step with nixpkgs' google-chrome package, which it was copied from.
- Keep both checks on the Helium tarball: the pinned hash fixes the bytes, and gpgv against `helium-signing-key.asc` proves Helium published them. A signing-key rotation needs the new key committed.
- `rust-system-libs.nix` copies fixes from nixpkgs master for packages broken by nixos-unstable commit f4a03c0, which makes Rust -sys crates link system libraries that those packages never listed. tabiew gets sqlcipher and zstd from NixOS/nixpkgs@7e94c72bfc; each override throws once nixpkgs carries its fix.
