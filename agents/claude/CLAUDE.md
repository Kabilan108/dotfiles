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

## `browser` Sub-Agent

Executes browser automation tasks using Rodney (Chrome CLI). Faster than step-by-step browser interaction because it runs with less deliberation overhead.

**When to use:** When you have a clear sequence of browser actions to perform. Delegate to this agent instead of executing browser steps yourself.

**Invocation format:**

When calling the Task tool with `subagent_type: "browser"`, use this prompt structure:

```
Goal: [What we're trying to accomplish]

Steps:
1. [Specific action with clear target]
2. [Specific action]
...

Success criteria: [How to verify the task succeeded]
Extract: [Any data to capture and return, optional]
```

Set the Task tool's `model` parameter to `"haiku"` for simple navigation/extraction or `"sonnet"` for complex interactions.

**Example invocation:**

```
Goal: Search for "claude code documentation" and extract the first 3 result titles

Steps:
1. Navigate to google.com
2. Type "claude code documentation" in the search box
3. Press Enter to search
4. Wait for results to load
5. Extract the titles of the first 3 search results

Success criteria: Search results page is visible with results
Extract: First 3 result titles as a list
```

**Model selection:**
- `haiku` - Simple navigation, form filling, data extraction
- `sonnet` - Complex multi-step flows, error recovery, ambiguous UI

**Guidelines:**
- The agent runs `rodney` CLI commands against a persistent Chrome instance
- Be specific in steps - "click the blue Submit button" not "submit the form"
- The sub-agent will return a structured result with Status, Outcome, Data, and Issues

**When NOT to use:**
- Single quick actions (one click, one navigation) - faster to do directly
- Exploratory browsing where next steps depend on what you find
