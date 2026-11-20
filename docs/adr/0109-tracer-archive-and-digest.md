# Tracer archives are pushed with merge-preserving tracer push, and tracer-digest marks processed sessions with a tag

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

sietch holds the authoritative tracer archive. `tracer-digest` on sietch reviews new agent sessions with a model and needs to know which sessions it has processed, while session archives are re-pushed between hosts. A raw rsync overwrote annotations such as `wiki:compiled` on every push. Tool output is about 85% of session bytes.

## Decision

- `tracer push` replaced the rsync. It transfers only new or changed transcripts, and the receiver merge-preserves annotations (tags and outcome).
- sietch lists `/vault/userdata/tracer-ingest` in `annotatable_roots`, so tag and outcome writes there survive re-pushes.
- Processed state lives in session frontmatter as the `wiki:compiled` tag; the digest lists sessions without it. Re-pushes keep the tag because the receiver's merge unions tags, so there is no side-channel bookkeeping file.
- Sessions are tagged only after the digest is written, so a failed run retries them.
- Transcripts are slimmed before the model reads them, which keeps the narrative and cuts token cost about 5 to 7 times.

## Consequences

This holds only while nothing rsyncs into the ingest root. Anything that rewrites frontmatter without merging tags would make sessions reprocess. `docs/fleet-plan.md` still describes the old rsync.

## Where

- `home/services/tracer-sync.nix` (`programs.tracer.settings.push.remotes`)
- `machines/sietch/default.nix` (`programs.tracer.settings.archive.annotatable_roots`)
- `bin/tracer-digest`
- `agents/skills/tracer/SKILL.md` (the `wiki:compiled` convention)
