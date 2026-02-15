---
name: learn-skill
description: Review the current session and propose new skills that could be created. Use when the user says "propose skills", "what skills could help", "find skill opportunities", "learn-skill", or after a long session to identify reusable patterns worth codifying into skills.
context: fork
---

Review this session and identify patterns that would benefit from being codified as reusable skills.

Look for:

- **Repeated workflows**: Multi-step procedures performed more than once or likely to recur
- **Domain expertise applied**: Specialized knowledge about tools, APIs, or systems that had to be recalled or looked up
- **Workarounds**: Non-obvious solutions to tool limitations or environment quirks
- **Complex procedures**: Multi-step processes where ordering, flags, or edge cases matter
- **Tool orchestration**: Patterns combining multiple tools in a specific way

For each candidate skill, determine:

1. **Name**: Hyphen-case identifier
2. **Description**: What the skill would do and when it triggers (this becomes frontmatter)
3. **What it would contain**: Instructions, scripts, references, or assets
4. **Placement**: Project-level (`.claude/skills/`) or user-level (`~/.claude/skills/`)
   - Project-level: Tied to this specific codebase, tech stack, or repo conventions
   - User-level: Generally useful across projects
   - If unclear, ask the user

Skip patterns that:

- Are already covered by an existing skill
- Are standard language/framework usage Claude already knows
- Would be used only once
- Are better captured as an AGENTS.md learning (use `/learn` for those)

Present each proposal in this format:

```
## <skill-name>

**Description:** <frontmatter description — what it does and when to trigger>
**Contains:** <brief list: instructions only, or scripts/references/assets needed>
**Placement:** <user-level | project-level> — <one-line rationale>
**Rationale:** <why this is worth a skill — what pain it prevents>
```

After presenting proposals, ask the user which (if any) they want to create, then hand off to `/skill-creator` with the relevant context.

$ARGUMENTS
