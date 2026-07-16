# AGENTS.md

## system info

the current machine runs nixos with a custom home-manager configuration. you can find the flake at ~/dotfiles/flake.nix.

tools for a variety of languages are installed in the home environment, but where necessary, project specific dependencies will be made available via a flake. the nix-direnv tool will typically be used to automatically start the flake's dev shell.

## subagents

Only spawn subagents when i ask you to

## Rules

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
