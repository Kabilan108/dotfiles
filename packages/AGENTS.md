# Packages notes

- `security-overrides.nix` pins TeamViewer to 15.83.3 for upstream advisory TV-2026-1011, which fixes CVE-2026-111585 and CVE-2026-92372 in Linux versions >= 15.83. The pinned Debian source has hash `sha256-8xMNJO2+JZ71ukalQ8bVqCOuoqFPUzg08uSEv9ymiQk=`. Remove the override once nixpkgs ships TeamViewer >= 15.83; if the overlay is then empty, remove its file and both imports in `flake.nix`.
- Only extract the ChatGPT desktop and Grok Bot Debian packages (`chatgpt-desktop.nix`, `grok-bot.nix`): no ELF, ASAR, launcher or feature patches, and never run their dpkg maintainer scripts, which add an apt source and an AppArmor profile. A fix that needs patching goes upstream or into our launcher.
- Keep the `unset` lines in the ChatGPT launcher. Desktop sessions can carry Codex, XDG and library-path variables that would redirect the app's Electron profile and Codex configuration away from the intended defaults.
- Keep the `deps` list in `helium.nix` in step with nixpkgs' google-chrome package, which it was copied from.
- Keep both checks on the Helium tarball: the pinned hash fixes the bytes, and gpgv against `helium-signing-key.asc` proves Helium published them. A signing-key rotation needs the new key committed.
