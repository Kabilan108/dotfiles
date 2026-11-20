# Architecture decision records

A decision gets a record here only when it is hard to reverse, surprising without
context, and the result of a real trade-off. Facts about how a subsystem works go in
that subsystem's `AGENTS.md` instead (see "Notes and decisions" in the root
`AGENTS.md`).

Name a new record `NNNN-<slug>.md` with the next free number:

```markdown
---
paths:
  - repo/path/the/decision/governs
---

# Sentence-case title that states the decision

One to three sentences: the context, what was decided, and why the alternative lost.
```

Add `## Consequences` only for effects a reader would not expect. A record that
replaces another says so in its first line, and the commit deletes the old record;
git keeps its history.
