# Draft implementation for review

September 7. Source changes are uncommitted; no live skill sync, provider configuration activation, cache deletion, publication, Nix rebuild, or Moberg rollout was performed.

## Start here

- [x] `agents/claude/CLAUDE.md` and `agents/codex/AGENTS.md`: short shared operating policy, explicit delegation, model choices, browser routing, and reference discovery. Claude's old ranking table and duplicated launch recipes are removed. Unslop is unchanged.
- [x] `agents/references/publication.md` and `empirical-review.md`: single homes for publication scope and behavioral review evidence.
- `agents/skills/html-communication/`, `dependency-source/`, and `executor/`: renamed/consolidated capabilities. Rich HTML assets and service references are preserved. The old dependency cache is untouched; future source work uses `~/.agents/vendored-deps`.
- `agents/skills/grilling/`, `diagnosing-bugs/`, and `create-verification-skill/`: small adapted trials with upstream attribution. Grilling and verification-skill creation are manual-only.
- `show-me` and `terminal-control`: manual-only metadata in both harness formats. Show-me's visual examples remain; its platform-specific open instruction is adapted.
- `bin/agent-run`: batch worker lifecycle, distinct from interactive `launch-agent`. Explicit access/model/effort, private state directory, real exit status, provider result/session capture, resume, reconciliation and acknowledgment. `model` is the requested model; `reported_model` is populated only when provider output supplies it. No guessed actual model attribution.
- `bin/sync-agent-skills`: preview mode and host selection, with Niri limited to Jacurutu and protection against replacing foreign links.

## Niri scope evidence

Six observed load archives: three Omasnap sessions, one dotfiles session, one Coppermind/TaskNotes session, and one Moberg session (the last included the user's correction toward Helium). IDs:

- Omasnap: `019ff6b5-7dbe-7b32-9d87-c62a0a8ee0d3`, `019ff94b-1d57-7e83-b0cf-24326a67ae61`, `01a02b55-77cb-7962-b0d3-627be3f4a2dc`.
- Dotfiles: `01a02efa-7aef-7ba1-9702-d5f8d1d886ff`.
- Coppermind: `01a03bc1-04ad-7751-a86b-b27980516a3d`.
- Moberg: `8ee4ad0f-e074-4323-be4d-06454bc76325`.

Niri stays globally available on Jacurutu, across projects. Stillsuit plugin development moves to `.agents/skills/stillsuit-plugin/` in dotfiles. The existing `.claude/skills -> ../.agents/skills` bridge makes the project-local folder visible to Claude; Codex uses the existing `.agents` project layout. This is source-layout verification, not a fresh paid agent discovery trial.

## Completed checks

- Lifecycle tests with isolated tmux sockets and trivial/fake workers: actual success/failure status, timeout followed by fresh-process reconciliation and completion, duplicate run ID rejection, missing provider result, captured session resume preserving read-only access, and acknowledgment filtering.
- Sync tests in a temporary fake checkout: dry-run makes no links, Jacurutu gets Niri, switching to Sietch removes only the managed Niri link, foreign links survive, and name collisions cannot replace a foreign link.
- Ruff checks for the new helper and tests; shell syntax check; Git whitespace check.
- YAML/name/invocation checks across all 27 current source skills, including project-local skills. The bundled Codex validator rejects Claude-only frontmatter fields even in existing skills; those supported cross-harness fields were retained and checked separately.
- Installed provider CLI help checked for model, effort, output, and resume flags. Live TaskNotes configuration and example task frontmatter inspected; the Coppermind conventions now match note-per-task storage.

Tests are in `tests/agent-tools/`. No paid provider runs, automatic browser sweep, or multi-model evaluation was used. Real provider authentication, model availability, and automatic notification delivery after a coordinator turn ends remain runtime concerns. The helper does not claim to wake a stopped coordinator; globals describe the available wait mechanism and restart recovery.

## Review notes

New files are marked intent-to-add so ordinary `git diff` includes their contents and detects moves. No file contents are staged and nothing is committed. Historical audit documents retain old paths as evidence; current decisions and this file describe the implementation.

Moberg lifecycle, concrete initial glossary, and application verification recipes remain in [moberg-follow-up.md](moberg-follow-up.md). The general creator skill is implemented; no project verification skill was generated without a real project exercise.
