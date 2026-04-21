---
globs: ["*.go"]
description: Go guidelines
---

## Go

- `gopls` with staticcheck, gofumpt, unused params analysis, and auto-complete for unimported packages.
- use `go doc` and `gopls` for inspecting dependency documentation and APIs

### Preferences

- Follow standard Go conventions (gofmt, effective go)
- Handle errors explicitly; don't ignore them with `_`
- Use table-driven tests
- Keep interfaces small and focused
