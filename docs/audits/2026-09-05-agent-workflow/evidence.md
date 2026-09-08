# Audit evidence and limitations

## Collection

Collected on September 5, 2026, using Tracer 0.2.2. Commands:

```sh
tracer skill
tracer list --json --since 720h
ssh sietch-agent 'tracer list --json --since 720h'
tracer get 01a036b6-01cf-7083-99e8-b3fee71ba828 --tool-output=none --turns=user,agent
```

Tracer's local listing/get startup required archive write access even though these commands only read. They were run outside the filesystem sandbox after automatic approval. No sync, tagging, annotation, archive regeneration, or remote mutation was performed.

Sietch's listing includes ingested Jacurutu records. Deduplication used host, provider, and session ID, retaining the newer metadata. Selected Sietch archive files were streamed read-only into local temporary storage. Local archive files were read directly. The transcript parser restricted observations to dated turns from August 7 onward, so resumed sessions with older start dates did not automatically contribute their pre-window content.

The scanner recognized both Codex skill-file read attempts and Claude `Skill` calls, including Tracer's “Launching skill” and rendered input formats. It ignored ordinary tool output for load detection. The counts in [usage.json](usage.json) are independently inspectable session-ID sets.

The archive records do not provide a reliable root/child relationship for this analysis. Forks can inherit the same history, and automation sessions are present. Accordingly, counts are reach signals across session records, not rates per independent task. A tool read attempt can fail, and truncated tool inputs can hide a load. We did not calculate successful-use rates, wasted tokens, cost savings, or causal effects of individual instructions.

Metadata lists 459 records; 238 archives were retained after automatic approval-review and empty-agent exclusions. There are 84 retained archives with content in the primary August 23–September 5 window. These were mechanically screened, followed by focused reading of the workstreams below. This was not a manual line-by-line review of all 238 transcripts. Automatic skill-content injections, tool outputs, generated continuations, and task notifications were not treated as ordinary human prompting examples.

## Focused session evidence

Resolve laptop sessions with `tracer get ID --tool-output=none --turns=user,agent`. For Sietch sessions, run the same command through `ssh sietch-agent`. Historical assistant claims below describe what the session reported, not a fresh rerun of its code.

| Session and host | Dates examined | Observation | Audit implication |
|---|---|---|---|
| `ae822177-5d59-40fc-b5af-5d9c79c3e306`, Sietch | Aug 30–Sep 1 | Review Relay implementation explicitly loaded milestone delegation, HTML plans, Codex implementation, and adversarial probe review. User selected Sol/medium, a named tmux workspace, a simple HTML log, and continued execution. The lead reported independent tests, browser smoke checks, paired review, and fixes. | Keep the useful implementation loop. Consolidate mechanical launch/watch/resume instructions rather than discarding the capability. |
| Same session | Aug 30–Sep 1 | Several “Continue from where you left off” turns follow rate-limit errors or a timeout. Some subsequent replies say “No response requested,” followed by another user nudge. | Do not count all nudges as model laziness. Separate runtime failure, resumption behavior, and actual premature completion. |
| `2548068d-7085-4f79-a1f5-08d94c8bfc62`, Sietch | Sep 3–5 | Customer integration branches, manual QA, image build requests, deployed-state investigation, and handoff updates. Several Sep 3 nudges follow an explicit Claude CLI minimum-version error or session limit. | Preserve build, review, deploy, and reconciliation states separately. A persistence prompt cannot fix an incompatible client. |
| `52d0f072-22d6-4308-844e-692a768e5ee9`, Sietch | Aug 30 | User requested a memory audit, removed stale 5.5 review-pairing memory, and requested 5.6 updates plus a review-pairing sentence in Claude guidance. The final response names the files changed. | The review-pairing rule was intentional and recent. Narrowing it now is a proposed preference change, not cleanup of an accidental rule. |
| `d443951d-085e-47a9-9c14-29beaa773fd0`, Jacurutu | Aug 30–31 | Stillsuit plan/review coordination, model rate-limit failures, handoff to Codex, and user caution about scarce Fable capacity. | Keep model choice configurable. Preserve completion state and review ownership through provider changes. |
| `019ffd88-be59-7442-8c05-396a482036ed`, Sietch | Aug 13–Sep 1 | Helium-based performance work; the user later authorized steps 1–6 and explicitly paused before step 7, with a notification if needed. | Rich prompts already convey precise boundaries. Carry those boundaries into handoffs instead of flattening them into blanket autonomy. |
| `8ee4ad0f-e074-4323-be4d-06454bc76325`, Jacurutu | Aug 7 | User asked why Niri computer use was being selected and requested Helium DevTools instead. | Direct evidence for clearer browser/native-desktop routing. |
| `019ff136-1555-7d13-80b8-a6368bba39a9` and `cddf8dc4-684f-4373-a4b2-087c08666f48`, Jacurutu | Aug 11 and later in-window continuation | Source-to-runtime profiling of a reported rendering regression using Helium. | Preserve environment and measurement guidance. Browser use is substantive engineering work here. |
| `01a0159e-0500-7281-94e7-faa7de1c5706` and `01a0159f-616a-7532-8808-7893d4d75427`, Sietch | Aug 18 | One delegated browser check failed before shell commands could execute because of bubblewrap. Another completed the requested eight checks and reported screenshots. | Distinguish infrastructure failure from application failure and verification success. |
| `01a02abe-ac30-7260-89a6-17687b240eb6`, Sietch | Aug 22 | PageBin interaction work encountered blocked storage/clipboard behavior and opaque-origin iframe inspection limits. The report separated artifact publication, local worker changes, and production verification. | Keep useful browser evidence while reducing automatic full-page QA for unchanged report layouts. |
| `01a036b6-01cf-7083-99e8-b3fee71ba828`, Jacurutu | Aug 25–27 | The agent initially followed the doubled vault path, then searched for the real root. Later the user requested inspection of tmux pane `%40` and simplification of redundant import testing and shell code. | Wrong universal path causes wasted work. Tmux pane access is useful; permanent tests should be proportional. |
| `019ffcc4-32d9-7421-a875-824118158ba5`, Sietch | Aug 13–Sep 2 | User scoped dependency-pin changes, rejected unnecessary machinery, requested a review, and gave dashboard-specific test constraints. | Put repository-specific scope and test rules in project guidance. Do not generalize them across the stack. |
| `01a04e99-3cb2-7300-9d92-b6929af2e360`, Sietch | Aug 29 | User accepted focused upload-hashing tests while negotiating deployment/build constraints. | “No tests anywhere” would contradict other explicit preferences. |
| `01a02039-8d10-7740-b2d1-340c3c8181ed`, Sietch | Aug 20–30 | User evaluated Herdr, described T3 Code as the primary agent orchestration layer, and deferred full tmux removal. | Treat tmux as supporting infrastructure, not the universal agent interface. |
| `019fdd93-1e88-7161-8c63-e360bb02b195`, Jacurutu | Aug 7 | Linked-PR review loaded code walkthrough and promised a Navi tour. | Rare observed use exists; check project review callers before removing this skill. |

