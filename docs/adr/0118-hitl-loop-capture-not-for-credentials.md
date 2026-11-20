# The HITL loop template keeps credentials out of capture

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

`hitl-loop.template.sh` is the diagnosing-bugs skill's last-resort reproduction loop. The agent runs it, and the user answers prompts in their terminal. `capture VAR "<question>"` reads a reply into `VAR`, and the script prints every captured value as `KEY=VALUE` at the end for the agent to parse. Anything typed into `capture` therefore lands in the agent's transcript.

## Decision

Agents copy the template, edit only the steps between its edit markers, use `capture` for observations, and give sign-in to the user as a `step`, which waits for Enter and reads nothing back.

## Consequences

Passwords and tokens never pass through `capture`. The template's usage notes must live somewhere an agent reads before copying it, such as `agents/skills/diagnosing-bugs/SKILL.md`, if they leave the script.

## Where

- `agents/skills/diagnosing-bugs/scripts/hitl-loop.template.sh` (`step`, `capture`)
- `agents/skills/diagnosing-bugs/SKILL.md` (HITL bash script)
