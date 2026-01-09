---
name: obsidian-tasks
description: "Work with the Obsidian Tasks plugin for task management. Use when creating, editing, querying, or managing tasks in an Obsidian vault. Covers Dataview inline field format (primary), query syntax, filters, sorting, grouping, recurrence rules, priorities, and custom statuses. Trigger on: task queries, todo management, task filtering, recurring tasks, task dashboards, or any work involving `- [ ]` checkbox items with metadata."
---

# Obsidian Tasks Plugin

The Tasks plugin enables task management across an Obsidian vault. Tasks are standard Markdown checkboxes with optional metadata for dates, priority, recurrence, and status.

## Task Format Overview

This vault uses **Dataview format** (inline fields with `[key:: value]` syntax), not emoji format.

### Basic Task Structure

```markdown
- [ ] Task description [due:: 2024-01-15] [priority:: high]
- [x] Completed task [done:: 2024-01-10]
- [/] In progress task
- [-] Cancelled task
```

### Available Fields (Dataview Format)

| Field | Syntax | Purpose |
|-------|--------|---------|
| Due date | `[due:: YYYY-MM-DD]` | When task must be completed |
| Scheduled date | `[scheduled:: YYYY-MM-DD]` | When to work on task |
| Start date | `[start:: YYYY-MM-DD]` | When task becomes available |
| Created date | `[created:: YYYY-MM-DD]` | When task was created |
| Done date | `[done:: YYYY-MM-DD]` | Auto-added on completion |
| Priority | `[priority:: highest/high/medium/low/lowest]` | Task importance |
| Recurrence | `[repeat:: every day]` | Recurring task rules |

### Task Statuses

| Status | Markdown | Type |
|--------|----------|------|
| Todo | `- [ ]` | TODO |
| Done | `- [x]` | DONE |
| In Progress | `- [/]` | IN_PROGRESS |
| Cancelled | `- [-]` | CANCELLED |

## Query Blocks

Query tasks using fenced code blocks with `tasks` language:

````markdown
```tasks
not done
due before tomorrow
sort by priority
```
````

### Essential Query Instructions

**Filtering:**
- `done` / `not done` - completion status
- `due today` / `due before tomorrow` / `due after 2024-01-01`
- `scheduled this week` / `starts before today`
- `priority is high` / `priority is above medium`
- `path includes Projects/` / `path does not include Archive/`
- `description includes meeting`
- `has due date` / `no due date`
- `is recurring` / `is not recurring`

**Sorting:**
- `sort by due` / `sort by due reverse`
- `sort by priority` / `sort by created` / `sort by done`

**Grouping:**
- `group by due` / `group by priority` / `group by filename` / `group by folder`

**Display:**
- `limit 10` - max results
- `short mode` - compact display
- `hide tags` / `hide task count` / `hide backlink`

### Global Task Filter

This vault uses `#todo` as the global task filter. Only tasks containing `#todo` are recognized by the plugin.

## Reference Files

- **Detailed query syntax**: See [references/queries.md](references/queries.md)
- **Task format details**: See [references/task-format.md](references/task-format.md)
- **Recurrence rules**: See [references/recurrence.md](references/recurrence.md)
- **Common examples**: See [references/examples.md](references/examples.md)

## Working in This Vault

When modifying task-related files:

1. **Check Obsidian settings** at `.obsidian/plugins/obsidian-tasks-plugin/data.json` for:
   - Global task filter configuration
   - Task format preference (should be Dataview)
   - Custom status definitions
   - Default date behavior

2. **Preserve existing task metadata** - don't strip fields when editing tasks

3. **Use consistent date format**: `YYYY-MM-DD`

4. **Place fields after description**: `- [ ] Description [due:: 2024-01-15]`

5. **Tags go before or within description**, not after metadata fields