## Configuration evidence

The audited worktree starts at `2c5103931089f10df1227f1b79e927eb1888e211`. It was clean before report creation. Personal source directories contain 24 shared skills, five Claude-only skills, and one Codex-only skill.

The sync script, Coppermind skill, HTML plans skill, and global Claude instructions have matching SHA-256 hashes between the inspected checkout and Sietch. All files under the personal skill source roots were compared against the laptop's main dotfiles checkout; differences were found in Niri's skill, two references, and `acu`. Those source-only differences were preserved. The report does not assume that the worktree's background-window feature is installed.

Relevant locations:

- `bin/sync-agent-skills:142`: unconditional shared-skill fan-out to agent directories.
- `home/shell.nix:107`: Home Manager activation calls the skill sync script.
- `agents/skills/coppermind/SKILL.md:10`: universal doubled-root assertion.
- `agents/claude/CLAUDE.md:59`: universal paired-review rule.
- `agents/claude/CLAUDE.md:81`: background job recommendation, conflicting with the implementation skill.
- `agents/codex/AGENTS.md:11`: explicit opt-in to subagents.
- `agents/claude-skills/codex-implementation/SKILL.md:32`: model-unpinned command shape; `:46` detached-process policy.
- `agents/claude-skills/codex-review/SKILL.md`: command examples should have model/access behavior verified together before revision. This audit did not launch a nested reviewer or validate every CLI example.
- `agents/skills/review-bot-gate/SKILL.md:39`: overly broad green-CI disproof wording.
- `agents/skills/html-plans/SKILL.md:13`: inactive playground dependency; `:15` recipe/template routing; `:57` mandatory checkpoint publication pattern.
- `agents/skills/helium-browser-use/references/remote.md`: manual tunnel uses plain SSH despite the Fleet agent-alias rule.
- `agents/skills/code-walkthrough/agents/openai.yaml`, `agents/skills/terminal-control/agents/openai.yaml`: Codex manual invocation metadata, without corresponding Claude frontmatter.
- `agents/skills/README.md`: lists missing or moved entries such as create-spec, spec-driven-build, librarian, fasthtml, and oracle as if active.

Live manifest-existence checks established opposite vault layouts on the two hosts. No vault contents were moved. Niri symlinks were confirmed in Sietch's Claude and Codex skill directories; Hyprland was found in PATH there and Niri was not. This supports host filtering without requiring a speculative Hyprland automation project.

## External sources

Both libraries were cloned read-only into `/tmp`; no plugin or skill installation was run.

Matt Pocock library at `3cca18b368ae95cdbdebbff572ccafa662551015`:

