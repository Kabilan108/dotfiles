# Stillsuit desktop wiring notes

- Take `niri` from `osConfig.programs.niri.package`, not `pkgs.niri`. Both hosts run niri-unstable, and `niri msg` must speak the running compositor's IPC version.
- Keep the PATH line in `stillsuit-open` that appends the per-user profile bin directory and the current-system bin directory. `gio open` runs the handler's Exec line, which can be a bare name such as `helium`, and that does not resolve on the shell unit's exact PATH.
