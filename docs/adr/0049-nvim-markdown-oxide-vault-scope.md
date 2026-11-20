# Scope markdown-oxide to the vault and fill its client gaps

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

markdown-oxide is the vault's LSP. Markdown in ordinary git repos should stay LSP-free. markdown-oxide relies on file watching to see notes created outside Neovim. Its reference code lenses call a client-side command, `moxide.findReferences`, that Neovim does not ship. Its `excluded_folders` setting matches directory basenames anywhere in the vault.

## Decision

- `markdown_oxide` uses root markers `.obsidian` and `.moxide.toml` with `workspace_required = true`, and advertises dynamic registration for `didChangeWatchedFiles`.
- `lsp.lua` registers `vim.lsp.commands['moxide.findReferences']`, which loads the locations into the quickfix list.
- `moxide/settings.toml` excludes `archives`, `_archive`, `excalidraw` and `repos`. The vault tag picker's ripgrep glob excludes the same four folders.

## Consequences

The excluded folder list lives in two places and must stay in sync. If Neovim gains a native handler for the command, the local one can go.

## Where

- `config/nvim/lua/config/lsp.lua` (`custom_cfg.markdown_oxide`, `moxide.findReferences`)
- `config/moxide/settings.toml` (`excluded_folders`)
- `config/nvim/lua/custom/vault_tags.lua` (`EXCLUDED`)
