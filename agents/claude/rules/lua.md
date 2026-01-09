---
globs: ["*.lua"]
description: Lua guidelines
---

## Lua

### LSP

`lua_ls` for language features and diagnostics.

### Preferences

- Add type annotations to all function definitions using LuaLS annotation syntax
- Define `---@class` annotations for tables used as types in multiple places
- Use `local` for all variables unless global scope is explicitly needed
- Prefer `vim.tbl_*` functions when working in Neovim configs
