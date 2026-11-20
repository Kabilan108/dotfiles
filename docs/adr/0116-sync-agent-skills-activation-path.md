# sync-agent-skills runs with Home Manager activation's minimal PATH

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Home Manager activation runs `bin/sync-agent-skills` (`home/shell.nix`) with a PATH that has no `awk`, `sed` or `hostname`. The activation snippet prepends `jq`. Host data comes from `~/.config/fleet/fleet.json`, which `modules/home/fleet.nix` generates from `lib/fleet.nix`.

## Decision

- The script reads skill frontmatter with Bash builtins only.
- It takes the host list and its own host name from `fleet.json` with `jq`, not from `hostname`.
- `tests/agent-tools/test_skill_sync.py` puts a `hostname` that exits 127 first on PATH to prove activation does not depend on it.

## Consequences

Any new external command in the script must be on the activation PATH or added in `home/shell.nix`.

## Where

- `bin/sync-agent-skills` (`fleet_json` lookup, `fleet_hosts_field`)
- `home/shell.nix` (activation call)
- `tests/agent-tools/test_skill_sync.py`
