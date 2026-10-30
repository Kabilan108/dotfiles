# Meeting artifacts

Pipeline-written meeting notes name the artifacts in frontmatter.

Run `meeting-minutes transcript <meeting-note>` to print the speaker-labeled transcript with timestamps. Add `--json` when the original JSON structure or segment metadata matters. The transcript path is available on Jacurutu and Sietch after synchronization.

`minutes_data` points at `<stem>.minutes.json` next to the transcript: the full structured result the note was rendered from. It holds the speaker mapping (diarized label → person, confidence, evidence), the calendar lookup per source and the matched event, the gathered Slack and Google Meet context, the minutes themselves with citations in seconds, the coverage-review outcome, and validation warnings. Read it instead of re-parsing the Markdown when an agent needs who said what or where in the transcript a point came from.

Sietch holds the durable MP4 copy at the note's `recording` path. The pipeline removes the Jacurutu copy after a successful transfer. From Jacurutu, use `ssh sietch-agent` when an agent needs to inspect or retrieve the recording.

## Note format

- `calendar_status` is `matched`, `no_match`, or `unavailable`; `calendar_event` and `calendar_event_start` name the matched event. `unavailable` means every calendar source failed and Tony was notified.
- `## notes` has one `###` section per topic. Each bullet ends with transcript time ranges such as `[12:04–13:10]`, in the same clock as `meeting-minutes transcript`. A `<details>` block after the bullets attributes opinions and advice to named speakers.
- `## decisions` lists only explicit conclusions and is often `- None`. `## ideas raised` lists undecided suggestions with who raised them.
- `## follow-ups`: only Tony's own actions are checkboxes; other people's commitments are `**Name** — action (timeframe)` bullets.
- Speakers the pipeline could not identify appear as `Unknown (likely A or B)` or `Unknown speaker`, in attendees and prose. Replace them by hand when you know who it was; raw `SPEAKER_NN` labels never appear in a note.

## Regenerating

`meeting-minutes regenerate <note-or-stem> --out <dir>` reruns the whole generation into `<dir>` (rendered note, `.minutes.json`, gathered context, Codex logs) without touching the vault, proposals, weekly log, or job queue. Pass `--transcript <json>` to use an alternate transcript with the same schema, `--reuse-context <earlier-dir>` to hold calendar and context lookups fixed for a comparison, and `--screenshots` to rerun the screenshot pass against the recording.
