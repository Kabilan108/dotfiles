# Task Format Reference

## Table of Contents
- [Dataview Format (Primary)](#dataview-format-primary)
- [Emoji Format (Reference Only)](#emoji-format-reference-only)
- [Task Statuses](#task-statuses)
- [Priority Levels](#priority-levels)
- [Field Ordering](#field-ordering)

---

## Dataview Format (Primary)

Tasks use Dataview inline field syntax: `[key:: value]`

### Date Fields

```markdown
- [ ] Task [created:: 2024-01-01]
- [ ] Task [start:: 2024-01-05]
- [ ] Task [scheduled:: 2024-01-10]
- [ ] Task [due:: 2024-01-15]
- [x] Task [done:: 2024-01-12]
```

| Field | Purpose |
|-------|---------|
| `created` | When task was created |
| `start` | Earliest date task can be worked on (hidden until this date) |
| `scheduled` | When you plan to work on it |
| `due` | Deadline - when it must be done |
| `done` | Completion date (auto-added when checked) |

**Date format**: Always `YYYY-MM-DD`

### Priority

```markdown
- [ ] Task [priority:: highest]
- [ ] Task [priority:: high]
- [ ] Task [priority:: medium]
- [ ] Task [priority:: low]
- [ ] Task [priority:: lowest]
```

Tasks without priority are treated as between low and medium.

### Recurrence

```markdown
- [ ] Task [repeat:: every day]
- [ ] Task [repeat:: every week]
- [ ] Task [repeat:: every month]
- [ ] Task [repeat:: every week on Monday]
```

See [recurrence.md](recurrence.md) for full recurrence syntax.

### Combined Example

```markdown
- [ ] Weekly team meeting #todo [repeat:: every week on Monday] [scheduled:: 2024-01-15] [priority:: high]
```

---

## Emoji Format (Reference Only)

The emoji format is **not used in this vault** but may appear in external resources or documentation.

| Emoji | Field | Dataview Equivalent |
|-------|-------|---------------------|
| 📅 | Due date | `[due:: ]` |
| ⏳ | Scheduled date | `[scheduled:: ]` |
| 🛫 | Start date | `[start:: ]` |
| ➕ | Created date | `[created:: ]` |
| ✅ | Done date | `[done:: ]` |
| 🔁 | Recurrence | `[repeat:: ]` |
| ⏫ | High priority | `[priority:: high]` |
| 🔼 | Medium priority | `[priority:: medium]` |
| 🔽 | Low priority | `[priority:: low]` |
| 🔺 | Highest priority | `[priority:: highest]` |
| ⏬ | Lowest priority | `[priority:: lowest]` |

**Emoji format example** (for recognition only):
```markdown
- [ ] Task 📅 2024-01-15 ⏫
```

---

## Task Statuses

### Default Statuses

| Checkbox | Symbol | Status Name | Type |
|----------|--------|-------------|------|
| `- [ ]` | space | Todo | TODO |
| `- [x]` | x | Done | DONE |
| `- [X]` | X | Done | DONE |
| `- [/]` | / | In Progress | IN_PROGRESS |
| `- [-]` | - | Cancelled | CANCELLED |

### Status Types

The plugin categorizes statuses into types for querying:

- **TODO**: Incomplete, needs to be done
- **IN_PROGRESS**: Currently being worked on
- **DONE**: Completed
- **CANCELLED**: Won't be done
- **NON_TASK**: Not a task (for special checkbox uses)

Query by type:
```
status.type is TODO
status.type is IN_PROGRESS
status.type is not DONE
```

### Status Transitions

When clicking a checkbox:
- `[ ]` (Todo) → `[x]` (Done)
- `[/]` (In Progress) → `[x]` (Done)
- `[-]` (Cancelled) → `[ ]` (Todo)
- `[x]` (Done) → `[ ]` (Todo)

Custom transitions can be configured in plugin settings.

---

## Priority Levels

Priority order (highest to lowest):
1. `highest`
2. `high`
3. `medium`
4. (no priority) ← default position
5. `low`
6. `lowest`

Tasks without explicit priority sort between `low` and `medium`.

### Filtering by Priority

```
priority is high
priority is above medium
priority is below high
priority is not none
has priority
no priority
```

---

## Field Ordering

### Recommended Order

```markdown
- [ ] Description #tags [repeat:: rule] [start:: date] [scheduled:: date] [due:: date] [priority:: level]
```

### Rules

1. **Checkbox first**: `- [ ]` or `- [x]`
2. **Description immediately after checkbox**
3. **Tags within or after description** (before metadata fields)
4. **Metadata fields after description and tags**
5. **Done date auto-appended** when task completed

### Valid Examples

```markdown
- [ ] Call mom #todo [due:: 2024-01-15]
- [ ] #todo Review PR [scheduled:: 2024-01-10] [priority:: high]
- [ ] Weekly standup #todo #work [repeat:: every week on Monday] [scheduled:: 2024-01-08]
```

### Invalid Patterns to Avoid

```markdown
- [ ] [due:: 2024-01-15] Task description  ❌ Fields before description
- [ ] Task [due:: 2024-01-15] #todo  ❌ Tags after fields may cause issues
```
