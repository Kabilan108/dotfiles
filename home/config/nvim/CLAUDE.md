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