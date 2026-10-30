# Meeting minutes pipeline

`bin/meeting-minutes` turns a Stillsuit recording into a Coppermind meeting note. The jacurutu user service `meeting-minutes-worker` runs it straight from the dotfiles checkout. Siren transcribes the recording, fixed Python code reads calendar, Google Meet notes, and Slack through Executor, and Codex identifies speakers and writes the minutes. Notes go to `01-logs/meetings/`; the structured result, transcript, recording, and split audio tracks go to `~/media/meetings/` and move to Sietch. Agent-facing details of the note format live in `agents/skills/coppermind/references/meeting-artifacts.md`.

`meeting-minutes regenerate <note-or-stem> --out <dir>` reruns generation for an existing meeting without touching the vault, proposals, weekly log, or job queue.

## Isolation

Codex reads text from outside the vault (transcripts, Slack messages, Meet notes, calendar entries), so it runs without tools. It uses a pipeline-owned `CODEX_HOME` at `~/.local/state/meeting-minutes/codex-home` (`MEETING_MINUTES_CODEX_HOME`). The pipeline rewrites its `config.toml` on every run: no MCP servers, hooks, plugins, connectors, sub-agents, shell, web search, or project trust. `auth.json` there is a symlink to `~/.codex/auth.json`; Codex refreshes tokens in place, so the login stays shared. Before a process sends any meeting content, it asks Codex to list MCP servers and features for that home, then runs once against a local stand-in model and reads the tool list it would send. Anything unexpected stops the job. A Codex upgrade that adds a built-in tool therefore fails closed with "unexpected tools"; review the tool and update `CODEX_EXPECTED_TOOLS` deliberately.

Meeting sessions live under that home, not `~/.codex/sessions`. To inspect one by hand, run Codex with `CODEX_HOME=~/.local/state/meeting-minutes/codex-home`.

Executor is called directly with an API key read from `~/.config/meeting-minutes/executor-env` (agenix `secrets/executor/meeting-minutes.age`). Only the read operations in `EXECUTOR_READ_OPERATIONS` can run.

## Rollout

- **Restart the worker after the checkout changes.** A running worker keeps the code it loaded. Wait for `meeting-minutes jobs` to show no actionable jobs, or stop it with `systemctl --user stop meeting-minutes-worker.service`; the path unit and timer start it again. Jobs already in flight regenerate their minutes from the saved transcript, because older work directories have no recorded inputs.
- **The recorder needs a rebuild.** `stillsuit-recorder` and its `meeting-minutes enqueue` helper are built into the Nix store. Until jacurutu rebuilds, recordings keep one mixed audio track, which the pipeline handles as a legacy recording.
- **The Executor key can come later.** Without the key file, notes are still written, but without calendar, Meet, or Slack context, and every meeting sends a "Meeting calendar lookup failed" notification. To enable it, mint an API key in Executor, store it as `EXECUTOR_API_KEY=...` with `agenix -e secrets/executor/meeting-minutes.age`, and rebuild. The secret is wired for jacurutu and sietch and stays inactive until that file exists.
- **Separate audio tracks need more storage.** Recordings with desktop audio and the microphone carry three audio tracks instead of one. With the mixed track around 120 kb/s and video around 600 kb/s, the two extra tracks add up to about a third to each MP4, roughly 110 MB per meeting hour, and the extracted `.desktop.mka` and `.microphone.mka` copies add about the same again on Sietch.
- **The people registry is a draft.** Until `04-projects/people.toml` and `04-projects/glossary.toml` exist in the vault, the pipeline reads the legacy `04-projects/*/people.md` rosters and uses no glossary.
