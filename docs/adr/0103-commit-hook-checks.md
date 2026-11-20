# Commit hooks run per-file statix and a narrowed qmllint syntax check, with narrow lint exceptions

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

prek passes several staged files to one hook invocation. `statix check` accepts one target per invocation. statix flags dotted option declarations (`repeated_keys`) and the `{ ... }:` signature (`empty_pattern`), both conventional in NixOS and Home Manager modules. Qt 6.12 `qmlformat` silently fails on ordinary properties named `id`. qmllint's duplicate-id diagnostics also flag ids in separate implicit delegate scopes, which are not real duplicates.

## Decision

- `scripts/statix-check` loops over its arguments and runs `statix check` once per file, failing if any run fails. statix disables `repeated_keys` and `empty_pattern`.
- The `qmlformat` hook excludes the files that trip the `id` bug; the `qml-syntax` hook still checks them.
- `scripts/qml-check syntax` runs qmllint with `--only-explicit-categories` and enables only `syntax` and `syntax.id-quotation` as errors. Duplicate-id checking stays in the full manual `lint` mode.

## Consequences

The commit hook does not catch real duplicate ids; the manual `qmllint` hook must. If statix gains multi-target support, the loop can go. Retry formatting the excluded QML files after a Qt update and drop the exclusion once qmlformat handles them.

## Where

- `scripts/statix-check`
- `scripts/qml-check` (`syntax` mode)
- `prek.toml` (hooks that call them, `qmlformat` hook `exclude`)
- `statix.toml` (`disabled`)
