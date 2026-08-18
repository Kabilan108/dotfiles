# AGENTS.md

## system info

the current machine runs nixos with a custom home-manager configuration. you can find the flake at ~/dotfiles/flake.nix.

tools for a variety of languages are installed in the home environment, but where necessary, project specific dependencies will be made available via a flake. the nix-direnv tool will typically be used to automatically start the flake's dev shell.

## subagents

Only spawn subagents when i ask you to

## skills

Shared skill docs live in `~/dotfiles/agents/skills/<name>/SKILL.md`. Read the relevant one BEFORE starting these task shapes — transcript audits show these are routinely missed:

| Task shape | Skill |
|---|---|
| Reviewing a diff, staged changes, or a branch | `review-swarm` |
| Discussing/planning a feature before implementing | `pair-programmer` |
| Creating commits from working-tree changes | `commit` |
| Long multi-phase session hitting a phase boundary | `handoff` |
| Driving a browser or validating rendered UI | `agent-browser` (Helium profile: `helium-browser-use`) |
| Building or restyling UI | `frontend-design` |
| Running servers/long jobs, coordinating panes | `tmux` |
| Anything on another fleet machine (sietch, tleilax) | `fleet` |

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

## Knowledge Vault

The coppermind vault (~/notes, /vault/notes/coppermind) is the knowledge base for projects and tasks. When working in a repo mapped by ~/notes/04-projects/manifest.md (notably /vault/work/moberg/*), read that project's brief.md + tasks.md for context. Vault write rules: ~/dotfiles/agents/skills/coppermind/SKILL.md — 04-projects/ is agent-writable (briefs/people via proposals), 00-bin/01-logs/02-moberg are Tony's zones.

## Shell & CI discipline

- Never pipe verification commands (tests, linters, builds) through filters that mask exit codes (`| tail`, `| grep`). Capture output to a file and check the exit code explicitly: `cmd > /tmp/out 2>&1; echo "exit=$?"`. A masked failure has caused a broken commit to be pushed.
- When watching a CI/workflow run, capture the run ID at trigger time and poll that ID. Never poll "latest run" (`gh run list --limit 1`) — a just-triggered push races the previous run and you will report the wrong result.
