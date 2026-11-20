# Stillsuit shell packaging notes

- Give every helper that calls `wl-copy` or `wl-paste` `coreutils` as a runtime input (`clipboard-collector.nix`, and `recorder-helper.nix` because omarecord saves and restores the clipboard). Both tools exec `cat`, and a wrapped helper's PATH holds only its declared inputs. Check transitive execs when adding an input.
- Run the clipboard collector with `python3 -P` in `clipboard-collector.nix`. Without it Python puts the script's directory on `sys.path`; for a store script that is the store root, and scanning it costs tens of milliseconds on every clipboard change.
- Build the agent-usage helper's PATH from `agyBin` and `codexBin` only (`userAgents` in `agent-usage-helper.nix`), not from nixpkgs copies. The probe must run the same `agy` and `codex` that `update-agents` installs and the user runs interactively; it breaks if `update-agents` stops installing to those paths.
