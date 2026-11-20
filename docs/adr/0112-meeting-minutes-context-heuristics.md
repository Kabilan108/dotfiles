# Meeting-minutes context and speaker heuristics

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The pipeline turns diarized transcripts and gathered context into minutes. Diarization produces short spurious speakers from cross-talk or a cough. Cited claims need to point near what was said. Slack conversations that set up a meeting often never name the other participant in the transcript. Microsoft Graph may return mail pages shorter than `$top`.

## Decision

- Unknown speakers with less than `UNKNOWN_SPEAKER_MIN_SECONDS` (15 s) of talk stay in the result JSON but are left out of attendees.
- Citation anchors merge one speaker's consecutive segments up to `ANCHOR_MAX_SECONDS` (25 s) with gaps of at most `ANCHOR_MAX_GAP_SECONDS` (3 s), so every cited claim lands within half a minute of what was said.
- Slack channels that were active just before or during the meeting are searched as context even when no transcript name points to them, because that is often how the meeting was arranged (a DM asking for a call, a huddle starting).
- Email paging follows Graph's next link rather than computing offsets, since pages can come back short. The pipeline test's `mail_page` fake returns short pages to cover this.

## Consequences

The thresholds are tuned on Tony's recordings; changing them changes attendee lists and citation ranges in new notes.

## Where

- `bin/meeting-minutes` (`UNKNOWN_SPEAKER_MIN_SECONDS`, `ANCHOR_MAX_SECONDS`, `ANCHOR_MAX_GAP_SECONDS`, the Slack `active_channels` search, email paging)
- `tests/test_meeting_minutes_pipeline.py` (`mail_page`)
