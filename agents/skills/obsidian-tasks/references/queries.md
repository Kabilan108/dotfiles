# Query Reference

## Table of Contents
- [Query Block Syntax](#query-block-syntax)
- [Status Filters](#status-filters)
- [Date Filters](#date-filters)
- [Priority Filters](#priority-filters)
- [Path and Location Filters](#path-and-location-filters)
- [Text Filters](#text-filters)
- [Tag Filters](#tag-filters)
- [Recurrence Filters](#recurrence-filters)
- [Sorting](#sorting)
- [Grouping](#grouping)
- [Display Options](#display-options)
- [Combining Filters](#combining-filters)
- [Custom Filters (Advanced)](#custom-filters-advanced)

---

## Query Block Syntax

````markdown
```tasks
<filter>
<filter>
<sort instruction>
<group instruction>
<display option>
```
````

Each line is a separate instruction. Lines starting with `#` are comments.

---

## Status Filters

### Basic Status

```
done
not done
```

### Status Type

```
status.type is TODO
status.type is IN_PROGRESS
status.type is DONE
status.type is CANCELLED
status.type is not TODO
```

### Status Symbol

```
status.symbol is x
status.symbol is /
status.symbol is -
status.symbol is (space character)
```

### Status Name

```
status.name is Todo
status.name includes Progress
```

---

## Date Filters

### Date Fields

Each date field supports the same filter patterns:
- `due`
- `scheduled`
- `start`
- `created`
- `done`
- `happens` (matches any of: due, scheduled, start)

### Absolute Dates

```
due on 2024-01-15
due before 2024-02-01
due after 2024-01-01
due on or before 2024-01-31
```

### Relative Dates

```
due today
due tomorrow
due yesterday
due before today
due after tomorrow
due this week
due next week
due last week
due this month
due in 7 days
due before in 3 days
```

### Date Existence

```
has due date
no due date
has scheduled date
no start date
```

### Special: "Happens" Filter

`happens` matches if ANY of due/scheduled/start matches:

```
happens today
happens before tomorrow
has happens date
```

---

## Priority Filters

```
priority is highest
priority is high
priority is medium
priority is low
priority is lowest
priority is none

priority is above medium
priority is below high
priority is not none

has priority
no priority
```

---

## Path and Location Filters

### File Path

```
path includes Projects/
path does not include Archive/
path includes Daily Notes/2024
```

### Folder

```
folder includes Work
folder does not include Personal
```

### Filename

```
filename includes meeting
filename does not include template
```

### Root (Top-Level Folder)

```
root includes Projects
root is Personal
```

### Heading

```
heading includes Sprint
heading does not include Done
```

---

## Text Filters

### Description

```
description includes call
description does not include optional
description regex matches /^Review/
```

### Case Sensitivity

By default, text matching is case-insensitive. Use regex for case-sensitive:

```
description regex matches /Meeting/
```

---

## Tag Filters

```
tags include #work
tags include #todo
tags do not include #someday
tag includes project
has tags
no tags
```

Note: `tags include` requires the `#` prefix; `tag includes` does not.

---

## Recurrence Filters

```
is recurring
is not recurring
recurrence includes weekly
recurrence does not include month
```

---

## Sorting

### Sort Instructions

```
sort by <property>
sort by <property> reverse
```

### Sortable Properties

```
sort by due
sort by scheduled
sort by start
sort by created
sort by done
sort by priority
sort by description
sort by path
sort by filename
sort by status
sort by status.name
sort by tag
sort by urgency
```

### Multiple Sorts

List in order of precedence:

```
sort by priority
sort by due
sort by description
```

### Reverse Order

```
sort by due reverse
sort by priority reverse
```

---

## Grouping

### Group Instructions

```
group by <property>
```

### Groupable Properties

```
group by due
group by scheduled
group by start
group by done
group by priority
group by status
group by status.name
group by status.type
group by path
group by folder
group by filename
group by root
group by heading
group by backlink
group by recurrence
group by tags
```

### Multiple Groups

Creates nested groups:

```
group by folder
group by priority
```

### Reverse Grouping

```
group by due reverse
```

---

## Display Options

### Limiting Results

```
limit 10
limit to 5 tasks
limit groups to 3
limit groups 5
```

### Hiding Elements

```
hide backlink
hide task count
hide priority
hide recurrence rule
hide due date
hide scheduled date
hide start date
hide created date
hide done date
hide tags
hide edit button
```

### Short Mode

Compact display with icons instead of text:

```
short mode
```

### Show/Hide All

```
show urgency
show backlink
```

---

## Combining Filters

### Boolean Logic

**AND (implicit)**: Each line is AND-ed together:

```
not done
due before tomorrow
priority is high
```

**OR**:

```
(due today) OR (scheduled today)
(path includes Work) OR (path includes Projects)
```

**NOT**:

```
NOT (tags include #someday)
NOT (path includes Archive)
```

**Complex combinations**:

```
(due before tomorrow) AND ((priority is high) OR (priority is highest))
NOT ((path includes Archive) OR (path includes Templates))
```

### Parentheses

Use parentheses to control evaluation order:

```
((due today) OR (scheduled today)) AND (priority is above low)
```

---

## Custom Filters (Advanced)

For complex logic, use JavaScript expressions:

### Filter by Function

```
filter by function task.due.moment?.isSame(moment(), 'week')
filter by function task.priority >= 2
filter by function task.description.length < 50
```

### Accessing Task Properties

In `filter by function`, access task properties:

| Property | Description |
|----------|-------------|
| `task.description` | Task text |
| `task.status.symbol` | Status character |
| `task.status.name` | Status name |
| `task.status.type` | Status type string |
| `task.priority` | Priority number (0-5, 0=highest) |
| `task.due.moment` | Due date as Moment.js object |
| `task.scheduled.moment` | Scheduled date |
| `task.start.moment` | Start date |
| `task.done.moment` | Done date |
| `task.created.moment` | Created date |
| `task.happens.moment` | Earliest of due/scheduled/start |
| `task.tags` | Array of tags |
| `task.file.path` | File path |
| `task.file.folder` | Folder path |
| `task.file.filename` | Filename |
| `task.isRecurring` | Boolean |
| `task.recurrence` | Recurrence object |

### Examples

Tasks due within 3 days:
```
filter by function task.due.moment?.isBetween(moment(), moment().add(3, 'days'), 'day', '[]')
```

Tasks in specific folder with high priority:
```
filter by function task.file.folder === 'Projects' && task.priority <= 2
```

### Sort by Function

```
sort by function task.description.length
sort by function task.due.moment?.unix() ?? Infinity
```

### Group by Function

```
group by function task.due.moment?.format('MMMM YYYY') ?? 'No Date'
group by function task.priority === 0 ? 'Critical' : task.priority <= 2 ? 'High' : 'Normal'
```

---

## Query Debugging

### Explain

Add to see how the query is interpreted:

```
explain
```

Outputs detailed breakdown of each filter instruction.
