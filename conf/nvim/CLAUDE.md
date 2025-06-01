# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Neovim Configuration Architecture

This is a highly modular Lua-based Neovim configuration with advanced features for development and AI assistance.

### Core Structure
- **init.lua** - Entry point that loads all modules in order: options, lazy, keymaps, then config modules
- **lua/plugins.lua** - Lazy.nvim plugin specifications with inline configurations
- **lua/config/** - Configuration modules for LSP, completion, debugging, statusline, snippets, and autocmds
- **lua/custom/** - Custom integrations (droid AI plugin interface, telescope extensions)
- **plugins/droid/lua/droid.lua** - Local AI assistance plugin for streaming LLM completions

### Key Plugins and Features
- **LSP Configuration**: Multi-language support via `lua/config/lsp.lua` with servers for Lua, Python (pyright+ruff), TypeScript, Go, Rust, C/C++, Nix, Docker, and Biome
- **AI Integration**: Custom "droid" plugin with streaming completions from multiple LLM providers
- **Navigation**: Harpoon for file marking, Telescope for fuzzy finding, Oil for directory editing
- **Development Tools**: nvim-dap for debugging, gitsigns for Git integration, treesitter for syntax highlighting
- **Code Execution**: In-buffer execution for Lua and Python via custom executors in `keymaps.lua`
- **Completion**: nvim-cmp with LSP, snippets, and path completion

### AI Assistant Usage
The droid plugin provides streaming AI completions with these keybindings:
- `<leader>c` / `<leader>C` - GPT-4.1 (edit/help modes)
- `<leader>la` / `<leader>lA` - Claude Sonnet 4 (edit/help modes)  
- `<leader>g` / `<leader>G` - Gemini 2.0 Flash (edit/help modes)
- `<leader>lc` - Cancel streaming completion

**Environment Variables Required:**
- `OPENAI_API_KEY` for GPT-4.1 completions
- `OPENROUTER_API_KEY` for Claude Sonnet 4 and Gemini 2.0 Flash

### Code Execution
The configuration supports in-buffer code execution:
- Lua: `<leader>xl` (line) / `<leader>xs` (selection) / `<leader>xb` (buffer)
- Python: Uses pyrepl.nvim for interactive execution

### Development Workflow
1. Use `<leader>sf` for file finding, `<leader>sg` for live grep
2. Mark important files with Harpoon (`<leader>a` to add, `<leader>h` to view)
3. Use AI assistance for code editing and help via droid plugin
4. Debug with nvim-dap (keybindings prefixed with `d`)
5. Execute code snippets in-place for rapid prototyping

### Plugin Management
Uses lazy.nvim with local plugin support. The droid plugin is loaded from `plugins/droid/` as a local plugin.

### Custom Utilities
- **utils.lua** - Keymap utilities and executor setup functions
- **custom/telescope.lua** - Extended telescope functionality
- **config/snippets.lua** - LuaSnip configuration with friendly-snippets

### Important Implementation Details
- LSP capabilities are extended with nvim-cmp for autocompletion
- The droid plugin validates options and provides type annotations via EmmyLua
- Keymaps are centralized in `keymaps.lua` using utility functions
- Theme is Catppuccin Mocha with extensive integration configurations