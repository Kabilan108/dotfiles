# Home modules notes

## fleet.nix

- Keep `IdentitiesOnly` on the human host aliases. Without it ssh also offers every key the desktop ssh-agent holds, including the passwordless agent key for the host, which bypasses the hardware-key requirement for human logins.
- Keep the agent aliases on their own `ControlPath` (cm-agent-…), separate from the login connection's (cm-…). On a shared socket, agent-key commands would ride a hardware-key login. Sharing one agent connection costs nothing: anything that can use the socket can already read the key.
- Treat the JSON in `fleetJson` as a contract for scripts: add fields freely, bump `version` on a breaking change, and never add keys to it.
- Keep the ssh client config a real user-owned file (mode 400) copied from the generated source file, not a store symlink. Agent harness shells see the Nix store through an id-mapped mount where files stat as nobody, and ssh rejects such a config with "Bad owner or permissions".
- Keep the combined Bitbucket alias with `HostName` ssh.bitbucket.org and `AddressFamily` inet. The alias keeps existing SSH URLs working after the November 2026 Bitbucket hostname migration, and IPv6 connections to Bitbucket time out on this network.

## CPA clients (`cpa-clients.nix`)

- Call `~/.local/bin/claude` and `~/.local/bin/codex` by absolute path in the `claude-cpa` and `codex-cpa` wrappers, so a wrapper can never resolve back to itself through PATH.
- Keep `-c 'model_provider="cpa"'` before the user's arguments in `codex-cpa`. At the root it applies to every subcommand, including the `app-server` and `exec` modes that T3 and scripts use. `agents/codex/config.toml` defines `[model_providers.cpa]` but does not make it the default, so plain `codex` keeps using OpenAI auth.
- Keep `codex-cpa` passing its filtered copy of CPA's catalog through `model_catalog_json`, not `model_catalog_url` in `agents/codex/config.toml`. With API-key auth and no catalog, Codex uses its bundled list, which lacks Ultrafast on GPT-6.2 Sol. CPA's full catalog also lists Claude models, and T3's `delegate_task` accepts any model in a provider's catalog, even models hidden in T3. The `gpt-*` filter only hides models: CPA client keys can call every model.

## browse (`opencode-browse.nix`)

- Keep `OPENCODE_BROWSER_AUTO_UPDATE=off` forced in the wrapper. browse otherwise downloads and installs releases hourly, unpinned; its updates come through `update-app-pins` instead.
- Keep the relay port pinned on every host. `browse-relay-tunnel` forwards one fixed port, and an unpinned relay moves to 19990-19997 when 19988 is busy, which would leave a forwarded host on a dead port.

## Other modules

- Give gh to user services through `config.dotfiles.gh.package` (`gh.nix`), not `pkgs.gh`. Plain gh reads its token from GNOME Keyring, and while the keyring is locked a timer-started gh hangs on the keyring prompt; the wrapper exports `GH_TOKEN` from the agenix file instead.
- Write tpm plugin lines to the generated plugins file that the tmux config sources, as `shell-base.nix` does. tpm reads `@plugin` lines only from the main tmux config and the files it sources.
- Keep `UnsetEnvironment` in the resident Ghostty unit in `ghostty.nix`. Every Ghostty window is a child of that one process, and AppImages such as T3 Code export their bundled library path (`LD_LIBRARY_PATH`, `APPDIR`, `APPIMAGE`, `GSETTINGS_SCHEMA_DIR`), which would otherwise leak into every shell.
- Keep Ghostty's `async-backend = "epoll"`. The io_uring backend's event waits inflate Linux I/O-pressure readings while the terminal is idle.
- Pass any GTK theme package through `extractGtkGresources` in `gtk.nix`. Libadwaita apps refuse named GTK themes, so the theme's gresource is never registered and the CSS import chain Home Manager generates fails silently; extracting each gtk-4.0 gresource to plain files makes the file imports work.
- Keep both dark-mode settings in `gtk.nix`. libadwaita reads dark mode from the portal `color-scheme` setting, while `gtk-application-prefer-dark-theme` only works for GTK 3 and non-libadwaita GTK 4.
- Do not add `d` or `r` bookmarks in `scout.nix`. Bookmarks are `g` plus a key, and scout's built-in `gd` already follows the XDG downloads folder and `gr` opens `~/repos`.
