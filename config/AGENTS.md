# Config notes

## .bashrc

- Key the tmux auto-attach on `SSH_TTY`, not `SSH_CONNECTION`. Remote tools start interactive login shells over SSH without allocating a terminal, and those must not exec tmux.
- Key the niri autostart on the real device (`tty` printing the tty1 path), not `XDG_VTNR`. `XDG_VTNR` leaks into tmux panes started without `DISPLAY`, and tty2 to tty6 must stay free for troubleshooting.
- Keep the `agy` wrapper function until agy stops gating keyring use on SSH variables. agy skips the system keyring whenever `SSH_*` variables are set, even when the user D-Bus session bus and an unlocked gnome-keyring are reachable, so SSH and tmux sessions would lose the sign-in that the desktop and T3 Code share.

## Vault tooling

- Keep `excluded_folders` in `moxide/settings.toml` and `EXCLUDED` in `nvim/lua/custom/vault_tags.lua` in sync. markdown-oxide matches each entry against directory basenames anywhere in the vault, and the tag picker's ripgrep glob mirrors that for the same four folders.

## Vendored files

- `t3code/icon.png` is the official Linux production icon, vendored from pingdotgg/t3code at commit 69db400b3cd6b1590d0dfdabf9857621a9089b39 for the jacurutu AppImage entry in `machines/jacurutu/default.nix`. A new upstream icon needs a manual re-vendor.
