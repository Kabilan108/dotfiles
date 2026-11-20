# The CPA unit runs sandboxed, and preStart enforces logging and request rules

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

- `yq -i` in preStart fchowns its temp file to the current owner, which a `~@privileged` syscall filter would kill. Without capabilities, chown can't change owners anyway.
- Go's network interface lookups use `AF_NETLINK`. CPA's upstream providers are on the internet.
- CPA's v8 config key `observability.logs.logging-to-file` overrides the legacy top-level `logging-to-file` on load.
- A 404 `thread_not_found` ("No thread state was found") from a Claude request is a fault in that request, not a reason to cool down the account. Broader operator rules earlier in the list could match it first.
- Anthropic rejects a request that has both `thread` and `fallbacks`.

## Decision

- `SystemCallFilter` is `@system-service ~@privileged ~@resources @chown`, and `SystemCallErrorNumber=EPERM`, so a filtered call fails instead of killing the gateway mid-session.
- `RestrictAddressFamilies` allows `AF_UNIX`, `AF_INET`, `AF_INET6` and `AF_NETLINK`.
- On every start, preStart sets the v8 logging key to false and deletes the legacy key, whatever the file's layout. Logs go to stdout and the journal.
- preStart prepends a request-scoped error rule `{status 404, match thread_not_found / No thread state was found, action stop}` for Claude, after removing any copy of it.
- preStart prepends a payload filter that drops `fallbacks` from `claude-*` requests that have `thread`, keeping fallbacks on unthreaded calls.

## Consequences

- New preStart tools must not need privileged syscalls beyond `@chown`.
- The rules are reapplied on every start, so operator edits can add rules but can't remove these.
- `tests/cpa` runs the generated unit's sandbox and preStart.

## Where

- `modules/nixos/selfhost/cliproxyapi.nix` (`systemd.services.cliproxyapi.serviceConfig`, `preStart`)
