# Remote sessions show through one local proxy session per host

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The picker switches between local and remote tmux sessions. Nesting a remote tmux inside a local window would capture keys twice, and starting a new ssh for every switch would ask for a security key touch each time.

## Decision

- A proxy is a local tmux session named `sessionizer-<host>` whose one pane runs `ssh -t <host> sessionizer --proxy-attach`, a tmux client of the remote server. The local tmux stays the outer layer.
- The proxy's key table is `sessionizer-proxy`, which holds only `M-s` (bound in `config/.tmux.conf`), and its prefix is `None`, so every other key, the prefix included, reaches the remote tmux.
- `proxyAttach` runs on the remote host, records its pid and terminal in a private runtime directory so `--proxy-switch` can find the client, then execs `tmux attach`.
- Switching to a remote session runs `--proxy-switch` over the open login connection, which moves that remote client, then moves the local client to the proxy. `--proxy-switch` exits with status 3 (`exitNoProxyClient`) when the host has no live proxy client for this origin, and the origin then starts a new proxy.
- `startProxy` restarts a stale proxy's pane in place with `respawn-pane -k`, so a client already showing it never leaves.
- A failed ssh (no touch, host down) keeps its pane through `remain-on-exit failed-key` so the error shows. The proxy has no prefix, so any key, `M-s` included, closes it.
- `optionTarget` names the proxy as `=<name>:` because tmux commands such as `set-option` take a pane target for `-t`, and the trailing colon makes the exact session match work there.
- `proxyShows` asks the remote host, through `--proxy-current` over the login connection, which session its proxy client shows. That can differ from the last session the picker chose, and can be newer than the origin's cached inventory.

## Consequences

- The `sessionizer-proxy` key table in `config/.tmux.conf` and `proxyKeyTable` must stay in sync.
- Exit status 3 is a protocol between hosts; other failures (except ssh's 255) surface as errors instead of starting a new proxy.
- A session named `sessionizer-<host>` without the `@sessionizer-proxy-host` marker is refused, not reused.

## Where

- `packages/sessionizer/proxy.go` (`openRemote`, `startProxy`, `optionTarget`, `proxyAttach`, `proxySwitch`, `proxyCurrent`, `proxyShows`, `exitNoProxyClient`)
- `config/.tmux.conf` (`sessionizer-proxy` key table)
