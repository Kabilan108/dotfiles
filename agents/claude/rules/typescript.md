---
globs: ["*.ts", "*.tsx", "*.js", "*.jsx"]
description: TypeScript and JavaScript guidelines
---

## TypeScript / JavaScript

### LSP

`ts_ls` for language features, `biome` for linting and formatting.

### Preferences

- Always use TypeScript over plain JavaScript
- Use `bun` for global package installs and as the default package manager when no other is configured
- Prefer `const` over `let`; avoid `var`
- Use explicit return types on exported functions
- Prefer `interface` over `type` for object shapes
