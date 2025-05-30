# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Neovim Configuration Overview

This is a comprehensive Neovim configuration built with Lua, featuring modern development tools and LSP integration.

### Core Architecture
- **Entry Point**: `init.lua` loads options, lazy plugin manager, keymaps, and plugin configurations
- **Plugin Management**: Lazy.nvim with auto-installation and lazy loading
- **Configuration Structure**: Modular setup with separate files for options, keymaps, and plugin configs
- **Theme**: Catppuccin Mocha with extensive plugin integrations

### Plugin Configuration Files
- `lua/config/editor.lua` - LSP servers, autocompletion, and code execution setup
- `lua/config/debug.lua` - DAP (Debug Adapter Protocol) configuration
- `lua/config/harpoon.lua` - Quick file navigation setup
- `lua/config/lualine.lua` - Status line configuration
- `lua/config/telescope.lua` - Fuzzy finder customization
- `lua/keymaps.lua` - All key mappings including LSP bindings

### Language Server Setup
Located in `lua/config/editor.lua` with these LSPs:
- **JavaScript/TypeScript**: ts_ls + biome (formatting/linting)
- **Python**: pyright (type checking) + ruff (linting/formatting) 
- **Go**: gopls with staticcheck, gofumpt, and enhanced completion
- **Rust**: rust_analyzer with default configuration
- **C/C++**: clangd with semantic highlighting and compile commands
- **Lua**: lua_ls optimized for Neovim development
- **Nix**: nixd + nixfmt for language support and formatting
- **Docker**: dockerls for Dockerfile support

### Key Features
- **File Navigation**: Oil.nvim for buffer-like directory editing (keymap: `-`)
- **Fuzzy Finding**: Telescope with custom file/grep/buffer searches
- **Autocompletion**: nvim-cmp with LSP, snippets, and path sources
- **Code Execution**: PyREPL integration for Python development
- **Git Integration**: Gitsigns for inline git status and operations
- **Debugging**: Full DAP setup with UI and virtual text
- **Custom Plugins**: Local ghola plugin and typing practice (typr)

### Development Workflow
1. Use `<leader>sf` to find files, `<leader>sg` for live grep
2. Navigate with LSP: `gd` (definition), `gr` (references), `gi` (implementation)
3. Code actions: `<leader>ca`, rename: `<leader>rn`, format: `<leader>fb`
4. Execute Python code with `<leader>xp` in visual mode
5. Access terminal with `<Ctrl-`>`, exit with `<Ctrl-n>`

### Custom Keymaps
- **Leader Key**: `<space>` for most operations
- **LSP Navigation**: Standard `gd`, `gr`, `gi`, `gt` pattern
- **Diagnostics**: `[d`/`]d` for navigation, `<leader>e` for float, `K` for hover
- **Telescope**: `<leader>sf/sg/sh/sk/rs/sr` for various searches
- **Buffer/Tab Management**: `bn/bp` (buffer nav), `nt/tn/tp` (tab nav)
- **Window Resizing**: `<Ctrl-Alt-t/s/w/n>` for directional resizing

### Editing Behavior
- **Indentation**: 2 spaces default, language-specific overrides (Python/Go: 4, Go uses tabs)
- **Folding**: Indent-based method with all folds open initially
- **Visual Aids**: Relative line numbers, 88-character ruler, visible whitespace
- **Clipboard**: System clipboard integration via `unnamedplus`
- **Auto-formatting**: Enabled for supported languages via LSP

### Local Plugins
- **Ghola**: Custom plugin located at `plugins/ghola/` 
- **PyREPL**: Execute Python code in terminal splits
- **Custom Configurations**: Stored in `lua/custom/` directory