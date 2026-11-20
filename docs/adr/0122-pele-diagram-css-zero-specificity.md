# Pele diagram colours derive from the page and stay overridable

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

`diagrams.mts` injects one stylesheet into pages built with different palettes and light or dark backgrounds. Page authors sometimes need to restyle a diagram.

## Decision

The injected rules derive `--pele-muted`, `--pele-line`, `--pele-surface`, `--pele-surface-alt` and `--pele-border` with `color-mix` from `--pele-fg` and `--pele-bg`, which the mount script reads from the background and text colour where each diagram sits. The rules sit inside `:where(.pele-diagram)`, so they have zero specificity.

## Consequences

Any page rule that sets a `--pele-*` variable on `.pele-diagram` wins without `!important`. The injected CSS must keep its selectors inside `:where()`.

## Where

- `agents/skills/html-communication/scripts/diagrams.mts` (`CSS`, `MOUNT`)
