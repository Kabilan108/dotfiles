# Delegation completion and wakeup audit

## Finding

The recent archives do not show a coordinator receiving a successful worker completion and then silently forgetting it. In the primary August 23 through September 5 window, I found 30 worker-related stop notifications across 27 task IDs. Twenty-seven notifications reported completion and three reported failure. Every completion notification led to a coordinator response that read, summarized, verified, or acted on the result.

The real failure modes sit on either side of that handoff:

1. A detached tmux worker does not wake the coordinator unless the coordinator also starts a harness-owned watcher.
2. That watcher disappears when the coordinator process or session restarts, even though the tmux worker survives.
3. A child-agent failure can reach the coordinator while the coordinator is subject to the same provider error. Delivery succeeded, but recovery then needed a later user turn or a fresh session.

This matters for the proposed tmux standard. Tmux is the right default for a long-lived shell worker because it survives a coordinator restart. Tmux alone is incomplete. The usable pattern is a durable worker, an ephemeral wakeup watcher, and a small durable record that lets a restarted coordinator reconstruct both.

## Scope and method

I used the 238 retained archives from the existing audit extraction. Eighty-four have content in the primary August 23 through September 5 window. The extraction normalizes each record to session metadata plus ordered user, agent, and tool parts. I mechanically found `<task-notification>` records, then read every worker-related notification and its following coordinator turns in the primary window. I treated repeated stop notifications for the same task ID as separate notification events and one logical task ID.

The broad August 7 through September 5 scan found 73 task-notification records. That number includes CI polling, ordinary background shell commands, monitor events, and orphan summaries, so it is not a delegation denominator. The defensible primary-window denominator is below.

| Event type | Notification events | Unique task IDs | Completed events | Failed events |
|---|---:|---:|---:|---:|
| Native child agents | 20 | 17 | 17 | 3 |
| Detached Codex runs with background completion watchers | 10 | 10 | 10 | 0 |
| Total worker-related | 30 | 27 | 27 | 3 |

The 30 events represent 27 task IDs because two native agents were resumed and completed again, and one native agent first failed and then completed under the same task ID. At the task-ID level, 25 of 27 reached a completed state in the observed transcript. Two ended failed. One additional failure event recovered and later completed.

All 27 successful completion events received visible follow-through. This is a selected sample of archived coordinator sessions, not a controlled reliability test. A worker that finished in tmux without any watcher would leave no task notification to count. That selection bias is exactly why zero ignored delivered completions does not prove zero unwitnessed completions.

## Episode classification

### Successful completion and prompt follow-through

Session `ae822177-5d59-40fc-b5af-5d9c79c3e306` is the clearest tmux case. It ran from `2026-08-30T17:53:34.504Z` to `2026-09-01T02:46:03.724Z` on Sietch. The coordinator launched long Codex jobs in the `diffshub-poc` tmux session and armed harness-owned background loops that watched for the `-o` report or a dead tmux window.

There were ten watcher completions in this session. The coordinator consumed every one. Two exact examples also show that the behavior was not confined to one coordinator model:

| Timestamp | Event | Coordinator action |
|---|---|---|
| `2026-08-30 19:03:26Z` | M0-U1 watcher completed | Fable 5 responded at `19:03:32Z`, checked whether the report existed or the tmux job died, then read and verified the work. |
| `2026-08-30 22:13:04Z` | M1-U1 watcher completed | Opus 4.8 responded at `22:13:08Z`, read the report and diff, and continued verification. |

The same session handled M0-U2, M0-U3, the M0 Codex review, three fix runs, M1-U2, M1-U3, the M1 fix, and M2-U1 in the same way. Native agent completions in that session also led to action: the M1 probe was combined with the Codex review, the SPA browser result led to cleanup and a checkpoint commit, and the code-search result led to visual verification.

Session `2548068d-7085-4f79-a1f5-08d94c8bfc62`, from `2026-09-03T19:44:31.839Z` through `2026-09-05T21:02:14.625Z`, contains nine successful native-agent notification events across eight task IDs. Each result was used in the integration plan, implementation, QA, or diagnosis. Examples include the fixture import warning, the paging and event-review conflict, the source-DSA overlap, hot-storage behavior, timeline spacing, preload expansion, and the pink-smear investigation. One source-DSA agent was resumed and generated a second completed notification under the same task ID.

