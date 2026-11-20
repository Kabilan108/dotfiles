# Sessionizer notes

## Remote access

- Keep `bin/sessionizer` (repo root) trying both the per-user profile under /etc/profiles and ~/.nix-profile. Other hosts and `docs/tleilax-install.md` call `"$HOME/bin/sessionizer"`, and the two candidates cover both Home Manager profile layouts.
- Wrap the binary with `--suffix PATH`, not `--prefix`, in `default.nix`. The picker must talk to the tmux server with the user's own tmux, while under `deploy-gate`'s bare PATH the suffix still supplies git for directory status.
- Use `SESSIONIZER_REMOTE_PROGRAM` only in tests. Gated hosts allow exactly `"$HOME/bin/sessionizer" --inventory` (`modules/nixos/deploy/gate.sh`), so any other spelling is refused there.

## Proxy sessions

- Change the `sessionizer-proxy` key table in `config/.tmux.conf` and `proxyKeyTable` in `proxy.go` together, and mirror the binding in `e2e/setup.sh`. The table must hold only `M-s`, so every other key reaches the remote tmux.
- Treat `exitNoProxyClient` (3) as a protocol between hosts. Hosts rebuild at different times, so changing the value makes an origin on the old build report an error instead of starting a new proxy.
- Name a proxy for `set-option` and `respawn-pane` through `optionTarget`, which returns `=<name>:`. Those tmux commands take a pane target for `-t`, and the exact-match `=` only works there with the trailing colon.
- Restart a stale proxy with `respawn-pane -k`, not by killing and recreating the session. A client already showing the proxy stays on it.

## Git reads

- Keep `gitBudget` (5 s, `dirs.go`) well under the 15 s ssh timeout in `refreshHost` (`fleet.go`). `--inventory` answers another host's picker inside that timeout, and a cold cache on a host with many repositories can exceed it; repositories the budget skips are read on a later run.
- Keep `gitCacheTTL` (10 minutes) even though entries are keyed by fingerprint. The fingerprint stats HEAD, index and ref files, and an edit to a tracked file changes none of them until something refreshes the index.
- Bump `gitCacheVer` when the cache entry format changes. Readers discard a file with another version.

## Compatibility with the Python picker

- Add inventory fields as optional (`omitempty`) and keep `windows` and `attached` written as strings. Sessionizer was a Python script driving fzf until the Go rewrite on 2026-11-08, hosts rebuild at different times, and the Python picker reads those six fields with those types. Once every host runs the Go build, the string encoding, `flexString` and the `activity` fallback in `InventorySession.Recency` can go.
- Keep the `session:<host>:<name>` and `path:<host>:<path>` favorite keys unless the favorites file is migrated. They are the Python picker's format.

## End-to-end tests

- Run `e2e/run.sh` with the built binary as its argument after changing the picker, proxy or ssh arguments. It builds three tmux servers on private sockets (driver terminal, local origin, remote host behind a fake ssh) and never touches your own tmux; `go test` does not run it.
- Update `list_column`, `row_tops` and `first_row` in `e2e/run.sh` when changing row layout, separators or section headers in `view.go`. The checks scrape the driver's screen and assume the list is the column between the popup border and the preview border, two lines per row, with the first row's top line in a HERE section right under the rule below the prompt.