- [Grilling](https://github.com/mattpocock/skills/blob/3cca18b368ae95cdbdebbff572ccafa662551015/skills/productivity/grilling/SKILL.md): useful deliberate questioning, but the exhaustive interview and automatic delegation need adaptation.
- [Domain modeling](https://github.com/mattpocock/skills/blob/3cca18b368ae95cdbdebbff572ccafa662551015/skills/engineering/domain-modeling/SKILL.md): terminology and selective ADRs.
- [Diagnosing bugs](https://github.com/mattpocock/skills/blob/3cca18b368ae95cdbdebbff572ccafa662551015/skills/engineering/diagnosing-bugs/SKILL.md): repeatable observable failure, hypotheses, and verification. Its ban on progressing without a repro is too strict for access-limited investigations.
- [TDD](https://github.com/mattpocock/skills/blob/3cca18b368ae95cdbdebbff572ccafa662551015/skills/engineering/tdd/SKILL.md): behavioral checks and independent expected values; mandatory approval of every test boundary is a poor default here.
- [Wait-what](https://github.com/mattpocock/skills/blob/3cca18b368ae95cdbdebbff572ccafa662551015/skills/productivity/wait-what/SKILL.md): overlaps the existing `bro` command.

Cursor plugins at `93b00b89ef425a9c1bac0d0b317dfc49c930ac99`:

- [Project verification generator](https://github.com/cursor/plugins/blob/93b00b89ef425a9c1bac0d0b317dfc49c930ac99/pstack/skills/create-verification-skill/SKILL.md): ground the instructions in the repo and execute a real feature before considering the recipe complete.
- [Encode lessons in structure](https://github.com/cursor/plugins/blob/93b00b89ef425a9c1bac0d0b317dfc49c930ac99/pstack/skills/principle-encode-lessons-in-structure/SKILL.md): use mechanisms for recurring rules.
- [Eval playbook](https://github.com/cursor/plugins/blob/93b00b89ef425a9c1bac0d0b317dfc49c930ac99/pstack/skills/poteto-mode/playbooks/eval.md): compare behavior without telling candidate agents what is being scored; adapt transcript inspection to Tracer.
- [Babysit playbook](https://github.com/cursor/plugins/blob/93b00b89ef425a9c1bac0d0b317dfc49c930ac99/pstack/skills/poteto-mode/playbooks/babysit.md): distinguish status inspection, repair, merge-ready, and human approval.
- [Poteto mode](https://github.com/cursor/plugins/blob/93b00b89ef425a9c1bac0d0b317dfc49c930ac99/pstack/skills/poteto-mode/SKILL.md): its large mandatory instruction chain would add process debt if imported whole.

Model guidance was fetched directly:

- [Astra](https://developers.openai.com/api/docs/guides/latest-model?model=gpt-6-astra).
- [Fable 5.1](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5-1).
- [Codex skill metadata](https://learn.chatgpt.com/docs/build-skills).
- [Claude skill invocation controls](https://code.claude.com/docs/en/skills).

## Videos

All five supplied videos had downloadable English automatic captions. Relevant passages were read with timestamps. At the user's suggestion, all five were also extracted successfully with `summarize '<video-url>' --extract --timestamps --youtube web --no-slides --plain --timeout 45s`. The CLI reported `transcript/captionTracks`; normalized transcript text matched the earlier extraction for every video. This is a second retrieval of the same captions, not independent transcription or visual verification. The follow-up read broader passages, recorded below, and revised the audit and proposed wording. This does not establish details visible only in demonstrations, and caption spellings of model names are imperfect. No full transcripts are copied into these reports.

| Video | Passage examined | Contribution |
|---|---|---|
| [It's Here](https://www.youtube.com/watch?v=XFWpf0wLbh0&t=2215s) | About 36:55–40:15 | Examples of review follow-through failures and overly long review loops. Treat as Theo's experience, not a measured failure rate in your archive. |
| [My New Favorite Model](https://www.youtube.com/watch?v=r_dw-1109Ag&t=1786s) | About 29:46–38:05 | Model-specific prompting discussion, including progress, dense writing, completion, and scope. Use official guidance for the actual model behavior claims. |
| [Turn off Claude Code's Memory](https://www.youtube.com/watch?v=Jf54k7tFeEc&t=1746s) | About 3:22–4:36, 13:17–18:31, and 21:40–30:40 | Stale copied context and a preference for structural prevention before more instructions. Does not by itself establish that all of your memory is harmful. |
| [So I tried Matt's skills](https://www.youtube.com/watch?v=0oXOOlqVu5M&t=1686s) | About 3:14–16:40 and 28:06–31:00 | Audit actual usage, adapt selected ideas, keep deliberate questioning and writing help without importing a full mandatory process. |
| [My AGENTS.md & SKILLS.md Breakdown](https://www.youtube.com/watch?v=e1snsuY4lTI&t=2939s) | About 3:04–26:49 and 45:04–50:57, including the supplied 48:59 offset | Descriptions control triggering; separate HTML communication and transport; preserve update identity; simplify rather than blindly copy a setup. |

## What remains unproven

- No controlled comparison of revised prompts versus current prompts was performed.
- The session sample is not enough to compare Astra, Fable 5.1, and Sol by quality or cost.
- We did not prove that every skill load succeeded or every loaded instruction affected behavior.
- No exhaustive audit of vendor plugins, every project-local skill, or current TaskNotes schemas was performed.
- No modernized CLI delegation helper, host-selection changes, or Hyprland adapter was implemented.

The report and inventory are concrete recommendations for your second pass. Configuration changes and any broader migration remain separate work.
