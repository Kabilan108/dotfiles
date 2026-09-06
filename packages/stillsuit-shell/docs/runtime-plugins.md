# Runtime plugins

The core, bar frame, shared UI, services, and compiled theme stay in the Nix
store by default. `development.sourceMode = "local"` intentionally switches
the core checkout; it is independent of the plugin roots.

`programs.stillsuitShell.pluginRoots` lists trusted writable roots in priority
order. Jacurutu uses the tracked `src/plugins/builtin` directory first, then
`~/.config/stillsuit/plugins`. The name `builtin` is historical, not a mutation
restriction. Each immediate child directory contains a manifest and its QML.
The selected bar frame remains reserved to the store. The retired meeting
plugin has an explicit disabled seed default; recording owns the current UI.

The watcher checks manifests against the schema, rejects symlinks and escaping
entry points, and snapshots changed plugin trees into content-addressed state
directories. Stable URLs therefore never serve stale QML after an edit. The
first root claiming an ID wins, including when that copy fails validation.
Malformed JSON that cannot identify its plugin cannot claim an ID. A broken
plugin is omitted/contained rather than crashing the core; its last working
version is not promised to remain visible. Fixing its source rediscovers it.
Trusted QML runs in-process: this is validation, not a security sandbox.

After an approved deployment, normal edits are discovered within about one
second; no rebuild or shell restart is needed. Nix defaults provide executable
paths and settings. Runtime preferences override settings, enablement, and bar
placement in `~/.config/stillsuit/plugins.json`:

```sh
stillsuit-plugins list
stillsuit-plugins validate
stillsuit-plugins disable stillsuit.example
stillsuit-plugins enable stillsuit.example
stillsuit-plugins place stillsuit.example right 50
```

Promote an experiment by moving its whole directory into the tracked root,
keeping its manifest ID, then reviewing and committing its source. Do not leave
two divergent copies. This is a manual source operation, not a runtime deploy.
Immutable generations are retained for now; garbage collection is future work.

New plugins import `Stillsuit.Ui`. Public component names and properties are
documented in `../src/ui/README.md`. Existing relative imports are supported by
the generation layout; new plugins should not copy that internal layout.
Python helpers remain Nix-wrapped so dependencies and executable paths are
explicit. Changing core services, helper packages, or Nix settings still needs
a rebuild, with activation separately approved.

The discovery seed preserves explicitly disabled Nix entries independently of
the enabled-only store catalog. Runtime scanning must not infer that a disabled
tracked plugin is a new plugin to enable. The watcher refreshes automatically
about once a second. Runtime IPC `rescan` returns `watching`, not `ok`: it does
not force an immediate scan. In store-catalog mode, rescan still rereads the
catalog synchronously.
