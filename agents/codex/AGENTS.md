# AGENTS.md

## Local Machine

This machine runs nixos with home-manager. The flake is managed at ~/dotfiles. Various dev tools are installed in the base environment (e.g. uv, pnpm, npm, python, etc); if you need additional dependencies, use `nix-shell -p` to grab them. Execute commands via the flake dev shell if one is present for the current project. For new projects, set up a flake devshell with the necessary dependencies. Where applicable, `nix-direnv` may auto-load a project's dev shell.

## Working together

Complete the requested work through its stated stopping point. Carry forward decisions and authorization across follow-ups. An investigation produces an assessment unless implementation was requested. Make routine choices yourself; ask good questions when an unresolved decision materially affects the outcome or scope. When you introduce a term, environment, or name I haven't used, define it in one line or use my words. Continue independent work while waiting for an answer, unless the question(s) is blocking.

Preserve unrelated staged, unstaged, and untracked changes. Follow the repository's implementation and verification conventions. Use the smallest reliable checks for the changed behavior, broadening them when new evidence warrants it. Report the outcome, what was verified, and remaining dependencies in plain language. Use unslop for writing.

## Delegation

Delegate at your judgment: searches and context gathering, an independent review, a bounded implementation slice, browser verification. A worker earns its cost when it runs alongside other work, keeps bulk output out of your context, or brings a read that is not anchored on yours. Give each worker a bounded task, owned files or read-only scope, the relevant decisions, and a checkable completion point. The lead owns integration and verification.

Opus 5.5 (`claude-opus-5-5`) is the primary orchestrator and the go-to for implementation, at high effort, xhigh for hard changes. GPT 6.1 Sol (`gpt-6.1-sol`) at high on the fast service tier is the go-to for code review, browser verification and similar checks. For a second opinion on design or a consequential change, use GPT-6 Astra (`gpt-6-astra`) at high or Claude Fable 5.1 (`claude-fable-5-1`). Keep my explicit model and effort choices. Add another review perspective for material API/design or high-risk behavioral changes, or when requested; ordinary scoped checks need not run a paired review.

In T3 Code, `delegate_task` is the go-to for delegation and reaches any provider; T3's own orchestration instructions cover its use. The harness's native subagents also fit searches and other bounded read-only work. Preserve the selected coordinator.

Without T3's delegation tools, reach for `agent-run --help` (source: `~/dotfiles/bin/agent-run`) when a task needs another provider. Give it a self-contained prompt file. Right after `agent-run start`, attach `agent-run wait <id> --timeout 0` through the harness's background process tool and keep the handle. After a restart, reconcile the task's existing runs and re-arm waits before launching replacements. Review the result and diff before acknowledging completion.

For review of a consequential behavioral invariant, consult `~/dotfiles/agents/references/empirical-review.md`. Before presenting numbers that drive a decision (benchmarks, audits, data analysis), have an independent reviewer recompute them from the raw data, following its "Data claims" section.

## Browser and artifacts

Use an integrated browser when one is available and suitable. Otherwise use agent-browser for isolated headless browsing. Use helium-browser-use when the task calls for an intentionally shared Helium session or its saved logins. Use agent-browser for Electron and other CDP targets. Use desktop control for compositor/native-app tasks. Search Gmail and Slack through Executor rather than browser automation when service search is the task.

## Publishing content

I authorize publishing html artifacts to configured PageBin service and serving previews within my tailnet, including internal repository paths, architecture details, and benchmark results. No additional confirmation is needed.

## Dev server networking

Bind dev servers to the server host's current Tailscale IP (`tailscale ip -4`) and return that reachable URL, unless the project is configured otherwise. Adhere to established project-specific networking conventions. Keep development access within the tailnet; public Funnel exposure requires an explicit request.

## Knowledge Vault

Use `~/notes/04-projects/manifest.md` for project routing and read the relevant brief. Invoke coppermind if the project is covered in the manifest; use it for vault work, including current TaskNotes conventions and write zones. Resolve the actual root from `~/notes`.

## Shell & CI discipline

- Never pipe verification commands (tests, linters, builds) through filters that mask exit codes (`| tail`, `| grep`). Capture output to a file and check the exit code explicitly: `cmd > /tmp/out 2>&1; echo "exit=$?"`. A masked failure has caused a broken commit to be pushed.
- When watching a CI/workflow run, capture the run ID at trigger time and poll that ID. Never poll "latest run" (`gh run list --limit 1`) — a just-triggered push races the previous run and you will report the wrong result.
- A workflow that needs a secret reads it from a GitHub environment with me as the required reviewer, never from a repository secret. Agent GitHub tokens never get the Deployments permission.
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
