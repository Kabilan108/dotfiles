# flake-lock-verify follows Nix's own input resolution rules

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

`bin/flake-lock-verify` checks a flake-update PR's `flake.lock` against what each declaring `flake.nix` allows (see `docs/flake-update.md`). To avoid false passes and failures it has to resolve inputs the way Nix does:

- Nix ignores overrides for inputs the flake doesn't declare.
- Nix may record a `follows` chain already resolved one step.
- Paths below a `follows` alias are instantiated in the followed flake's context, so the root's override on the alias is ignored. For example, an `alias` that follows `home-manager` reuses home-manager's own `old` input.
- When the root overrides a transitive input's source, the `flake = false` flag still comes from the declaring flake.

## Decision

- An override for an undeclared input yields no expectation.
- For `follows`, the verifier compares where the declared and locked paths lead, and checks the target's own binding separately.
- Bindings are checked shallowest first, each in its own context, so a child sees the final status of the binding above it. Paths below a `follows` alias are checked where Nix instantiates them.
- The `flake` flag comes from the input's own declaration.

## Consequences

A change in Nix's lock semantics can make the verifier pass something Nix resolves differently. The tests in `tests/test_flake_lock_verify.py` pin each rule above.

## Where

- `bin/flake-lock-verify` (override resolution, the `follows` comparison, the per-binding check loop)
- `tests/test_flake_lock_verify.py` (`test_paths_below_a_follows_alias_use_the_followed_context`, `test_flake_flag_comes_from_the_own_declaration`)
