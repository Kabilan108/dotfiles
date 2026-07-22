# Google Calendar

## Read a schedule

Use:

- `calendar.calendarList.list`
- `calendar.events.list`

1. Resolve and describe both exact tool names.
2. List visible calendars with `showDeleted: false`, `showHidden: false`, and pagination. Unless the user narrows the scope, include every entry whose `selected` value is not `false`.
3. For every included calendar, paginate `events.list` with RFC 3339 `timeMin` and exclusive `timeMax`, `timeZone: "America/New_York"`, `singleEvents: true`, `orderBy: "startTime"`, and `showDeleted: false`.
4. Preserve the source calendar on each event. Read timed events from `dateTime`; read all-day events from `date`, whose end date is exclusive. Keep multi-day events that overlap the requested window even when they began earlier.
5. Preserve status, event type, transparency, location, organizer, and the user's attendee response only when they affect the requested summary. Treat `transparent` events as informational rather than busy time.

Retrieval is complete when the calendar list and every included calendar's event list have no remaining page token or each failed calendar is named explicitly.

## Summarize

- Present events in the requested timezone and distinguish all-day from timed events.
- Consolidate repeated events only when each occurrence remains countable.
- Surface overlaps, deadlines, and events continuing past the displayed range.
- Report included calendars with zero events when coverage matters.

The schedule is complete when every displayed event can be traced to its source calendar and the visible range matches the stated boundaries.
