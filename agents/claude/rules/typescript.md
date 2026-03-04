---
globs: ["*.ts", "*.tsx", "*.js", "*.jsx"]
description: TypeScript and JavaScript guidelines
---

## TypeScript / JavaScript

### LSP

`ts_ls` for language features, `biome` for linting and formatting.

### Preferences

- Always use TypeScript over plain JavaScript
- Use `bun` as the default package manager for new projects. In existing projects, detect the configured package manager (look for `bun.lock`, `pnpm-lock.yaml`, or `package-lock.json`) and use that (`bun`, `pnpm`, or `npm`)
- Prefer `const` over `let`; avoid `var`
- Use explicit return types on exported functions
- Prefer `interface` over `type` for object shapes
