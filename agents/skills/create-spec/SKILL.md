---
name: create-spec
description: "Create a structured implementation spec from a project idea or description. Use when starting a new feature or project that needs a spec before building. Fills the gap before spec-interview: create-spec → spec-interview → spec-driven-build. Triggers on: 'create a spec', 'write a spec', 'spec from scratch', 'new project spec', 'turn this idea into a spec'."
---

# Create Spec

Produce a structured implementation spec from a rough idea or project description. The output is a spec file with phased tasks ready for refinement (via spec-interview) or direct execution (via spec-driven-build).

## When to Use This vs Alternatives

| Situation | Use |
|-----------|-----|
| Rough idea, no spec exists | **create-spec** |
| Spec exists, needs refinement | spec-interview |
| Spec is complete, ready to build | spec-driven-build |
| Quick feature, low complexity | Plan mode directly |

## Workflow

Three phases: **Explore → Discuss → Write**.

### Phase 1: Explore

Determine context by examining the current working directory and the user's description.

**Existing codebase, new feature** — CWD has substantial code:
- Launch Explore agents to understand project structure, tech stack, conventions
- Identify existing code the feature will interact with
- Summarize findings before moving to discussion

**Monorepo, separate sub-project** — CWD has code but user describes something independent:
- Explore shared infrastructure and conventions
- Treat the feature as semi-independent from existing modules

**Greenfield project** — CWD is empty or user explicitly says "new project":
- Research the domain using Explore agents, `exa`, or `WebSearch`
- Investigate similar projects, library options, architecture patterns

Usually the user's description plus what's in CWD makes the situation obvious. If genuinely ambiguous, ask.

### Phase 2: Discuss

Conversational interview to understand requirements. Do not front-load questions — ask 2-3 at a time, grouped by topic.

**Topics to cover:**
1. Core functionality — what does it do, who uses it, key user flows
2. Technical constraints — platform, language, framework, integrations
3. Data model — entities, relationships, storage approach
4. Edge cases — what happens when things go wrong
5. Non-functional requirements — performance, security, scale

**How to interview:**
- After each response, synthesize what you heard and ask targeted follow-ups
- When a decision point has multiple valid options, present the tradeoffs with your recommendation, then ask
- Continue for 3-5 rounds until all major decisions are resolved
- At the end, use `AskUserQuestion` to confirm the final set of key decisions before writing

### Phase 3: Write

Write the spec to disk. Use the template in `references/spec-template.md` as the structure.

**File location:**
- Existing project: `<project-root>/spec.md` or user-specified path
- New project: `<project-name>/spec.md`

**Implementation Phases in the spec are critical.** Each phase must include:
- Concrete action items with file paths and deliverables
- Dependencies on other phases
- Branch name suggestion

These tasks feed directly into the Claude Code task system during spec-driven-build. They don't need to be exhaustive (spec-interview will refine), but each phase must have clear, actionable deliverables.

After writing, print:
- The spec file path
- Next steps: "Run `/spec-interview <path>` to refine, or start building with spec-driven-build."
