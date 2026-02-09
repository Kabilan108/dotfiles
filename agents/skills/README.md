# Claude Code Skills

Reusable skills that extend Claude Code with specialized workflows. Each subdirectory is a standalone skill you can copy into your own `agents/skills/` directory.

## Workflow & Project Management

| Skill | What it does |
|-------|-------------|
| **commit** | Creates atomic, well-structured git commits from uncommitted changes with good messages |
| **create-spec** | Generates implementation specs from project ideas through an explore-discuss-write workflow |
| **spec-driven-build** | Orchestrates multi-phase builds from specs using git worktrees and parallel subagents |
| **handoff** | Creates HANDOFF.md for context transfer between sessions when hitting context limits |
| **tmux** | Manages concurrent processes (servers, long tasks, multi-agent orchestration) via tmux panes |

## Knowledge & Learning

| Skill | What it does |
|-------|-------------|
| **learn** | Extracts non-obvious session learnings into AGENTS.md files for persistent codebase knowledge |
| **learn-skill** | Reviews sessions to identify patterns worth codifying as new reusable skills |
| **librarian** | Researches libraries via Exa code search and creates structured markdown docs for future reference |
| **skill-creator** | Step-by-step guide for creating new skills with proper structure and frontmatter |

## Development

| Skill | What it does |
|-------|-------------|
| **fasthtml** | Build interactive web apps in pure Python (HTMX + Starlette) without JavaScript |
| **frontend-design** | Creates distinctive, high-quality frontend interfaces that avoid generic AI aesthetics |
| **hook-development** | Guide for creating Claude Code plugin hooks (PreToolUse, PostToolUse, Stop, etc.) |
| **logging-best-practices** | Logging patterns focused on wide events / canonical log lines for debugging and analytics |
| **playground** | Creates self-contained HTML playgrounds with visual controls and live preview |

## Tool Integration

| Skill | What it does |
|-------|-------------|
| **oracle** | Consults OpenAI Codex (GPT-5.2) as a second opinion via tmux for hard problems |
| **raindrop** | Manages Raindrop.io bookmarks (search, tag, organize) through the raindrop CLI |
| **obsidian-tasks** | Task management using Obsidian Tasks plugin with Dataview format |
| **worktrunk** | Guidance for Worktrunk, a CLI tool for managing git worktrees with hooks and LLM commit generation |
