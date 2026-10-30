# Meeting artifacts

Pipeline-written meeting notes name the artifacts in frontmatter.

Run `meeting-minutes transcript <meeting-note>` to print the speaker-labeled transcript with timestamps. Add `--json` when the original JSON structure or segment metadata matters. The transcript path is available on Jacurutu and Sietch after synchronization.

`minutes_data` points at `<stem>.minutes.json` next to the transcript: the full structured result the note was rendered from. It holds the speaker mapping (diarized label → person, confidence, evidence), the calendar lookup per source and the matched event, the gathered Slack and Google Meet context, the transcript anchors, the minutes themselves with each item's cited anchor IDs and derived time ranges, the coverage-review and citation-repair outcomes, and validation warnings. Read it instead of re-parsing the Markdown when an agent needs who said what or where in the transcript a point came from.

Sietch holds the durable MP4 copy at the note's `recording` path. The pipeline removes the Jacurutu copy after a successful transfer. From Jacurutu, use `ssh sietch-agent` when an agent needs to inspect or retrieve the recording.

Recordings made with both desktop audio and the microphone carry three audio tracks: 0 is the mix (what players and transcription use), 1 is desktop audio, and 2 is the microphone. `artifacts.audio_tracks` in the minutes data records the layout, and `artifacts.source_tracks` names the stream-copied `<stem>.desktop.mka` and `<stem>.microphone.mka` files published next to the transcript. Older recordings have one mixed track and no source tracks. The desktop track starts a few tens of milliseconds after the mix and microphone, by an amount that differs per recording, so align it by cross-correlation before comparing or combining tracks.

## Note format

- `calendar_status` is `matched`, `no_match`, or `unavailable`; `calendar_event` and `calendar_event_start` name the matched event. `calendar_errors` lists every source that failed or only partly answered; any entry there means Tony was notified, and `unavailable` means no source answered.
- `## notes` has one `###` section per topic. Each bullet ends with the transcript time ranges it was checked against, such as `[12:04–12:31]`, in the same clock as `meeting-minutes transcript`. `[no transcript citation]` marks an item the pipeline could not tie to the transcript; treat it as unverified. A `<details>` block after the bullets attributes opinions and advice to named speakers.
- `## decisions` lists only explicit conclusions and is often `- None`. `## ideas raised` lists undecided suggestions with who raised them.
- `## follow-ups`: only Tony's own actions are checkboxes; other people's commitments are `**Name** — action (timeframe)` bullets.
- Speakers the pipeline could not identify appear as `Unknown (likely A or B)` or `Unknown speaker`, in attendees and prose. Replace them by hand when you know who it was; raw `SPEAKER_NN` labels never appear in a note.

## Regenerating

`meeting-minutes regenerate <note-or-stem> --out <dir>` reruns the whole generation into `<dir>` (rendered note, `.minutes.json`, gathered context, Codex logs) without touching the vault, proposals, weekly log, or job queue. Pass `--transcript <json>` to use an alternate transcript with the same schema, `--reuse-context <earlier-dir>` to hold calendar and context lookups fixed for a comparison, and `--screenshots` to rerun the screenshot pass against the recording. A directory only resumes for identical inputs; after changing the transcript, registry, glossary, or reused context, use a new `--out` or pass `--fresh`.
