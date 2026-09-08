# AGENTS.md

## Local Machine

This machine runs nixos with home-manager. The flake is managed at ~/dotfiles. Various dev tools are installed in the base environment (e.g. uv, pnpm, npm, pythonk, etc); if you need additional dependencies, use `nix-shell -p` to grab them. Execute commands via the flake dev shell if one is present for the current project. For new projects, set up a flake devshell with the necessary dependencies. Where applicable, `nix-direnv` may auto-load a project's dev shell.

## Language-specific instructions

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

# Browser Tools

- Use `agent-browser` for most interactive browser work. It is the default choice for agent-driven exploration, iterative UI interaction, screenshots, and stateful sessions. Prefer it when you want AI-friendly page discovery via `snapshot` and stable element refs like `@e1`.

# Shell & CI discipline

- Never pipe verification commands (tests, linters, builds) through filters that mask exit codes (`| tail`, `| grep`). Capture output to a file and check the exit code explicitly: `cmd > /tmp/out 2>&1; echo "exit=$?"`. A masked failure has caused a broken commit to be pushed.
- When watching a CI/workflow run, capture the run ID at trigger time and poll that ID. Never poll "latest run" (`gh run list --limit 1`) — a just-triggered push races the previous run and you will report the wrong result.
- When an applicable `.envrc` exists, run project commands through `direnv exec "$PWD" ...`.
