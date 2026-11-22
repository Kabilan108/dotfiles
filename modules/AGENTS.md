# Modules notes

- File dialogs open in scout through three pieces that must change together: `nixos/desktop-wayland.nix` installs `pkgs.scout` as a portal backend and sets `GDK_DEBUG=portals` and `GTK_USE_PORTAL=1`, and `home/scout.nix` routes `FileChooser` to scout. GTK apps use their built-in dialog unless told to use the portal; GTK 4 and recent GTK 3 follow `GDK_DEBUG=portals`, older GTK 3 follows `GTK_USE_PORTAL=1`.
- The user portal config in `home/scout.nix` shadows the one niri packages, so it restates niri's defaults, changes `FileChooser` to scout, and drops the uninstalled `oo7-portal` from `Secret`. Changes to niri's packaged portal defaults do not reach it; compare the two after a niri update that touches portals.
