# Mirror the vault's task conventions in Neovim

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The coppermind vault defines custom checkbox statuses in its Obsidian Tasks config and `custom-checkboxes.css` snippet: `[/]`, `[-]`, `[!]`, `[?]` and `[~]`. Task tracking has moved to TaskNotes, which tags tasks in frontmatter. Inline checkbox items and `#todo` lines come from the retired Obsidian Tasks setup and number in the hundreds.

## Decision

- render-markdown.nvim renders the same custom checkbox statuses the vault defines.
- The vault tag picker skips inline checkbox lines and `#todo` lines, so a tag surfaces notes and TaskNotes tasks. Nested tags count toward their parents as in Obsidian: `#moberg` also finds `#moberg/clara`.

## Consequences

A change to the vault's checkbox statuses needs the matching change in `plugins.lua`. If inline tasks return as a live convention, `is_old_task` must change.

## Where

- `config/nvim/lua/plugins.lua` (render-markdown `checkbox.custom`)
- `config/nvim/lua/custom/vault_tags.lua` (`is_old_task`, tag normalization)
