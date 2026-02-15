---
name: code-reference
description: Explore external codebases to answer questions about their architecture, implementation, and behavior. Use when needing to understand how a library, framework, or external project works internally — for debugging dependency behavior, making architecture decisions, understanding API internals, or learning implementation patterns. Triggers on repo slugs or URLs with questions (e.g., "how does X implement Y"), "look at the source of", "check how [dep] works", "explore [repo]", or when answering a question would benefit from reading source code of an external project. Also invoke proactively when the user's question about a dependency could be answered more accurately by reading the actual source rather than relying on training data.
---

# Code Reference

Explore external codebases to answer specific questions, grounded in actual source code.

## Input Parsing

Arguments are freeform — a mix of **target** (what repo) and **question** (what to find out).

Extract:
1. **Target** — a GitHub URL, repo slug (`org/repo`), package name, or natural language description
2. **Question** — what the user wants to know (may be implicit: "how does the allocator work", "what's the plugin architecture")

If only a target is given with no question, ask what they want to know.

## Workflow

### 1. Resolve the Repository

**Slug or URL provided:**

```bash
gh repo view <slug> --json nameWithOwner,url,defaultBranch
```

**Package name or description (ambiguous):**

First check if it's a dependency of the current project (see step 2) to resolve the exact repo. Otherwise search:

```bash
gh search repos "<query>" --limit 5 --json nameWithOwner,description,url
```

If multiple candidates match, present them and ask the user to pick.

### 2. Version Pinning

If the referenced repo corresponds to a **direct dependency** of the current project, identify the pinned version and check out the matching release tag. This ensures advice is grounded in the version actually in use.

Check these files in the project root to find the version:

| Ecosystem | Dependency files | Version source |
|-----------|-----------------|----------------|
| Python | `pyproject.toml`, `uv.lock`, `requirements*.txt` | Version specifier or locked version |
| Node | `package.json`, `package-lock.json` | `dependencies` / `devDependencies` |
| Go | `go.mod` | `require` directives |
| Rust | `Cargo.toml`, `Cargo.lock` | `[dependencies]` section |
| Zig | `build.zig.zon` | `.dependencies` |
| JVM | `build.gradle.kts`, `libs.versions.toml` | Version catalog or dependency block |
| Nix | `flake.nix`, `flake.lock` | Input refs and locked revisions |

If a version is found, resolve the matching git tag:

```bash
gh api "repos/{owner}/{repo}/git/refs/tags" --jq '.[].ref' | grep -i "<version>"
```

### 3. Clone or Locate

Cache reference repos at `~/.cache/claude/references/`:

```bash
REF_DIR="$HOME/.cache/claude/references/<owner>/<repo>"

if [ -d "$REF_DIR" ]; then
  git -C "$REF_DIR" fetch --tags --quiet
else
  mkdir -p "$(dirname "$REF_DIR")"
  gh repo clone <owner>/<repo> "$REF_DIR"
fi

# If version-pinned, checkout the tag
git -C "$REF_DIR" checkout <tag> --quiet 2>/dev/null
```

### 4. Explore

Two-phase strategy — orient first, then dig in.

#### Phase A: DeepWiki Probe

Use the DeepWiki MCP server (`mcp__deepwiki__read_wiki_structure`, `mcp__deepwiki__read_wiki_contents`) to get a high-level overview of the repo before reading source files. This is fast, context-efficient, and especially valuable for large or unfamiliar projects.

- Get the wiki structure to identify relevant sections
- Read sections that relate to the user's question
- Use the overview to identify which modules, files, and abstractions to target in Phase B

If DeepWiki hasn't indexed the repo or the MCP is unavailable, skip to Phase B with a broader initial pass.

#### Phase B: Targeted Source Exploration

Launch Explore sub-agents (via Task tool with `subagent_type=Explore`) against the cloned repo directory. Frame the exploration prompt around:

- The user's specific question
- Architectural context from DeepWiki (if available)
- The pinned version and any version-specific considerations

For questions that span multiple subsystems, launch parallel Explore agents targeting different aspects.

Set the exploration `path` to `$REF_DIR` so the agent searches the reference repo, not the current project.

### 5. Respond

Provide:
- **Direct answer** to the question, grounded in source code
- **Key files** — paths in the reference repo most relevant to the answer
- **Code excerpts** — short, targeted snippets (not full files)
- **Version note** — if version-pinned, state the version examined

Stay focused on the question asked. Don't dump the whole architecture unless that's what was requested.
