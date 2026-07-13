# Agent Skills

Shared skills for the agent harnesses on this machine (Claude Code, Codex). Each subdirectory is a standalone skill; the set is kept deliberately lean — skills that don't earn their keep in transcript audits get cut.

## Workflow

| Skill | What it does |
|-------|-------------|
| **commit** | Creates atomic, well-structured git commits from uncommitted changes with good messages |
| **handoff** | Compacts the current session into a handoff document another agent can pick up |
| **pair-programmer** | Senior-engineer persona for collaboratively planning features (plans only, no implementation) |
| **review-swarm** | Parallel read-only multi-agent review of a diff or file scope |
| **tmux** | Manages concurrent processes (servers, long tasks, multi-agent orchestration) via tmux panes |

## Browser & Desktop

| Skill | What it does |
|-------|-------------|
| **agent-browser** | Browser automation CLI for driving websites, forms, screenshots, and Electron apps |
| **helium-browser-use** | Drives the dedicated Helium browser profile via agent-browser/CDP, locally or over SSH tunnels |
| **niri-computer-use** | Desktop inspection and control for the local niri Wayland session via `acu` |

## Infrastructure

| Skill | What it does |
|-------|-------------|
| **fleet** | Working with the other machines in the fleet (jacurutu, sietch, tleilax) |
| **notify** | Sends Discord notifications for long-running jobs and blockers |

## Knowledge & Authoring

| Skill | What it does |
|-------|-------------|
| **btca-local** | Searches vendored repo checkouts and answers questions with commit-pinned citations |
| **frontend-design** | Creates distinctive, high-quality frontend interfaces that avoid generic AI aesthetics |
| **html-plans** | Publishes plans and reports as hosted HTML pages via pagebin |
| **learn** | Extracts non-obvious session learnings into AGENTS.md files |
| **skill-creator** | Step-by-step guide for creating new skills with proper structure and frontmatter |
