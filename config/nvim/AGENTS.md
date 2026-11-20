# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

### Development Workflow
```bash
# Test configuration changes
nvim --noplugin -u init.lua

# Check for Lua syntax errors
lua -c "loadfile('init.lua')"

# Plugin management (run from within Neovim)
:Lazy sync          # Update all plugins
:Lazy clean         # Remove unused plugins
:Lazy profile       # Check startup performance
```

### Testing Changes
```bash
# Start with minimal config for debugging
nvim -u NONE

# Test specific plugin
nvim -c "lua require('lazy').load({name='plugin-name'})"
```

## Architecture Overview

This is a modern Neovim configuration built around **Lazy.nvim** plugin management with modular organization and AI integration.

### Core Structure
- **init.lua** - Entry point that loads modules in order: options → lazy → keymaps → configs
- **lua/plugins.lua** - All plugin specifications with lazy loading configurations
- **lua/config/** - Specialized configuration modules (LSP, completion, debugging, AI)
- **lua/custom/** - Custom extensions and enhanced functionality
- **plugins/droid.nvim/** - Custom AI assistant plugin with streaming support

### Key Components

#### Plugin Management (Lazy.nvim)
- Plugins defined in `lua/plugins.lua` with sophisticated loading strategies
- Custom plugins supported in `/plugins/` directory
- Performance-optimized with lazy loading and caching

#### LSP Configuration (`lua/config/lsp.lua`)
- Centralized LSP server management with 10+ language servers
- Python: Pyright + Ruff combination for comprehensive analysis
- Auto-configuration with sensible defaults and enhanced capabilities

#### AI Integration (`lua/config/llm.lua` + `droid.nvim`)
- **Streaming AI responses** directly into buffers
- **Multiple AI providers** via OpenRouter (OpenAI, Anthropic, Google)
- **Two modes**: Edit (replaces selection) vs Help (appends response)
- **Model switching** via Telescope picker

#### Enhanced Navigation
- **Telescope** with custom live grep supporting `<query>  <glob>` syntax
- **Harpoon** for quick file navigation with numbered marks
- **Oil.nvim** for directory editing as buffers

### Development Patterns

#### Adding New Plugins
1. Add specification to `lua/plugins.lua`
2. Use lazy loading with appropriate events/keys/commands
3. Configuration can be inline or in separate `lua/config/` module

#### Custom Keymaps
- Use `utils.map()` function for consistent keymap creation
- Follow leader key conventions: `<leader>s` (search), `<leader>l` (LLM), `<leader>d` (debug)

#### LSP Server Addition
1. Add server name to `servers` table in `lua/config/lsp.lua`
2. Custom configuration via `server_configs[server_name]` if needed
3. Mason will auto-install missing servers

#### AI Assistance Workflow
- `<leader>ll` - Get help/explanation for current context
- `<leader>le` - Edit/replace selected text with AI suggestions
- `<leader>lm` - Switch between AI models via Telescope picker

### Special Features

#### Code Execution
- Execute Lua code directly in buffers with `<leader>x`
- Python code execution support for rapid prototyping

#### Language-Specific Settings
- Automatic indentation detection and language-specific configurations
- Use `utils.setup_custom_indentation()` for new languages

#### Performance Optimizations
- Lazy plugin loading reduces startup time
- Conditional configurations based on file types and events
- Smart LSP server activation only when needed

### File Organization Conventions
- **configs**: `lua/config/` for complex, standalone configurations
- **utilities**: `lua/utils.lua` for reusable helper functions
- **customizations**: `lua/custom/` for enhanced or modified plugin behaviors
- **plugins**: Local plugins in `/plugins/` directory with proper lua module structure

### Notable Dependencies
- **Lazy.nvim** - Plugin manager (auto-bootstrapped)
- **Mason** - LSP/DAP/linter installer
- **Telescope** - Fuzzy finder with extensive integrations
- **nvim-cmp** - Completion engine with multiple sources
- **droid.nvim** - Custom AI assistant (local plugin)

## Neovim vault notes

### markdown-oxide

- Keep `didChangeWatchedFiles` dynamic registration in the `markdown_oxide` entry of `lua/config/lsp.lua`. markdown-oxide relies on file watching to see notes created outside Neovim; the inotifywait backend comes from `home/shell.nix`.
- Keep the `moxide.findReferences` handler in `lua/config/lsp.lua`. markdown-oxide's reference code lenses call that client-side command and Neovim does not ship it; drop the handler if Neovim gains a native one.

### Link tools

- Exclude code examples in any tool that reads or rewrites links: collect fenced code, indented code, HTML and metadata ranges from the outer Markdown tree first, and resolve reference definitions from the outer document only. Fenced Markdown code injects its own Markdown parser, so injected trees contain links and definitions from examples (`lua/custom/moberg_link_references.lua`, `lua/custom/note_link_yank.lua`).
- Generate and reuse only reference IDs markdown-oxide can parse: at least two characters, no whitespace or brackets, no leading caret. markdown-oxide 0.25.12 sets those limits, which is why one-character IDs get a `link-` prefix; loosen the checks if a later release relaxes them.
- Keep `p` and `P` in `lua/custom/moberg_links.lua` putting through the expression register. That keeps counts, undo and dot-repeat, and leaves the source register and the system clipboard untouched; writing the formatted link to a register would not.
- Keep the `vim.paste` override buffering every chunk before it formats. Terminal pastes can split even a single URL across several chunks.
- Resolve a wikilink by asking markdown-oxide for the definition at the start of the link target, not at the cursor, and collapse the returned locations to one file. The cursor may sit on an alias or heading, and heading and block targets return several locations in the same file.

### Notes and templates

- Keep `render` in `lua/custom/note_templates.lua` to named placeholder substitution. Vault templates are files other tools can edit, so they must never execute code; computed values come from `weekly_context`.
- Keep `create` opening with exclusive create even though `:Today` checks for the file first. Obsidian or another Neovim can create the same note in between, and an existing note must never be overwritten.

### Prose layout

- `lua/custom/readable_width.lua` caps text width with an empty pad window on the right because Neovim has no native maximum width for soft-wrapped text.
- Keep all three pad autocmds. `focusable = false` only covers `<C-w>w`-style cycling, so `WinEnter` bounces directional moves such as `<C-w>l` off the pad; `QuitPre` closes the pad when `:q` hits the last real window; `WinClosed` covers `:close` and similar commands, which skip `QuitPre`.

### Task conventions

- Mirror the vault's checkbox statuses (`[/]`, `[-]`, `[!]`, `[?]`, `[~]`) in the render-markdown `checkbox.custom` table in `lua/plugins.lua`. They come from the coppermind vault's Obsidian Tasks config and its custom-checkboxes CSS snippet, so a change there needs the matching change here.
- `is_old_task` in `lua/custom/vault_tags.lua` skips inline checkbox lines and `#todo` lines because they are leftovers of the retired Obsidian Tasks setup and number in the hundreds; TaskNotes tags tasks in frontmatter. Change it if inline tasks return as a live convention.