Session `48e3406c-5433-4245-bf7c-2be0b05951b0` has two completed notifications for the same Google Slides worker after a correction. Both were consumed. Session `d443951d-085e-47a9-9c14-29beaa773fd0` has three successful native-agent completions. All three were summarized for the user.

### A user check that looks like forgetting but is not

The closest candidate is `d443951d-085e-47a9-9c14-29beaa773fd0` on August 31. The services/plugins reviewer completed at `03:30:43Z`. Fable 5 summarized its blocker, three majors, nine minors, and clean checks at `03:30:50Z`. At `03:37:31Z`, the user asked whether that reviewer had completed. The coordinator answered at `03:37:37Z` with the same completion state and noted that only the Nix review remained.

This was a redundant status check, not an ignored worker. The coordinator had already acknowledged and summarized the result seven minutes earlier. It may still indicate that a long parallel review needs a clearer compact status ledger, because a prose update amid several active reviewers is easy to miss.

### Delivered failure, recovery blocked by the same provider

The same `d443951d-...` session shows two Fable child failures caused by 429 cooldowns.

- The services/plugins agent failed at `03:26:38Z`. The coordinator received the failure, preserved its progress by resuming the same task, and got a successful completion at `03:30:43Z`.
- The Nix reviewer failed at `03:43:10Z`. The coordinator itself then returned a synthetic 429 at `03:46:05Z`. A user continuation at `15:14:11Z` produced `No response requested`, and the next compacted session explicitly recorded the Nix review as unfinished. This is a provider-capacity interruption with an unrecovered worker, not a finished worker that the coordinator forgot.

Session `2548068d-...` shows the same distinction with client compatibility. At `2026-09-03 21:56:24Z`, the smear-fix agent failed before editing because Claude Code 2.1.220 did not support `claude-fable-5-1`. The coordinator returned the same error on the next turns. After three user nudges and one `No response requested`, Fable 5.1 recovered at `21:58:50Z`, recognized that the child had made no edits, and implemented the fixes directly. A later session-limit message caused more delay. The notification path worked; the runtime could not execute the selected model.

### Harness restart and lost watcher evidence

Two older sessions show what restart recovery currently looks like for harness-owned background work:

- `0330ca11-cbcb-4d6d-a046-1ff5b10b653f` received an orphan summary on August 18 for two shell tasks with no completion record. The coordinator identified them as stale compile watchers and confirmed that both verdicts had already been collected.
- `c1deea30-3e49-47bf-b46f-6bae65557fdc` received an orphan summary on August 20 for two prior-session shell tasks. A new user report arrived in the same turn, and the coordinator moved to that issue.

These orphan notices do not prove that a delegated worker finished unseen. They do prove that the harness can lose completion records for background shell tasks across teardown or restart. The current milestone-delegation skill says to re-check every in-flight tmux run and re-arm its watcher after a restart. That rule matches the observed boundary: tmux persists, the background watcher does not.

### Intentional pause

Human-review gates must remain separate from wakeup failures. Session `019ffd88-be59-7442-8c05-396a482036ed` authorized implementation steps 1 through 6 and explicitly required a pause before step 7 so the user could choose patients and decide the acceptance-test setup. Waiting there is correct behavior even if all delegated work has finished.

## Transport comparison

| Property | Native child agent | Direct `run_in_background` shell worker | Detached tmux worker plus watcher |
|---|---|---|---|
| Wakes the active coordinator | Yes, with a task notification | Yes, when the command exits | Yes, only through the separate watcher |
| Worker survives coordinator restart | Not established by this sample | No, current instructions say it is tied to the Claude process | Yes |
| Wakeup survives coordinator restart | No guarantee | No | No, the watcher must be rebuilt |
| Clean completion artifact | Result embedded in notification | Command output file | `codex -o` report, plus log |
| Failure distinction | Native completed or failed state | Exit status and output | Watcher must distinguish report-ready from tmux-exited-without-report |
| Best use | Bounded work within one live coordinator session | Short commands and polling | Long shell delegation and Codex CLI work |

