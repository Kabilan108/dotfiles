# Neovim Configuration Guidelines

## Commands
- Formatting: `<leader>fb` - Format current buffer with LSP
- Trim whitespace: `<leader>tw` - Remove trailing whitespace
- Syntax check: Use LSP diagnostics (`<leader>e` to show error)

## Code Style Guidelines
- Indentation: Use 2 spaces (configured via indent-blankline)
- Naming: Use snake_case for variables and functions
- Functions: Use local functions with descriptive names
- Keymaps: Use map() helper with descriptive comments
- Imports: Group imports by type, prefer local requires
- Error handling: Use nvim diagnostics for error reporting
- Plugin config: Follow existing pattern of { plugin, config = function() ... end }
- Formatting: gofumpt enabled for Go files
- Linting: LSP-based linting with configured servers

## Treesitter
Configured with auto-install and highlight/indent for:
- bash, lua, markdown, python