# Home configuration notes

- Keep `NIX_SSHOPTS` at RequestTTY=no in `shell.nix`. Fleet host aliases request a TTY for tmux-on-ssh, a TTY merges remote stderr into stdout, and nixos-rebuild with a build host then parsed build progress as the result path. Only Nix reads this variable.
- Keep nix-direnv pinned to 3.1.2 from source in `shell.nix`. Version 3.2.0 makes cached shells invalidate each other through profile timestamps. Drop the pin once a release includes https://github.com/nix-community/nix-direnv/pull/790.
- In `services/solaar.nix`, the MX Master 2S thumb button's firmware fallback must stay on a button without gesture navigation. With gesture navigation as the fallback, a sticking switch suppressed pointer movement.

## shell.nix

- Keep `SSL_CERT_FILE`, `REQUESTS_CA_BUNDLE` and `PIP_CERT` pointed at the NixOS CA bundle in both the session and systemd user environments. certifi and pip ship their own roots and would miss trust-store fixes, which otherwise arrive on rebuild.
- Keep `DENO_TLS_CA_STORE = "system"`. Deno ignores `SSL_CERT_FILE` and falls back to its bundled roots.
- Keep `HF_TOKEN_PATH` outside `HF_HOME`. `HF_HOME` is a model cache shared with services such as siren, and login credentials (token, stored_tokens) must not sit in it.
- Leave Atuin's `teams.enabled = false`. Atuin for Teams uploads a server-readable copy of all shell history and every agent thread, beside the end-to-end encrypted sync.
- Keep `pkgs.inotify-tools` in `programs.neovim.extraPackages`. Neovim's LSP workspace file watching on Linux uses an inotifywait backend, and markdown-oxide depends on it (see `config/nvim/lua/config/lsp.lua`).
- Keep `moveGrokHome` before `checkLinkTargets` in `shell.nix`. A host's existing `~/.grok` holds its Grok sign-in and sessions; the step copies them into `agents/grok` without overwriting tracked files, then clears the way for the link, which Home Manager would otherwise refuse as a collision.
- Link only the shared config directory of Antigravity into the checkout, and merge its CLI settings with `sync-antigravity-config` instead of linking them. agy rewrites its settings file atomically, which replaces a symlink with a plain file, and it writes runtime state elsewhere under the same home.
- Bridge the Antigravity agent instructions, MCP config and MCP OAuth tokens into T3 Code's Antigravity profiles from `sync-antigravity-config`. T3 Code isolates `GEMINI_HOME` per provider instance and symlinks only config and skills. The script runs at activation and only touches profiles that exist, so a new or reset T3 profile stays unbridged until the next Home Manager activation.
- Expect T3 Code to disable Antigravity as a background text-generation model for any profile with a non-empty MCP config. That is acceptable while T3's `textGenerationModelSelection` uses Codex; revisit the bridge if that selection moves to Antigravity.

## default.nix

- Keep `xdg.terminal-exec` defaulting to Ghostty. GLib launches `Terminal=true` desktop entries (the nvim entry) only through xdg-terminal-exec or a hardcoded terminal list that lacks Ghostty.
- Keep the removed Zotero association for text/plain. Zotero's desktop entry claims text/plain, and every code and markdown type inherits from it.
- List MIME types one by one in `xdg.mimeApps.defaultApplications`. XDG default applications do not support wildcards such as image/*.
- Declare an app's URL scheme handlers in `xdg.mimeApps` when adding it (see `services/grok-bot.nix`). Home Manager makes the user's mimeapps list read-only, so an app cannot register its own deep-link handlers at runtime.
