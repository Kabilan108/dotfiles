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
| gpt-5.5  | 9    | 8            | 5     |
| sonnet   | 5    | 5            | 7     |
| opus     | 4    | 7            | 8     |
| fable    | 2    | 9            | 9     |

How to apply:
- These are defaults, not limits. You have standing permission to override them: if a cheaper model's output doesn't meet the bar, rerun or redo the work with a smarter model without asking. Judge the output, not the price tag. Escalating costs less than shipping mediocre work.
- Cost is a tie-breaker only; when axes conflict for anything that ships, intelligence > taste > cost.
- Bulk/mechanical work (clear-spec implementation, data analysis, migrations, investigation of large codebases): gpt-5.5 — it's effectively free.
- Anything user-facing (UI, copy, API design) needs taste ≥ 7.
- Reviews of plans/implementations: fable or opus, optionally gpt-5.5 as an extra independent perspective.
- Never use haiku.
- Claude models (sonnet, opus, fable) run via the Agent/Workflow model parameter. gpt-5.5 is only reachable through the Codex CLI (`codex exec`).

## Delegating to gpt-5.5 via Codex CLI

`~/.codex/config.toml` defaults to gpt-5.5 at xhigh effort with full-access sandbox and no approvals. ALWAYS override effort and sandbox per invocation — xhigh is a token furnace and wrong for delegated work:

```sh
# investigation / analysis (no file changes)
codex exec -s read-only -c model_reasoning_effort=medium "<self-contained prompt>"

# clear-spec implementation in the current repo
codex exec -s workspace-write -c model_reasoning_effort=medium "<self-contained prompt>"

# mechanical grunt work (renames, format fixes, boilerplate)
codex exec -s workspace-write -c model_reasoning_effort=low "<self-contained prompt>"

# independent code review of the current repo
codex exec review "<what to focus on>"

# follow-up / steering on the previous run
codex exec resume --last "<correction or next step>"
```

Prompt rules — Codex shares none of your conversation context:
- Prompts must be fully self-contained: repo path, relevant file paths, exact requirements, acceptance criteria, and any constraints (formatter, test command, conventions).
- State what "done" looks like and tell it to end with a summary of changed files.
- For long tasks, run via Bash with run_in_background and check output when notified; codex prints its final message to stdout.
- After a delegated implementation, review the diff yourself before presenting it. If the output misses the bar, fix or redo with a Claude model — don't ship it unexamined.

Using gpt-5.5 inside workflows and subagents (the model parameter only takes Claude models, so use a wrapper):
- Spawn a thin Claude wrapper agent with `model: 'sonnet', effort: 'low'` whose prompt instructs it to write a self-contained codex prompt, run `codex exec` via Bash, and return the raw result without editorializing.
