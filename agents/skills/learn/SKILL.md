---
name: learn
description: Extract non-obvious learnings from session to AGENTS.md files to build codebase understanding
context: fork
---

Analyze this session and extract non-obvious, durable learnings to add to AGENTS.md files. If the user asked for review-only/audit-only, or another active session owns the files, produce a proposed AGENTS.md patch instead of editing.

AGENTS.md files can exist at any directory level, not just the project root. When an agent reads a file, any AGENTS.md in parent directories are automatically loaded into the context of the tool read. Place learnings as close to the relevant code as possible:

- Project-wide learnings → root AGENTS.md
- Package/module-specific → packages/foo/AGENTS.md
- Feature-specific → src/auth/AGENTS.md

What counts as a learning (non-obvious discoveries only):

- Hidden relationships between files or modules
- Execution paths that differ from how code appears
- Non-obvious configuration, env vars, or flags
- Debugging breakthroughs when error messages were misleading
- API/tool quirks and workarounds
- Build/test commands not in README
- Architectural decisions and constraints
- Files that must change together

What NOT to include:

- Obvious facts from documentation
- Standard language/framework behavior
- README-style usage docs, install instructions, or command catalogs
- Things already covered in any relevant parent or target AGENTS.md
- Verbose explanations
- Session-specific details, temporary paths, or one-off branch names

Process:

1. Review session for discoveries, errors that took multiple attempts, unexpected connections
2. Determine scope - what directory does each learning apply to?
3. Read existing AGENTS.md files at the repo root, the target directory, and directories between them; merge with existing sections instead of duplicating equivalent guidance
4. Create or update AGENTS.md at the appropriate level
5. When creating a **new** AGENTS.md, handle the CLAUDE.md compatibility file:
   - If CLAUDE.md is absent: `ln -s AGENTS.md CLAUDE.md`
   - If CLAUDE.md is already a symlink to AGENTS.md: leave it alone
   - If CLAUDE.md exists as a real file or points elsewhere: do not overwrite it; report the conflict
6. Keep entries to 1-3 lines per insight

After updating, summarize which AGENTS.md files were created/updated, how many learnings per file, and any candidate learnings skipped as too obvious or too session-specific.

$ARGUMENTS