The current instructions conflict. `agents/claude/CLAUDE.md:81` says long tasks should use Bash `run_in_background`. The implementation skills say runs longer than a few minutes should use detached tmux because a Claude restart kills background children. The milestone loop has the complete hybrid rule: detached tmux for durability, followed immediately by a harness-owned background watcher for wakeup.

The helper `bin/tmux-resurrect-agents` solves a different problem. It records the Claude session ID on a pane and rewrites tmux-resurrect commands so Claude or Codex resumes the exact session. It does not record delegated jobs, report paths, completion state, or watchers. It cannot reconstruct the missing wakeup edge by itself.

## Model attribution

The archive cannot support a quality ranking among Astra, Fable 5.1, and Sol for coordinator follow-through.

- No retained archive has Astra coordinator metadata in the audited set.
- Only seven retained primary-window archives mention Fable 5.1, which is too small and selected for any rate estimate.
- The key sessions have mixed model metadata. The raw transcript can attribute individual turns in a few examples, but a session-level success or failure cannot be assigned to one model.
- In `ae822177-...`, Sol was the delegated Codex worker. Fable 5 and Opus 4.8 were coordinator models. Calling the whole episode a Sol coordination result would mix worker and coordinator roles.
- Both Fable 5 and Opus 4.8 reacted within seconds to tmux watcher completions in that session. This shows the mechanism works with both. It does not establish equal reliability.
- The clearest failures have explicit non-model causes: Fable provider cooldowns, an unsupported Claude CLI version, session limits, and synthetic continuation turns that returned `No response requested`.

The right conclusion is mechanism-first. The sample is strong enough to improve completion tracking and restart recovery. It is not strong enough to choose a coordinator model based on wakeup reliability.

## Recommended completion contract

Standardize long shell delegation on detached tmux, but make the following pieces one contract rather than optional advice.

1. Create a unique durable run record before launch. Record a run ID, coordinator session ID, task label, transport, tmux target, worker session ID when available, prompt path, log path, report path, launch time, expected terminal marker, and next action. A stable state directory is a better home than an undocumented temporary filename.
2. Launch the tmux worker with a unique report file. Treat a nonempty report as clean completion only when the CLI guarantees `-o` is written on clean exit.
3. Arm the watcher immediately. It should check for the report first, then check tmux liveness. Its output should say `report-ready` or `worker-exited-no-report`, rather than returning exit 0 for both cases.
4. Feed native child notifications and tmux watcher notifications into the same coordinator queue. Use explicit states such as `running`, `completed-unreviewed`, `completed-reviewed`, `failed-retryable`, `failed-terminal`, and `awaiting-human`.
5. Acknowledge completion only after reading the report. For implementation work, require diff inspection and the chosen verification before moving the record to `completed-reviewed`.
6. On every session start or resume, reconcile the run records before taking new work. Read completed reports, inspect dead tmux jobs with no report, re-arm watchers for live jobs, and retain intentional human gates.
7. Before launching a native child, preflight model and client compatibility. A version error is deterministic and should fail before consuming a worker slot.
8. When a child fails from a provider cooldown, preserve the task ID and partial result. Retry once after cooldown or route to an allowed alternate provider. If the coordinator shares the outage, leave a persistent retry state for the next session rather than relying on repeated user nudges.
9. Show a compact active-work table in long parallel sessions. The `d443951d-...` status question suggests that clear per-worker state is useful even when the coordinator did process the notification.

The implementation skills should converge on this contract. In particular, the global instruction to run long tasks directly with `run_in_background` should not remain alongside the detached-tmux requirement. Short-lived shell polling can stay harness-owned. The actual long worker should live in tmux, with its wakeup and recovery state recorded separately.

## Limits

This audit can count delivered notifications. It cannot see a tmux worker that completed without a watcher unless another turn later mentions the result. The archives also do not reliably encode parent-child relationships across forked histories, and task IDs can notify more than once after resume. The primary-window episodes came from four coordinator archives with worker notifications, so the sample is concentrated in a few large workstreams.

I did not launch workers, change skills, or change agent configuration. The recommendations are a design for the user's second pass, not an implemented migration.
