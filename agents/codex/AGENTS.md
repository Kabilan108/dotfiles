# AGENTS.md

## Local Machine

This machine runs nixos with home-manager. The flake is managed at ~/dotfiles. Various dev tools are installed in the base environment (e.g. uv, pnpm, npm, python, etc); if you need additional dependencies, use `nix-shell -p` to grab them. Execute commands via the flake dev shell if one is present for the current project. For new projects, set up a flake devshell with the necessary dependencies. Where applicable, `nix-direnv` may auto-load a project's dev shell.

## Working together

Complete the requested work through its stated stopping point. Carry forward decisions and authorization across follow-ups. An investigation produces an assessment unless implementation was requested. Make routine choices yourself; ask good questions when an unresolved decision materially affects the outcome or scope. Continue independent work while waiting for an answer, unless the question(s) is blocking.

Preserve unrelated staged, unstaged, and untracked changes. Follow the repository's implementation and verification conventions. Use the smallest reliable checks for the changed behavior, broadening them when new evidence warrants it. Report the outcome, what was verified, and remaining dependencies in plain language. Use unslop for writing.

## Delegation

Use subagents at your judgment for read-only exploration: searches, context gathering, an independent review perspective. Be judicious and prefer the cheapest model that meets the bar. Splitting implementation across subagents, using another provider, or launching workers that outlive the session is opt-in: only when I ask, or when a workflow I selected includes it. Once I ask for delegation on a task, that covers its follow-up workers; no need to re-ask for each one. Give each worker a bounded task, owned files or read-only scope, the relevant decisions, and a checkable completion point. The lead owns integration and verification.

Use native workers within the current harness when available. Use a provider CLI when I request another provider or a separate runtime. Preserve the selected coordinator. Sol (`gpt-5.6-sol`) at medium is the default for bounded delegated work; Fable 5.1 at medium is the default Claude choice. Astra (`gpt-6-astra`) is an option for peer consultation, design discussion, and consequential review. Keep my explicit model and effort choices. Add another review perspective for material API/design or high-risk behavioral changes, or when requested; ordinary scoped checks need not run a paired review. Never use Haiku.

For durable shell delegation, use `agent-run --help` (source: `~/dotfiles/bin/agent-run`). It records model, scope, process identity, result and exit status. Give it a self-contained prompt file. After `agent-run start`, immediately run `agent-run wait <id> --timeout 0` using the harness mechanism below. Retain its handle. After a restart, reconcile the task's existing runs and re-arm waits before launching replacements. Review the result and diff before acknowledging completion. Use `launch-agent` for interactive panes, not batch completion tracking.

For review of a consequential behavioral invariant, consult `~/dotfiles/agents/references/empirical-review.md`.

## Browser and artifacts

Use available integrated browser tools when suitable; use helium-browser-use otherwise or when explicitly requested, including when its persistent login session is needed. Use desktop control for compositor/native-app tasks. Search Gmail and Slack through Executor rather than browser automation when service search is the task.

For HTML publication, follow `~/dotfiles/agents/references/publication.md`; html-communication owns authoring and PageBin owns transport. Keep the artifact's identity across updates.

## Codex-specific tools

Use claude-review for a requested Fable 5.1 second opinion. Run the watcher through the available process tool and retain its yielded handle. Resume that handle with the tool's wait/poll operation; keep the managed wait active until completion or an explicit checkpoint. A finished turn is not guaranteed to be awakened by a background process. On restart, reconcile and reattach waits before starting replacements.

## Dev server networking

Bind dev servers to the server host's current Tailscale IP (`tailscale ip -4`) and return that reachable URL, unless the project is configured otherwise. Adhere to established project-specific networking conventions. Keep development access within the tailnet; public Funnel exposure requires an explicit request.

## Knowledge Vault

Use `~/notes/04-projects/manifest.md` for project routing and read the relevant brief. Invoke coppermind if the project is covered in the manifest; use it for vault work, including current TaskNotes conventions and write zones. Resolve the actual root from `~/notes`.

## Shell & CI discipline

- Never pipe verification commands (tests, linters, builds) through filters that mask exit codes (`| tail`, `| grep`). Capture output to a file and check the exit code explicitly: `cmd > /tmp/out 2>&1; echo "exit=$?"`. A masked failure has caused a broken commit to be pushed.
- When watching a CI/workflow run, capture the run ID at trigger time and poll that ID. Never poll "latest run" (`gh run list --limit 1`) — a just-triggered push races the previous run and you will report the wrong result.
- When an applicable `.envrc` exists, run project commands through `direnv exec "$PWD" ...`.

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
