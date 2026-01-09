# Common Examples

## Table of Contents
- [Daily Views](#daily-views)
- [Weekly Views](#weekly-views)
- [Project Dashboards](#project-dashboards)
- [Priority Views](#priority-views)
- [Status-Based Views](#status-based-views)
- [Habit Tracking](#habit-tracking)
- [Review Queries](#review-queries)
- [Template Snippets](#template-snippets)

---

## Daily Views

### Today's Tasks

````markdown
```tasks
not done
(due today) OR (scheduled today)
sort by priority
```
````

### Overdue + Today

````markdown
```tasks
not done
due before tomorrow
sort by due
sort by priority
```
````

### Today with Sections

````markdown
```tasks
not done
(due today) OR (scheduled today) OR (due before today)
group by function task.due.moment?.isBefore(moment(), 'day') ? '⚠️ Overdue' : 'Today'
sort by priority
```
````

### What I Can Do Today

Tasks that have started (start date passed) but aren't done:

````markdown
```tasks
not done
(has start date) AND (start before tomorrow)
no scheduled date
no due date
sort by start
```
````

---

## Weekly Views

### This Week's Tasks

````markdown
```tasks
not done
due this week
group by due
sort by priority
```
````

### Next 7 Days

````markdown
```tasks
not done
due before in 7 days
group by due
sort by due
```
````

### Weekly Schedule

````markdown
```tasks
not done
(scheduled this week) OR (due this week)
group by function task.scheduled.moment?.format('dddd') ?? task.due.moment?.format('dddd') ?? 'Unscheduled'
sort by scheduled
```
````

---

## Project Dashboards

### Tasks in Specific Folder

````markdown
```tasks
not done
path includes Projects/MyProject/
sort by due
sort by priority
```
````

### Project Overview with Grouping

````markdown
```tasks
path includes Projects/
group by folder
group by status.type
sort by due
```
````

### Exclude Archive

````markdown
```tasks
not done
path does not include Archive/
path does not include Templates/
sort by due
```
````

---

## Priority Views

### High Priority Only

````markdown
```tasks
not done
priority is above medium
sort by due
```
````

### Priority Dashboard

````markdown
```tasks
not done
has priority
group by priority
sort by due
limit groups 5
```
````

### Urgent (High Priority + Due Soon)

````markdown
```tasks
not done
priority is above medium
due before in 3 days
sort by due
sort by priority
```
````

---

## Status-Based Views

### In Progress

````markdown
```tasks
status.type is IN_PROGRESS
sort by due
```
````

### Blocked/Waiting

If using custom `-` status for blocked:

````markdown
```tasks
status.symbol is -
sort by due
```
````

### Recently Completed

````markdown
```tasks
done
done after last week
group by done
sort by done reverse
```
````

### Completed Today

````markdown
```tasks
done
done today
sort by done reverse
```
````

---

## Habit Tracking

### Daily Habits Due Today

````markdown
```tasks
not done
is recurring
recurrence includes day
(due today) OR (due before today)
sort by description
```
````

### All Recurring Tasks

````markdown
```tasks
not done
is recurring
group by recurrence
sort by due
```
````

### Overdue Habits

````markdown
```tasks
not done
is recurring
due before today
sort by due
```
````

---

## Review Queries

### Tasks Without Due Dates

````markdown
```tasks
not done
no due date
no scheduled date
path does not include Templates/
sort by created reverse
limit 20
```
````

### Old Unfinished Tasks

Tasks created more than 30 days ago still not done:

````markdown
```tasks
not done
created before 30 days ago
sort by created
```
````

### All Tasks by File

````markdown
```tasks
group by filename
sort by status
```
````

### Tasks Created This Week

````markdown
```tasks
has created date
created after last week
group by created
sort by created reverse
```
````

---

## Template Snippets

### Daily Note Template

````markdown
## 🎯 Today's Focus

```tasks
not done
(due today) OR (scheduled today) OR (due before today)
path does not include Templates/
short mode
hide backlink
hide task count
sort by priority
```

## ✅ Completed Today

```tasks
done today
short mode
hide backlink
hide task count
```
````

### Weekly Note Template

````markdown
## 📅 This Week

```tasks
not done
happens this week
group by due
short mode
hide backlink
```

## ✅ Done This Week

```tasks
done
done this week
group by done
short mode
hide backlink
```
````

### Project Note Template

````markdown
## 📋 Active Tasks

```tasks
not done
path includes {{title}}
group by status.type
sort by priority
sort by due
```

## ✅ Completed

```tasks
done
path includes {{title}}
sort by done reverse
limit 10
```
````

---

## Advanced Patterns

### Tasks Due by End of Quarter

````markdown
```tasks
not done
filter by function task.due.moment?.quarter() === moment().quarter() && task.due.moment?.year() === moment().year()
sort by due
```
````

### Tasks Tagged with Specific Person

````markdown
```tasks
not done
tags include #waiting-on
description includes @John
sort by due
```
````

### Combine Multiple Folders

````markdown
```tasks
not done
(path includes Work/) OR (path includes Projects/)
path does not include Archive/
sort by due
```
````

### Short Display for Dashboards

````markdown
```tasks
not done
due before in 7 days
short mode
hide tags
hide task count
hide backlink
hide edit button
limit 10
```
````
