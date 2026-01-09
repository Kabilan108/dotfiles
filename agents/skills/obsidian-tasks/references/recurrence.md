# Recurrence Rules Reference

## Table of Contents
- [Basic Syntax](#basic-syntax)
- [Intervals](#intervals)
- [Specific Days](#specific-days)
- [Monthly Patterns](#monthly-patterns)
- [Yearly Patterns](#yearly-patterns)
- [Completion-Based Recurrence](#completion-based-recurrence)
- [How Recurrence Works](#how-recurrence-works)
- [Date Relationships](#date-relationships)

---

## Basic Syntax

Dataview format:
```markdown
- [ ] Task [repeat:: every <interval>]
```

All recurrence rules start with `every`.

---

## Intervals

### Simple Intervals

```markdown
[repeat:: every day]
[repeat:: every week]
[repeat:: every month]
[repeat:: every year]
```

### Numbered Intervals

```markdown
[repeat:: every 2 days]
[repeat:: every 3 weeks]
[repeat:: every 6 months]
[repeat:: every 2 years]
```

### Weekday Shortcut

```markdown
[repeat:: every weekday]
```

Equivalent to Monday through Friday.

---

## Specific Days

### Day of Week

```markdown
[repeat:: every Monday]
[repeat:: every Tuesday, Thursday]
[repeat:: every week on Friday]
[repeat:: every 2 weeks on Monday]
```

### Multiple Days

```markdown
[repeat:: every Monday, Wednesday, Friday]
[repeat:: every week on Tuesday, Thursday]
```

---

## Monthly Patterns

### Day of Month

```markdown
[repeat:: every month on the 1st]
[repeat:: every month on the 15th]
[repeat:: every month on the last day]
[repeat:: every month on the last]
```

### Ordinal Weekday

```markdown
[repeat:: every month on the first Monday]
[repeat:: every month on the second Tuesday]
[repeat:: every month on the third Friday]
[repeat:: every month on the last Friday]
```

### Multiple Months

```markdown
[repeat:: every 3 months on the 1st]
[repeat:: every 2 months on the last Friday]
```

---

## Yearly Patterns

### Specific Date

```markdown
[repeat:: every year on January 1st]
[repeat:: every January on the 15th]
[repeat:: every year on December 25th]
```

### Month and Ordinal

```markdown
[repeat:: every year on the third Monday of January]
[repeat:: every November on the fourth Thursday]
```

---

## Completion-Based Recurrence

By default, recurrence calculates next date from the **original due date**.

Use `when done` to calculate from **completion date**:

```markdown
[repeat:: every week when done]
[repeat:: every 2 days when done]
[repeat:: every month when done]
```

### Difference Example

**Without `when done`** (date-based):
```
Original: due 2024-01-01, repeat every week
Complete on 2024-01-05 → Next: 2024-01-08 (original + 1 week)
```

**With `when done`** (completion-based):
```
Original: due 2024-01-01, repeat every week when done
Complete on 2024-01-05 → Next: 2024-01-12 (completion + 1 week)
```

Use `when done` for habits and tasks that should happen a fixed time after completion (e.g., "water plants every 3 days" = whenever you last watered).

---

## How Recurrence Works

### On Completion

1. Original task is marked done with `[done:: date]`
2. New task is created (above or below, per settings)
3. New task has updated dates based on recurrence rule
4. Recurrence rule is preserved on new task

### Task Status Changes

Only status changes from TODO → DONE trigger recurrence.

- `[ ]` → `[x]` ✓ Creates next occurrence
- `[/]` → `[x]` ✓ Creates next occurrence  
- `[ ]` → `[-]` ✗ Cancellation, no recurrence
- `[ ]` → `[/]` ✗ Progress, no recurrence

---

## Date Relationships

When a recurring task has multiple dates, they maintain relative relationships.

### Example

```markdown
- [ ] Task [repeat:: every 2 weeks] [start:: 2024-01-01] [scheduled:: 2024-01-05] [due:: 2024-01-07]
```

Relationships:
- Start is 6 days before due
- Scheduled is 2 days before due

After completion, all dates shift by recurrence interval, maintaining relationships:
```markdown
- [ ] Task [repeat:: every 2 weeks] [start:: 2024-01-15] [scheduled:: 2024-01-19] [due:: 2024-01-21]
```

### Reference Date Priority

For calculating next occurrence:
1. Due date (if present)
2. Scheduled date (if no due)
3. Start date (if no due or scheduled)

---

## Invalid Patterns

These are **not supported**:

```markdown
[repeat:: every day for 10 times]     ❌ Count limits
[repeat:: every day until 2024-12-31] ❌ End dates
[repeat:: every other day]            ❌ Use "every 2 days"
```

---

## Common Patterns

### Daily Habits
```markdown
- [ ] Morning journal #todo [repeat:: every day] [scheduled:: 2024-01-01]
```

### Weekly Meetings
```markdown
- [ ] Team standup #todo [repeat:: every week on Monday] [scheduled:: 2024-01-08]
```

### Bi-weekly
```markdown
- [ ] Sprint review #todo [repeat:: every 2 weeks on Friday] [due:: 2024-01-12]
```

### Monthly Bills
```markdown
- [ ] Pay rent #todo [repeat:: every month on the 1st] [due:: 2024-02-01]
```

### Quarterly Reviews
```markdown
- [ ] Quarterly goals review #todo [repeat:: every 3 months] [due:: 2024-04-01]
```

### Annual
```markdown
- [ ] File taxes #todo [repeat:: every year on April 15th] [due:: 2024-04-15]
```

### Flexible Habits (when done)
```markdown
- [ ] Water plants #todo [repeat:: every 3 days when done] [scheduled:: 2024-01-01]
- [ ] Clean desk #todo [repeat:: every week when done] [scheduled:: 2024-01-01]
```
