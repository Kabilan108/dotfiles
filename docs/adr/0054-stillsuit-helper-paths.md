# Stillsuit helpers run on an exact, declared PATH and get absolute tool paths

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The Stillsuit shell runs as a systemd user unit, and it and each Nix-wrapped helper replace `PATH` with the bin directories of their declared runtime inputs. Nothing from the session leaks in. Session actions run against that exact PATH, so a bare command name such as `lock-screen` does not resolve. `gio open` launches a handler's Exec line, which can be a bare name such as `helium`, and that also fails to resolve under the unit's PATH.

Some tools have dependencies their names do not reveal: `wl-copy` and `wl-paste` exec `cat` to move clipboard data, and omarecord saves and restores the clipboard through them. The agent-usage probe must run the same `agy` and `codex` that `update-agents` installs and that the user runs interactively, not separate nixpkgs copies. Both hosts run niri-unstable rather than the nixpkgs niri, and `niri msg` must speak the running compositor's IPC version. Python adds the script's directory to `sys.path`; for a store script that directory is the store root, and scanning it costs tens of milliseconds on every clipboard change.

## Decision

- The shell's runtime inputs (the default `package` in `options.nix` and `exactRuntimeInputs` in `service.nix`) always add `coreutils` and `wl-clipboard`. The clipboard collector and the recorder wrapper add `coreutils` too.
- The `niri` binding uses `lib.getExe osConfig.programs.niri.package`, so `niri msg` comes from the same build as the compositor.
- The lock action uses the store path of the `lock-screen` package that `swaylock.nix` adds to `home.packages`. Configs without it keep the module's loginctl default.
- `stillsuit-open` appends `/etc/profiles/per-user/<user>/bin` and `/run/current-system/sw/bin` to PATH before calling `gio open`.
- The agent-usage helper builds a `stillsuit-user-agents` directory holding symlinks to the configured `agyBin` and `codexBin`, and exposes only those two.
- The clipboard collector runs `python3 -P`, which keeps the store root off `sys.path`.
- `bin/stillsuit-app-launch` keeps its `#!/usr/bin/env bash` line so its test can run the source directly; `app-launch-helper.nix` strips that line before `writeShellApplication` adds its own.

## Consequences

Any new tool that shells out to an undeclared program fails at runtime, not at build time; check transitive execs when adding a runtime input. New helpers and session actions must pass store paths or extend PATH themselves. The runtime input list is assembled the same way in `options.nix` and `service.nix`, so both must change together. Swapping the niri package for nixpkgs' release would let `niri msg` drift from the compositor's IPC. The agent-usage probe breaks if `update-agents` stops installing to the configured paths.

## Where

- `home/desktop/wayland/quickshell/default.nix` (`niri`, `lockScreen`, `openHelper`)
- `modules/home/stillsuit/options.nix` (`package` default `runtimeInputs`)
- `modules/home/stillsuit/service.nix` (`exactRuntimeInputs`)
- `packages/stillsuit-shell/clipboard-collector.nix` (`runtimeInputs`, `python3 -P`)
- `packages/stillsuit-shell/recorder-helper.nix` (`runtimeInputs`)
- `packages/stillsuit-shell/agent-usage-helper.nix` (`userAgents`)
- `packages/stillsuit-shell/app-launch-helper.nix` (`text`)
