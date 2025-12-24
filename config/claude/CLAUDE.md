# CLAUDE.md

# system info

the current machine runs nixos with a custom home-manager configuration. you can find the flake at ~/dotfiles/flake.nix.

tools for a variety of languages are installed in the home environment, but where necessary, project specific dependencies will be made available via a flake. the nix-direnv tool will typically be used to automatically start the flake's dev shell.

# LSP Usage

Use the LSP tool to check for errors, explore code, and debug. The following operations are available:

## error checking
- after editing a file, use `hover` on modified symbols to verify types are correct
- use `findReferences` before deleting or renaming functions to understand impact

## code exploration
- `goToDefinition`: trace where a function/class/variable is defined - essential for understanding unfamiliar code
- `findReferences`: find all usages of a symbol across the codebase
- `documentSymbol`: get an overview of all functions, classes, and variables in a file
- `workspaceSymbol`: search for symbols by name across the entire project
- `goToImplementation`: find concrete implementations of interfaces or abstract methods

## debugging & understanding call flow
- `hover`: inspect types, documentation, and inferred information for any symbol
- `incomingCalls`: find all functions that call a specific function (useful for tracing how code is reached)
- `outgoingCalls`: find all functions called by a specific function (useful for understanding dependencies)
- `prepareCallHierarchy`: get call hierarchy information for a function

## practical workflows
- **before refactoring**: use `findReferences` to understand all affected code
- **debugging a bug**: use `incomingCalls` to trace how a function is reached, `goToDefinition` to follow the data flow
- **understanding new code**: use `documentSymbol` for file overview, `hover` for type info, `goToDefinition` to dive deeper

# Language-specific instructions

## `python`

- *lsp:* `ty` (type checking) + `ruff` (linting, formatting, import organization)
  - ty is extremely fast (10-60x faster than mypy/pyright) and provides full LSP support including completions with auto-import, rename refactoring, inlay hints, and signature help. see [ty documentation](https://docs.astral.sh/ty/).
- ruff handles linting and formatting. it disables import organization when used alongside ty.

### code style

- use type hints wherever possible. if a @pyproject.toml file is present, check the pythonversion and use the appropriate type hints.
- the only code that belongs in a try except block, is the code that is expected to raise and exception.

### package management with uv

this project uses the `uv` package manager for dependency management:

#### common commands:
- `uv add <package>`: add a new dependency to pyproject.toml
- `uv add --group dev <package>`: add to development dependencies
- `uv remove <package>`: remove a dependency
- `uv sync`: install/update dependencies from lockfile
- `uv run <script>`: execute scripts in the project environment
- `uv run python <file>`: run python files with project dependencies

#### development workflow:
- dependencies are defined in `pyproject.toml`
- use `uv sync` to ensure environment matches lockfile
- use `uv run` to execute code with proper dependencies
- add new dependencies with `uv add` rather than manual editing

## `typescript` | `javascript`

- *lsp:* `ts_ls` (language features) + `biome` (linting, formatting)
- always prefer typescript over plain javascript
- use bun for global package installs, and as the default package manager if others are not configured for the current project.

## `go`

- *lsp:* `gopls` with staticcheck, gofumpt, unused params analysis, and auto-complete for unimported packages. see [gopls documentation](https://go.dev/gopls/).

## `nix`

- *lsp:* `nixd` with nixpkgs option support for NixOS, home-manager, and flake-parts
- nixd integrates with the nix evaluation system for features like option completion and package completion. see [nixd documentation](https://github.com/nix-community/nixd).

## `lua`

- *lsp:* `lua_ls`
- write type annotations for function definitions
- make sure to define a type/class annotation for types/classes that are used in multiple places

# Tools

## `exa` - Code Documentation Search

Search for code documentation, examples, and implementations using Exa's Context API. Searches GitHub repos, official docs, and Stack Overflow.

```bash
exa "<query>" [--tokens <n>] [--json]
```

**When to use:** For library/framework documentation lookups where code examples are needed. More targeted than general web search for programming questions.

**Examples:**
```bash
exa "fastapi dependency injection"
exa "htmx hx-swap examples" --tokens 5000
```

**Requires:** `EXA_API_KEY` environment variable
