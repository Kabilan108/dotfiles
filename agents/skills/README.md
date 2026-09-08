# Shared agent skills

Each child directory with a `SKILL.md` is a shared skill. Its frontmatter describes its purpose; harness metadata controls implicit invocation.

`bin/sync-agent-skills` installs shared and harness-specific skills for Claude, Codex, and OpenCode. Use `--dry-run --host jacurutu` or `--host sietch` to inspect availability. Project-local skills live in the owning repository’s `.agents/skills/` directory. Pi’s separately managed skill directory is not covered by this sync command.
