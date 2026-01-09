---
globs: ["*.nix", "flake.nix", "flake.lock"]
description: Nix and NixOS guidelines
---

## Nix

### LSP

`nixd` with nixpkgs option support for NixOS, home-manager, and flake-parts. Integrates with nix evaluation for option and package completion.

### Preferences

- Use `let ... in` for local bindings
- Prefer `lib` functions over reimplementing logic
- Use `mkOption` with proper types for module options
- Format with `nixfmt` or `alejandra`

### NixOS MCP Tool

Use the `mcp__nixos__nix` tool to query packages and options:
- `action: "search"` to find packages or options
- `action: "info"` for detailed package/option information
- `source: "home-manager"` for home-manager options
- `source: "darwin"` for nix-darwin options
