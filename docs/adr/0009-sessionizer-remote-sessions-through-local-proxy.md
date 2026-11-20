---
paths:
  - packages/sessionizer/proxy.go
  - config/.tmux.conf
---

# Show remote tmux sessions through one local proxy session per host

The picker switches between local and remote tmux sessions. Each remote host gets one local session, `sessionizer-<host>`, whose single pane runs `ssh -t <host>` into a tmux client of the remote server; switching remote sessions moves that remote client over the already open login connection. Nesting a remote tmux in an ordinary local window lost because both layers would capture the prefix, and a new ssh per switch lost because each one needs a security key touch.

## Consequences

The proxy session has no prefix and a key table holding only `M-s`, so the local tmux cannot be driven from inside it except through the picker. The origin and the remote host speak a small command protocol (`--proxy-attach`, `--proxy-switch`, `--proxy-current`, exit status 3), so both ends must stay compatible across staggered rebuilds.
