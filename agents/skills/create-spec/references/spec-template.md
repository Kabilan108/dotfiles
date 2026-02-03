# <Project Name> — Spec

## Overview

One paragraph summarizing the project: what it is, who it's for, and what problem it solves.

## Goals

- Goal 1
- Goal 2

## Non-Goals

- Explicitly out of scope item 1
- Explicitly out of scope item 2

## Architecture

Tech stack, high-level component relationships, key dependencies.

Describe how components interact. A text diagram is fine:

```
[Component A] → [Component B] → [Storage]
       ↓
[Component C]
```

## Data Model

Entities, their relationships, and storage approach.

| Entity | Fields | Storage |
|--------|--------|---------|
| Example | id, name, ... | Postgres / SQLite / ... |

## API / Interface

Endpoints, UI pages, CLI commands — whatever the interface surface is.

## Implementation Phases

### Phase 1: <Name>

**Branch:** `feature/<name>`

**Tasks:**
- [ ] Create/modify `path/to/file` — description of what and why
- [ ] Create/modify `path/to/file` — description
- [ ] ...

**Dependencies:** None

### Phase 2: <Name>

**Branch:** `feature/<name>`

**Tasks:**
- [ ] ...

**Dependencies:** Phase 1

### Phase N: <Name>

...

## Open Questions

- Unresolved decision or area needing further investigation
