# Fable review follow-up — September 8

This pass implements Tony's settled review decisions. Changes remain uncommitted for review; no live skill sync, activation, or Nix rebuild was performed.

## Fixes

- `agent-run` readers share the startup lock, so status cannot observe the pre-launch record as interrupted. Completion is checked again after the tmux liveness probe.
- Interrupted runs expose surviving result-file presence and provider session metadata recovered from the log. `acknowledge ID --interrupted` explicitly retires an inspected interrupted run. `start --resume-from ID` accepts interrupted runs with a captured session; running runs remain rejected, and absent sessions require a self-contained handoff. This does not prove an interrupted worker made no edits: inspect the result, log, and diff before recovery.
- Claude accepts the existing validated access choices plus `plan`. Model reporting reads `modelUsage`, retaining all reported models and setting the singular field only when unambiguous. No raw provider-flag escape hatch was added. Command-argv persistence is called out in help.
- Applied Tony's delegation paragraph verbatim, moved wait arming beside helper discovery, simplified browser routing, and corrected the Python typo. Preserved the surrounding voice.
- Clarified Helium's isolated agent profile, narrowed agent-browser's description, removed the misplaced Claude-mode sentence from codex-review, and made diagnosing-bugs' description match manual invocation.
- Corrected current show-me decisions, linked HTML verification guidance, repaired the Stillsuit path, replaced the stale skills index with discovery instructions, and aligned Pi's separately managed dependency-source copy. Pi is still outside sync-agent-skills.
- Sync rejects unknown hosts before mutation. Tests cover missing-SKILL.md filtering and removal of its managed link.

## Verification and limits

- Seven agent-run tests passed, including real isolated tmux-server termination, interrupted acknowledgment and resume, retained results with nonzero exit, Claude result/model/session parsing, completion during liveness checking, and status blocked during startup. Sync tests, Ruff, shell syntax and whitespace checks passed.
- Installed CLIs: Claude Code 2.1.263 and codex-cli 0.153.4. Claude advertises low/medium/high/xhigh/max effort and plan mode. Despite omitting default from its help choices, it accepted default in live print-mode runs. The helper's four effort values are supported by the CLI; only low was used for provider smoke runs, medium for the watcher trial.
- Two fresh low-effort runs per provider, each followed by a resumed follow-up: all eight completed, with exact SMOKE_OK / RESUME_OK results and preserved provider session IDs. Claude reported claude-fable-5-1. Codex accepted gpt-5.6-sol and honored exec-level --json and -o on resume, but emitted no model field: reported_model remains null rather than asserting independently verified identity.
- A real Claude review under default inspected the actual sync diff and reproduced the exact guard with no permission denials. Its suggestions about allowing arbitrary-host previews and deduplicating the three-name error message were not adopted: the former contradicts the requested guard; the latter is optional maintenance style, not a demonstrated defect. A completed process still does not certify review quality.
- Fresh Fable 5.1 medium watcher trial with the revised globals appended: initial run was blocked before launch by print-mode permissions. One retry used a temporary allowance restricted to the helper command. After a compound command was denied, the direct launch succeeded; the next tool call armed wait with run_in_background=true and then used TaskOutput. No prompt reminder about waits was included. The retry could read completion status but was denied a separate log read; Astra independently confirmed WATCHER_OK in the log. Fable also declined acknowledgment as outside scope, so acknowledgment behavior remains an ordinary-use observation. This is one successful arming observation, not evidence of wakeups after a stopped coordinator or reboot.
- Dry-run succeeded locally on Jacurutu against this checkout and remotely on Sietch using the revised script against Sietch's current source tree. No remote candidate-tree activation was performed. Bad-host rejection and no-mutation behavior were verified with the isolated sync fixture.

Scratch run records, CLI outputs, and watcher traces are under `/tmp/agent-review-smoke/` on Jacurutu; they are ephemeral, not installed configuration. No production data or credentials are included in this report.

## Ordinary-use follow-up

After Tony activates, observe for a week: unsolicited HTML, unsolicited show-me, whether Helium was the appropriate choice, orphan/duplicate run recovery, and actual use of the three manual workflows. Change one description at a time. Broad benchmarks and additional paired reviews are not prerequisites.

## Subsequent access-mode decision

Tony selected automatic approval review for new provider runs. Omitted access now defaults to auto: Claude uses --permission-mode auto; Codex uses --approve-for-me (workspace-write with automatic approval review). Explicit restricted modes remain available, and resumed runs preserve their recorded access. Both review entrypoints request auto. No permission-bypass flags are used. The earlier trials above used default/read-only. Command construction, CLI parsing and eight lifecycle regression tests passed; the subsequent auto-mode trial is recorded below.

## Auto-mode trial

One fresh helper run per provider with access omitted, each followed by a resumed follow-up: all four completed with exact SMOKE_OK / RESUME_OK output, recorded access=auto, and preserved session IDs.

A fresh Claude Fable 5.1 medium coordinator used permission-mode auto with the revised globals and no additional allowedTools rule. It launched the three-second command worker, immediately armed the background wait, received completion, and read WATCHER_OK from the log. The result reported zero permission denials. The worker remained unacknowledged, accurately reported by the coordinator.

This supports trying the current interface under auto during ordinary work; no extra allowlist or output operation is needed based on this trial. It does not establish that every future auto review will approve, or that a stopped coordinator can be awakened. Scratch evidence: /tmp/agent-review-smoke/auto-runs/ and watcher-auto.jsonl on Jacurutu. Installed settings remain unchanged.
