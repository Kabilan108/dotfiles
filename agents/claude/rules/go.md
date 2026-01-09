---
globs: ["*.go"]
description: Go guidelines
---

## Go

### LSP

`gopls` with staticcheck, gofumpt, unused params analysis, and auto-complete for unimported packages.

### Preferences

- Follow standard Go conventions (gofmt, effective go)
- Handle errors explicitly; don't ignore them with `_`
- Use table-driven tests
- Keep interfaces small and focused
