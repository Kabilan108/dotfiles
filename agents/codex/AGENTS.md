# AGENTS.md

## system info

the current machine runs nixos with a custom home-manager configuration. you can find the flake at ~/dotfiles/flake.nix.

tools for a variety of languages are installed in the home environment, but where necessary, project specific dependencies will be made available via a flake. the nix-direnv tool will typically be used to automatically start the flake's dev shell.

## Rules

### Comment Policy

#### Unacceptable Comments

- Comments that repeat what the code does
- Commented-out code (delete it)
- Obvious comments ("increment counter")
- Comments instead of good naming
- Comments about updates to old code ("<- now supports xyz")

#### Principle

Code should be self-documenting. If you need a comment to explain WHAT the code does,
consider refactoring to make it clearer.

### Nix

#### Preferences

- Use `let ... in` for local bindings
- Prefer `lib` functions over reimplementing logic
- Use `mkOption` with proper types for module options
- Format with `nixfmt` or `alejandra`

### Python

#### LSP

`ty` for type checking, `ruff` for linting, formatting, and import organization.

You can call both via `uv run [ty|ruff]` if you're working in a project with a `pyproject.toml` file. Otherwise, you can run `uvx [ty|ruff]`.

Before formatting with ruff, check if the project already uses it (look for `[tool.ruff]` in `pyproject.toml` or a `ruff.toml`). Don't introduce ruff formatting to projects using other formatters.

#### Preferences

- Add type hints to all function signatures and class attributes.
- Check `pyproject.toml` for the target Python version and use appropriate type syntax
- Only wrap code in try/except if that specific code is expected to raise an exception
- Use `pathlib.Path` for file handling instead of `os.path`, `os.makedirs`, `open()`, etc. — unless the project already uses `os.*` patterns consistently

#### Package Management (uv)

Use `uv` for dependency management:

| Command | Purpose |
|---------|---------|
| `uv add <pkg>` | Add dependency |
| `uv add --group dev <pkg>` | Add dev dependency |
| `uv remove <pkg>` | Remove dependency |
| `uv sync` | Install from lockfile |
| `uv run <cmd>` | Run in project environment |
| `uvx <cmd>` | Run arbitrary python executable without installing |

Always use `uv add` to add dependencies rather than editing `pyproject.toml` manually.

### TypeScript / JavaScript

#### Preferences

- Always use TypeScript over plain JavaScript
- Use `bun` for global package installs and as the default package manager when no other is configured
- Prefer `const` over `let`; avoid `var`
- Use explicit return types on exported functions
- Prefer `interface` over `type` for object shapes

## Browser Tools

- Use `agent-browser` for most interactive browser work. It is the default choice for agent-driven exploration, iterative UI interaction, screenshots, and stateful sessions. Prefer it when you want AI-friendly page discovery via `snapshot` and stable element refs like `@e1`.
- Use `dev-browser` when you need programmable browser automation with Playwright-style APIs. Prefer it for scripted multi-step flows, reusable inspection scripts, or cases where `snapshotForAI()` plus direct `page` methods are the best fit.
- On this machine, `dev-browser` may work better with `--connect` to an existing Chrome/CDP session than by launching its bundled browser directly.
