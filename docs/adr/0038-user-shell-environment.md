# The user environment pins CA trust, keeps credentials out of shared caches and turns off Atuin for Teams

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

- Clients that ship their own roots (certifi, pip) miss NixOS trust-store fixes. Deno ignores `SSL_CERT_FILE` and otherwise uses its bundled roots.
- `HF_HOME` is a model cache shared with services such as siren.
- Atuin for Teams uploads a server-readable copy of all shell history and every agent thread, beside the end-to-end encrypted sync.
- Neovim's LSP workspace file watching on Linux uses an inotifywait backend.

## Decision

- `SSL_CERT_FILE`, `REQUESTS_CA_BUNDLE` and `PIP_CERT` point at `/etc/ssl/certs/ca-certificates.crt`, and `DENO_TLS_CA_STORE=system`, in both the session and systemd user environments.
- `HF_TOKEN_PATH` keeps Hugging Face login credentials in `~/.config/huggingface/token`, outside `HF_HOME`.
- `teams.enabled = false` in Atuin.
- Neovim gets `inotify-tools` as an extra package.

## Consequences

Trust-store fixes reach those clients on rebuild. Re-enabling Atuin for Teams would expose shell history and agent threads to the server.

## Where

- `home/shell.nix` (`systemCaEnv`, `HF_TOKEN_PATH`, `programs.atuin.settings.teams`, `programs.neovim.extraPackages`)
