# Every fleet host shares one shell base, with store copies on tleilax

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

bash, tmux and the host colors should match on every host. sietch and jacurutu have `~/dotfiles` checkouts; tleilax has none. tpm reads `@plugin` lines from files that `~/.tmux.conf` sources. tmux-continuum must load last.

## Decision

- With `fromCheckout`, the files link into the checkout and tpm fetches the plugins. Without it (tleilax), Home Manager installs Nix store copies and loads the plugins from nixpkgs.
- `tmuxPlugins` is an ordered list ending with continuum, rendered either as tpm `@plugin` lines or as `run-shell` lines.

## Consequences

New plugins go before continuum. A host without a checkout gets config changes only on rebuild.

## Where

- `modules/home/shell-base.nix` (`configFile`, `tmuxPlugins`, `tpmPlugins`, `nixpkgsPlugins`)
