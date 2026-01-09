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
