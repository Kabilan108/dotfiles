# Agents use 1Password through a per-host service account that agent-op keeps out of transcripts

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

jacurutu has a desktop session; sietch does not. Helium and Zen are not on 1Password's built-in browser list. The 1Password app checks the browser process's executable name and rejects `custom_allowed_browsers` unless it is root-owned and not a symlink. While `OP_SERVICE_ACCOUNT_TOKEN` is set, `op` signs in as the service account instead of as Tony.

Agents run as the token file's owner, so `agent-op` is not a security boundary; the service account's read-only vault scope limits what they can reach. The goal is to keep the token and secret values out of agent transcripts. `op` has parser behaviors that can leak the token:

- It expands `$VAR` and `${VAR}` in env files from its own environment, which holds the token. `X=${OP_SERVICE_ACCOUNT_TOKEN}` hands it to the command, and `X=op://${OP_SERVICE_ACCOUNT_TOKEN}/a/b` prints it in an error.
- In `op run`, a bare word before `--` is taken as the command and started with the token. A flag that takes a value consumes the next argument even when it is `--`.
- `op` can read a `--` as a flag's value, as in `whoami --config -- --debug`.

## Decision

- jacurutu enables the desktop app, which unlocks `op` and the browser extension. `/etc/1password/custom_allowed_browsers` lists helium, zen, zen-beta and .zen-beta-wrapped with an explicit mode, so it is a root-owned file rather than a store symlink.
- sietch enables only the `op` CLI; agents sign in with the host's service-account token.
- Each host's token is stored as `OP_SERVICE_ACCOUNT_TOKEN=…` in `~/.config/op-agents/env`, an agenix secret encrypted to the host key. It reaches only the `op` process that `agent-op` starts for one command, never a shell profile or the command `op` runs.
- Subcommands that print secret values are refused; secrets go to a command through `agent-op run --env-file=<file of op:// refs> -- <cmd>`.
- `check_env_file` refuses any env file containing `$`.
- `check_run` allows only op's own flags before `--`, and treats a value-taking flag as consuming the next argument, as op does.
- For `whoami` and list commands, which run nothing, `refuse_flags` checks every argument.
- Inherited `OP_*` variables are cleared with `${!OP_@}`, not `compgen`, because the bash that `env bash` finds may lack completion builtins.

## Consequences

Exporting the token in a profile would silently switch Tony's own `op` sessions to the service account. An op upgrade that changes its flag parser or env-file expansion needs the `agent-op` checks reviewed.

## Where

- `machines/jacurutu/default.nix` (`programs._1password-gui`, `environment.etc."1password/custom_allowed_browsers"`)
- `machines/sietch/default.nix` (`programs._1password`)
- `user.nix` (`secrets/op/agents.age`, the `op-agents/env` secret)
- `bin/agent-op` (`refuse_flags`, `check_env_file`, `check_run`, the `OP_*` cleanup loop)
