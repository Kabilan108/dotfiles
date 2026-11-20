# Render note templates by substitution and create notes exclusively

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

`:Today` creates the ISO-week log from the vault's `templates/neovim/weekly-log.md`. Vault templates are files that other tools can edit, and a second editor (Obsidian, another Neovim) may create the same note at the same time. Day arithmetic across a DST change can land on the wrong date when done at midnight.

## Decision

- `render` substitutes named `{{ key }}` placeholders only and errors on an unknown key. Templates never execute code.
- `weekly_context` does calendar arithmetic at local noon.
- `create` opens the file with `wx` (exclusive create), returns quietly on `EEXIST`, and removes a partial file on a short write.

## Consequences

Templates cannot carry logic; computed values must come from `weekly_context`. An existing note is never overwritten.

## Where

- `config/nvim/lua/custom/note_templates.lua` (`render`, `weekly_context`, `create`)
- `config/nvim/after/plugin/weekly_log.lua` (`Today`)
