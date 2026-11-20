# The dev-checkouts plugin ships disabled and reaches sietch through a forced-command key

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The Stillsuit dev-checkouts plugin on jacurutu shows sietch's Moberg development checkouts and can pause or resume one. It is Moberg work tooling. A forced SSH command runs with no login environment, and loading the checkout's direnv/nix shell costs seconds per poll. The service polls `dev co list --json` on sietch, and every successful poll clears `lastError`.

## Decision

- The plugin is declared with `enable = false`; the "moberg" Stillsuit runtime profile enables it.
- The `moberg-status@jacurutu` key is authorized on sietch outside the access matrix, with `command="…/moberg-dev-checkouts",restrict,from="100.64.0.0/10"`.
- `moberg-dev-checkouts` accepts only `status`, `pause NAME` and `resume NAME`, from `SSH_ORIGINAL_COMMAND` or argv, and validates NAME. It runs the checkout's editable devcli venv (`./.cache/devcli/bin/dev`) directly instead of the dev shell. Docker's endpoint comes from `~/.config/moberg/docker.toml`.
- `stillsuit-dev-checkouts` sends only the request words over SSH, defaulting to `status`, with batch mode, no connection sharing and short timeouts.
- A failed pause or resume is stored in `actionError`, not `lastError`, so the next successful poll does not erase it before the user sees it.

## Consequences

The key can list checkouts and pause or resume one by name, and nothing else. The helper and `moberg-dev-checkouts` must agree on the request grammar. If the devcli venv moves or needs the dev shell's environment, the command breaks. The plugin stays off unless the profile is active. Views must show both error fields.

## Where

- `home/services/moberg.nix` (`devCheckouts`, `moberg-dev-checkouts`)
- `lib/fleet.nix` (`extraAuthorizedKeys.sietch`, `mobergStatusKey`)
- `home/desktop/wayland/quickshell/default.nix` (`devCheckoutsHelper`, `builtinPlugin "dev-checkouts"`)
- `packages/stillsuit-shell/src/plugins/builtin/dev-checkouts/Service.qml` (`actionError`, `lastError`)
