# Edit vault notes as soft-wrapped prose at a capped width

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Obsidian vault notes are prose. Soft-wrapping on a wide screen gives long lines; Neovim has no native max text width for wrapped display. `focusable = false` on a window only covers `<C-w>w` and similar cycling, not directional moves such as `<C-w>l`. `:close` and similar commands skip `QuitPre`.

## Decision

- Vault markdown soft-wraps at word boundaries, and `j`/`k` move by screen line without a count. With a count, they move by real lines so relative line numbers stay usable.
- `readable_width` caps text at `WIDTH` (100) columns by opening an empty, unfocusable pad window on the far right of the tab that takes the spare columns. Buffers opt in with `vim.b.readable_width`.
- A `WinEnter` autocmd bounces focus off the pad. `QuitPre` closes the pad when `:q` hits the last real window, and `WinClosed` closes the tab or quits when only the pad remains.

## Consequences

The pad must never become the last window or a focus target; both autocmds have to stay.

## Where

- `config/nvim/after/ftplugin/markdown.lua`
- `config/nvim/lua/custom/readable_width.lua` (`open`, `sync`, autocmds)
