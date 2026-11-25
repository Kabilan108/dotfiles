# Home services notes

- Do not install T3 Code's upstream service; `t3-update` in `t3-code.nix` runs only the binary's updater. Home Manager owns the t3-code user unit, and a second unit would fight it for port 3773.
- Keep the restart check in `t3-update` comparing the running executable with the installed symlink, not the updater's output. An earlier update can download a release without restarting the service, and only the comparison catches that.
- Keep the `cmdline-tools/latest` symlink that `androidSdkPackage` adds. T3 Code's Android tooling expects the Android Studio SDK layout, while Nix installs the command-line tools under a version directory.
- viewh5 in `install-tools.nix` follows Git HEAD with no release-age hold because it is Tony's own package. Give any third-party tool added there the same hold the package managers enforce (`config/mise/config.toml`, `config/pnpm/config.yaml`, `config/uv/uv.toml`).
- Keep `update-agents.service` in `update-agents.nix` out of `default.target`. Its timer's `OnBootSec` and `Persistent` already trigger runs, and `WantedBy = [ "default.target" ]` makes `switch-to-configuration` block on network retries before system units restart.
