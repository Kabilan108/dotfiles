# Meeting minutes: follow-up handoff

Read this before picking up work on `bin/meeting-minutes`, Siren diarization, or the meeting registry. It records the state as of November 2, 2026, after the P1 reliability work landed on `nixos` (last commit `b1ea5dcc`). Recheck runtime state before acting.

How the pipeline works, its commands, isolation and rollout steps are in `docs/meeting-minutes.md`. The note format agents read is in `agents/skills/coppermind/references/meeting-artifacts.md`. `git log -- bin/meeting-minutes` shows what changed and why. This file covers only what those don't: decisions Tony made along the way, open items, and known gaps.

This repo is public. Keep real names, meeting content, Slack messages and transcript excerpts out of it, including out of commit messages and issues on public repos (Siren is public too). Use the vault for anything specific.

## Decisions to keep

- **Model:** `gpt-6.1-sol` at medium effort on the fast tier. Tony chose medium over high.
- **Context sources:** calendar (Google and Outlook) first, then Meet notes, then Slack and Outlook email. Slack means the Moberg workspace only, and Outlook means the Moberg work account. Every read is fixed Python code calling the allowlisted operations in `EXECUTOR_READ_OPERATIONS`. No model that reads meeting content gets tools.
- **Speaker identification:**
  - Mapping a label to Tony needs high confidence.
  - Someone outside the registry needs a self-introduction, or an outside source (calendar, Meet, Slack, email) plus a mention in the transcript. A name said only in conversation is never enough, because people talk about partners and friends who aren't there and ASR mishears names.
  - Unknown speakers show as "Unknown (likely X)" and never as `SPEAKER_NN`.
- **People proposals:** only for people who spoke in meetings where Tony also spoke. Webinars and talks propose no one. Don't add a person Tony hasn't confirmed; he declined one case outright.
- **Glossary proposals:** only when a gathered source spells the term, and code checks the quoted text.
- **Citations:**
  - Each item cites at most 3 ranges.
  - A range is at most 3 lines and 60 seconds, or an unbroken stretch of up to 90 seconds.
  - Spots within 10 seconds are merged.
- **Registry:** `04-projects/people.toml` and `glossary.toml` in the vault. The old `people.md` rosters are retired.
- **Personal chat:** private-life talk stays out of work-meeting notes (`PERSONAL_RULE`). Tony asked that it not over-correct. Work talk before or after the call, conference news and professional connections stay. Personal meetings are exempt.
- **Siren:** the speaker smoothing from siren#4 is on (`SIREN_SPEAKER_SMOOTHING` in `modules/nixos/selfhost/siren.nix`). Tony judged 26 of 27 folds correct. Nemotron diarization was tried and rejected because it was worse on his audio. The branch `diarization-nemotron` is kept on GitHub for reference.
- **Siren changes** go on a branch with a dev instance; Tony deploys to sietch himself.

## Open items

1. **Publish the fixed November 2 note.** A corrected regenerate of that morning's office meeting sits in `/vault/scratch/mm-regen/2026-11-02-eeg/`. One label is still "Unknown (likely ...)" for someone who also has a confirmed label, so that person appears twice in the attendees. Tony can rerun the regenerate with `--speaker SPEAKER_03=<id> --fresh`, then run `meeting-minutes publish <dir>`. Check `meeting-minutes regenerate --help` for the rest.
2. **Roll `b1ea5dcc` out to jacurutu.** The worker there runs from its checkout. Pull, then restart the worker as `docs/meeting-minutes.md` describes. Tony runs rebuilds himself.
3. **Echo measurement.**
   - **Setup:** in the office, remote voices reach Tony's laptop mic through a colleague's speakers and also arrive through Zoom desktop audio, 250–380 ms apart. Tony keeps the mic on (muted in Zoom) to capture talk in the room after the call. At home he uses headphones.
   - **Still unmeasured:** the first three-track office recording (November 2) can't answer it, because Zoom audio barely reached the desktop track.
   - **Next step:** on the next office recording with working Zoom audio, compare the `.desktop.mka` and `.microphone.mka` tracks, measure the offset, and count the extra or duplicated labels and misattributions the echo causes.
   - **Default:** do nothing. If the echo clearly hurts, the only option Tony is open to is the simple rule: transcribe the desktop track, and keep mic speech only where the desktop track is silent, with no call or headphone detection. Report the numbers to him and don't build anything without his approval. He questioned whether any fix is worth the extra places the pipeline can break.
4. **Owner voiceprint.** Filed as [siren#6](https://github.com/Kabilan108/siren/issues/6) and deferred. Pick it up only if the owner keeps going unidentified in real recordings. Tony asked that it not be handled in meeting-minutes threads.
5. **Dedicated meeting-notes service** ("Quire"): dotfiles issue #25.

## Known gaps not yet raised with Tony

- **Unrelated Slack conversations.** Slack context pulls in any conversation active near the meeting start (`SLACK_ACTIVE_SECONDS`). On November 2 that brought in an unrelated DM, which is now stored in that meeting's `minutes.json`. Consider tightening this before relying on Slack context further, and ask Tony first.
- **Unrelated email.** Email context keeps any message a likely attendee sent or received within an hour of the meeting (`EMAIL_ATTENDEE_ONLY_SECONDS`). Someone senior is on many threads, so this can store unrelated mail, including clinical-site threads, in `minutes.json`. Watch the first few meetings' `context.email.messages` and tighten it if needed.
- **Ad hoc meetings miss the calendar.** Office meetings without an invite get `calendar_status: no_match`, so speaker ID falls back to the transcript and the registry.
- **Lint and format drift.** `ruff check` and `ruff format --check` already fail on `bin/meeting-minutes` (import order, one `with` statement). The drift predates this work; leave it unless Tony asks.

## Verifying changes

```
nix-shell -p 'python3.withPackages(p:[p.pytest])' --run 'python -m pytest -q tests/test_meeting_minutes_*.py' > /tmp/mm-tests.out 2>&1; echo "exit=$?"
```

All 90 tests passed at `b1ea5dcc`. For behavior on real meetings, run `meeting-minutes regenerate <stem> --out /vault/scratch/<dir>` on sietch, which never touches the vault, and compare it with the published note. `/vault/scratch/meeting-compare/build.py` builds a before/after comparison site from regenerate outputs. Serve it only on the tailnet, never through PageBin, since it holds meeting content.

## Pointers

- **Agent memory:** `~/.claude/projects/-home-kabilan-dotfiles/memory/meeting-minutes-p1-state.md`.
- **Original session:** `c46cabe4-b307-4c75-a63e-ca84f4bcc5e5`, findable with `tracer`.
- **Moberg data policy:** `04-projects/moberg/data-policy.md` in the vault. The minutes prompt includes it.

## Suggested skills

- `coppermind`: vault write zones, people and glossary registry, proposals.
- `transcribe`: Siren jobs and transcripts.
- `executor`: calendar, Slack, and Outlook reads when debugging context gathering.
- `fleet`: jacurutu worker rollout and sietch Siren service.
- `tracer`: reading the original session for detail.
- `unslop`: any prose written for Tony.
