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

# Tools

## Browser Tools

- Use `agent-browser` for most interactive browser work. It is the default choice for agent-driven exploration, iterative UI interaction, screenshots, and stateful sessions. Prefer it when you want AI-friendly page discovery via `snapshot` and stable element refs like `@e1`.
- Use `dev-browser` when you need programmable browser automation with Playwright-style APIs. Prefer it for scripted multi-step flows, reusable inspection scripts, or cases where `snapshotForAI()` plus direct `page` methods are the best fit.
- On this machine, `dev-browser` may work better with `--connect` to an existing Chrome/CDP session than by launching its bundled browser directly.

# Picking the right models for workflows and subagents

Rankings, higher = better. Cost reflects actual plan limits, not list price. Intelligence is how hard a problem you can hand the model unsupervised. Taste covers UI/UX, code quality, API design, and copy.

| model    | cost | intelligence | taste |
|----------|------|--------------|-------|
| gpt-5.6  | 9    | 8            | 5     |
| sonnet   | 5    | 5            | 7     |
| opus     | 4    | 7            | 8     |
| fable    | 2    | 9            | 9     |

How to apply:
- These are defaults, not limits. You have standing permission to override them: if a cheaper model's output doesn't meet the bar, rerun or redo the work with a smarter model without asking. Judge the output, not the price tag. Escalating costs less than shipping mediocre work.
- Don't let cost prevent you from using the right model for the job. Instead, take advantage of cheaper options to get more information and try things before moving the work to a more expensive option.
- Bulk/mechanical work (clear-spec implementation, data analysis, migrations, investigation of large codebases): gpt-5.6 — it's effectively free.
- Anything user-facing (UI, copy, API design) needs taste ≥ 7.
- Reviews of plans/implementations: fable or opus, optionally gpt-5.6 as an extra independent perspective. A gpt-5.6 review is never the sole gate: always pair it with a fable/opus adversarial pass focused on API and interface design before presenting findings or merging.
- Never use haiku.
- Claude models (sonnet, opus, fable) run via the Agent/Workflow model parameter. gpt-5.6 is only reachable through the Codex CLI (`codex exec`).

## Delegating to gpt-5.6 via Codex CLI

`~/.codex/config.toml` defaults to gpt-5.6 at high effort with a full-access sandbox and no approvals — ALWAYS pass `-s` and `-c model_reasoning_effort=...` explicitly per invocation.

Use the skills for the mechanics (command shapes, effort guidance, prompt templates, session capture):
- `codex-implementation` — scoped code changes producing a patch
- `codex-review` — independent second-opinion review of a diff, branch, or commit
- `codex-computer-use` — browser/desktop verification of running apps

For quick one-off investigation with no file changes:

```sh
codex exec -s read-only -c model_reasoning_effort=medium "<self-contained prompt>"
```

Prompt rules — Codex shares none of your conversation context:
- Prompts must be fully self-contained: repo path, relevant file paths, exact requirements, acceptance criteria, and project-specific constraints (Codex already loads the global AGENTS.md conventions).
- State what "done" looks like and tell it to end with a summary of changed files.
- For long tasks, run via Bash with run_in_background and check output when notified; use `-o <file>` to capture the final message.
- For follow-ups, capture the `session id:` from codex's output frontmatter and run `codex exec resume <session-id> "<correction>"` so follow-ups stay pinned to the right run.
- After a delegated implementation, review the diff yourself before presenting it. If the output misses the bar, fix or redo with a Claude model — don't ship it unexamined.

Using gpt-5.6 inside workflows and subagents (the model parameter only takes Claude models, so use a wrapper):
- Spawn a thin Claude wrapper agent with `model: 'sonnet', effort: 'low'` whose prompt instructs it to write a self-contained codex prompt, run `codex exec` via Bash, and return the raw result without editorializing.

# Knowledge Vault

The coppermind vault (~/notes, /vault/notes/coppermind) is the knowledge base for projects and tasks. When working in a repo mapped by ~/notes/04-projects/manifest.md (notably /vault/work/moberg/*), read the project's brief.md + tasks.md there for context, and invoke the vault's `coppermind` skill before writing anything into it.

# Shell & CI discipline

- Never pipe verification commands (tests, linters, builds) through filters that mask exit codes (`| tail`, `| grep`). Capture output to a file and check the exit code explicitly: `cmd > /tmp/out 2>&1; echo "exit=$?"`. A masked failure has caused a broken commit to be pushed.
- When watching a CI/workflow run, capture the run ID at trigger time and poll that ID. Never poll "latest run" (`gh run list --limit 1`) — a just-triggered push races the previous run and you will report the wrong result.
- When an applicable `.envrc` exists, run project commands through `direnv exec "$PWD" ...`.
