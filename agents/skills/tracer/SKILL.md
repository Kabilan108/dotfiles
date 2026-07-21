---
name: tracer
description: Query, read, annotate, and cross-host-sync the coding-agent session archive with the tracer CLI. Use when listing or fetching session transcripts, filtering tool output for LLM consumption, tagging sessions for pipeline state (e.g. wiki:compiled), or pushing archives between hosts.
---

# Tracer

Run `tracer skill` and follow its output — the installed binary prints
complete, version-matched usage instructions (SKILL.md format), so they can
never drift from the CLI you actually have.

```bash
tracer skill
```

Notes that live outside the binary:

- On this fleet, jacurutu pushes its archive to sietch daily
  (`tracer-sync` systemd user timer → `tracer push sietch`); sietch reads it
  via `archive.additional_roots` and may annotate it (`annotatable_roots`).
- Pipeline convention: `wiki:compiled` marks sessions the digest/wiki
  pipeline has processed. Query unprocessed work with
  `tracer list --json --tag '!wiki:compiled'`.
- Prefer `tracer get <id> --tool-output=none` when feeding transcripts to an
  LLM; the archive on disk is never modified by reads.
