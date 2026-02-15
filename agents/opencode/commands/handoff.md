---
name: handoff
description: "Create a HANDOFF.md for seamless context transfer when approaching limits or ending a session. Use when the agent is running low on context, needs to pass work to another session, or the user says 'handoff', 'save progress', 'context overflow', 'pick up later', or 'wrap up session'."
---

# Handoff

Write a HANDOFF.md that captures everything a successor session needs to continue the work. The goal is to transfer knowledge that exists only in the current session's context — the plan, spec, and codebase will persist, but conversation history, interim discoveries, and reasoning will not.

Write the handoff as if briefing a colleague who has access to the repo but was not in the room for any of the discussions.

## When to Use

- Approaching context window limits
- A subagent in spec-driven-build needs to pass remaining work to a successor
- Ending a long session with unfinished work
- Switching between agents (exploration → implementation)
- User requests: "handoff", "save progress", "wrap up"

## HANDOFF.md Structure

### Status

Summarize where things stand — not a single line, but enough that someone unfamiliar with the session can orient. What phase are we in? What's working? What's broken? What was the user's last direction?

### Completed

Concrete evidence of progress:
- Files created or modified (with full paths)
- Commits made (with hashes if available)
- Tests passing or failing
- Milestones reached

### In Progress

What is currently being worked on:
- The specific task or file
- How far along it is
- What the immediate next step would be

### Discussion Summary

What was discussed during this session — the conversational context that gets lost on overflow:
- Options the user considered
- Tradeoffs that were weighed
- Questions the user answered and their responses
- Design directions that were explored and abandoned

### Decisions Made

Settled questions with rationale. This section prevents the successor from re-opening resolved discussions:
- **Decision**: what was decided — **Rationale**: why

Include the "why" — without it, the next session may question or reverse a good decision.

### Session Learnings

Non-obvious knowledge discovered during the session:
- Gotchas and undocumented behavior
- Performance characteristics observed
- Things that look wrong but are intentional
- Workarounds for known issues
- Patterns in the codebase that aren't documented elsewhere

This is the knowledge that lives only in the agent's context and would be permanently lost.

### Remaining Work

Ordered list of what still needs to be done, with enough detail to act on:
1. Task description — key details, approach notes
2. ...

### Blockers

What is preventing progress and what's needed to resolve each blocker.

### Context

Everything the next session needs to orient itself:
- Relevant file paths
- Running services (ports, tmux pane IDs)
- Environment variables or configuration
- Branch name and worktree location
- Links to specs, plans, docs
- Task list ID if shared across sessions

### Reproduction

Commands to run to get back to the current state (install deps, start servers, switch branches, etc.).

## How to Write the Handoff

1. Review what the session's goal was and what was accomplished
2. Check `git status` and recent commits for concrete progress evidence
3. Check the task list if `CLAUDE_CODE_TASK_LIST_ID` is set
4. Write HANDOFF.md — location priority:
   - Worktree root (if in a worktree)
   - Project root (if in a project)
   - Path from `$ARGUMENTS` if specified
5. Print the file path and a brief summary

If there is nothing meaningful to hand off (no real work done), say so rather than writing a hollow file.
