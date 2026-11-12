# Commit checks and Stillsuit tests

The root dev shell pins the hook tools through `flake.lock`. From the repository
root, install the Git hook shim once per checkout:

```sh
direnv exec "$PWD" prek install
```

The hooks run through `direnv exec .`. direnv blocks `.envrc` in a new git
worktree until it is approved, so run `direnv allow` once in each worktree
before committing.

Commits run the checks in `prek.toml` against selected staged files. The checks
leave source files unchanged. To run checks before staging, pass explicit paths:

```sh
direnv exec "$PWD" prek run --files flake.nix scripts/niri-validate
```

Nix checks use nixfmt, Statix and deadnix. ShellCheck selects shell files by type,
including extensionless scripts with a shell shebang, and checks warnings and
errors. Sourced Bash fragments need `# shellcheck shell=bash` when they have no
shebang. Inline scripts remain in Nix; `writeShellApplication` checks its generated
script during builds. Other inline scripts need explicit build or test coverage.

QML checks compare files with qmlformat output and reject syntax errors. Format
files you change before staging:

```sh
direnv exec "$PWD" qmlformat -i path/to/Component.qml
```

The QML formatting baseline is applied repository-wide. The intentionally
malformed `Broken.qml` plugin fixtures are excluded from QML hooks.

Qt 6.12's formatter silently fails on ordinary properties named `id`.
`core/HostNotice.qml`, `tests/tray/fixture-shell.qml`, and
`workbench/FixtureModels.qml` under `packages/stillsuit-shell/src` are excluded
from formatting only, while syntax checking remains enabled. Retry them when
updating Qt; keep their public properties intact.

Full QML linting is a manual hook while existing dynamic-property and other
diagnostics are reviewed. It resolves Qt, Quickshell and local Stillsuit modules
and fails on warnings as well as errors:

```sh
direnv exec "$PWD" prek run qmllint --stage manual --files path/to/Component.qml
```

## Stillsuit verification

The `stillsuit-fast` commit hook runs for changes under `packages/stillsuit-shell`
or `modules/home/stillsuit`, changes to its runner, and root flake/lock changes.
Run it directly with:

```sh
direnv exec "$PWD" scripts/stillsuit-check-fast
```

This runner covers launcher models, clipboard and notification models, bar source
contracts, and manifest/theme schemas. It intentionally leaves timing budgets,
QML runtime loading, D-Bus fixtures and nested compositor tests to explicit runs.

Before committing behavior changes:

- Run the relevant feature runner under `packages/stillsuit-shell/src/tests`, such
  as `audio-media/run-fixtures.sh`, `connectivity/run.sh`, or `launcher/run.sh`.
- For shared core or plugin lifecycle changes, also run
  `src/tests/run-lane-b-fixtures.sh` and the affected feature runners.
- For shared UI or bar changes, also run `src/tests/ui/run-fixtures.sh` and the
  affected bar fixtures, such as `src/tests/bar-v2/run.sh`.
- Run performance tests explicitly when changing launcher search or other
  performance-sensitive behavior. Use `STILLSUIT_LAUNCHER_REQUIRE_QML=1` for the
  launcher runner so missing Quickshell fails instead of silently skipping QML.

All paths above are relative to `packages/stillsuit-shell`. For example:

```sh
direnv exec "$PWD" bash packages/stillsuit-shell/src/tests/audio-media/run-fixtures.sh
```

Runtime runners can need a display, private D-Bus, or nested Sway; some fetch tools
when missing. Run them explicitly in a suitable environment. Report the commands,
results, and any skipped checks. Source checks, runtime fixtures and verification
of the running desktop are separate evidence.

Host configuration evaluation and builds are also explicit. A root
`nix flake check`, even with `--no-build`, can evaluate Sietch. Follow the host
restriction in `AGENTS.md` and validate Sietch on Sietch.
