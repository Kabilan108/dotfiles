# AGENTS.md

# system info

the current machine runs nixos with a custom home-manager configuration. you can find the flake at ~/dotfiles/flake.nix.

tools for a variety of languages are installed in the home environment, but where necessary, project specific dependencies will be made available via a flake. the nix-direnv tool will typically be used to automatically start the flake's dev shell.

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

# Browser Tools

- Use `agent-browser` for most interactive browser work. It is the default choice for agent-driven exploration, iterative UI interaction, screenshots, and stateful sessions. Prefer it when you want AI-friendly page discovery via `snapshot` and stable element refs like `@e1`.
- Use `dev-browser` when you need programmable browser automation with Playwright-style APIs. Prefer it for scripted multi-step flows, reusable inspection scripts, or cases where `snapshotForAI()` plus direct `page` methods are the best fit.
- On this machine, `dev-browser` may work better with `--connect` to an existing Chrome/CDP session than by launching its bundled browser directly.

## Knowledge Vault

The coppermind vault (~/notes, /vault/notes/coppermind) is the knowledge base for projects and tasks. When working in a repo mapped by ~/notes/04-projects/manifest.md (notably /vault/work/moberg/*), read that project's brief.md + tasks.md for context. Vault write rules: the `coppermind` skill (~/dotfiles/agents/skills/coppermind/SKILL.md) — 04-projects/ is agent-writable (briefs/people via proposals), 00-bin/01-logs/02-moberg are Tony's zones.

# Shell & CI discipline

- Never pipe verification commands (tests, linters, builds) through filters that mask exit codes (`| tail`, `| grep`). Capture output to a file and check the exit code explicitly: `cmd > /tmp/out 2>&1; echo "exit=$?"`. A masked failure has caused a broken commit to be pushed.
- When watching a CI/workflow run, capture the run ID at trigger time and poll that ID. Never poll "latest run" (`gh run list --limit 1`) — a just-triggered push races the previous run and you will report the wrong result.
- When an applicable `.envrc` exists, run project commands through `direnv exec "$PWD" ...`.
