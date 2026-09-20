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
`stillsuit.dictation` owns the Dictator quick controls: its bar widget opens a
panel with the record button, a live level meter fed by the shared Dictator
OSD projection in `stillsuit.workflows`, recent transcripts with copy, and a
launcher for the full `dictator-gui` app. It shells out to the configured
`dictatorCliPath` (`toggle`, `cancel`, `transcripts -n N`) and never parses
the daemon IPC socket itself. The fixture is `src/tests/d6-dictation/run.sh`.

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
stillsuit-plugins set stillsuit.notifications notifications.avoidOutputs '["DP-4"]'
stillsuit-plugins unset stillsuit.notifications notifications.avoidOutputs
```

`set` and `unset` edit one dotted key under a plugin's runtime `settings`
override; the value is JSON. The change re-constructs that plugin's service
within about a second, which for notifications preserves history through the
persisted state file.

## Plugin profiles

Profiles are named deltas over the normal plugin configuration. They do not
select source directories and do not change root precedence. The helper still
discovers every configured root as one trusted plugin inventory.

The effective configuration order is:

```text
Nix seed defaults
-> global plugins.json override
-> active named profile override
```

The implicit `default` profile stops after the global override. It always
exists, even when no profile files exist. Existing `enable`, `disable`,
`place`, `set`, and `unset` commands continue to change the global base.
Named profiles usually add work or project-specific plugins, but a profile may
also disable or move an ordinary base plugin. Exactly one profile is active;
profiles neither inherit from nor combine with other named profiles.

Profile definitions follow `schemas/profiles.v1.json` and default to
`~/.config/stillsuit/profiles.json`:

```json
{
  "schemaVersion": 1,
  "profiles": {
    "work": {
      "name": "Work",
      "description": "Moberg development tools",
      "plugins": {
        "stillsuit.worktrees": {
          "enabled": true,
          "section": "left",
          "order": 30
        },
        "stillsuit.t3": {
          "enabled": true,
          "settings": {
            "projectFilter": ["moberg"]
          }
        }
      }
    }
  }
}
```

Each plugin delta may contain `enabled`, `section`, `order`, and `settings`.
Omitted fields inherit the base. Settings merge one top-level key at a time,
so a profile value for an object or array replaces that whole base value.
Arrays never concatenate.

Profile IDs match `[a-z][a-z0-9-]*`. `default` is reserved and cannot be
created, deleted, or changed as a named profile. The selected profile is kept
separately in `~/.local/state/stillsuit/active-profile.json`:

```json
{
  "schemaVersion": 1,
  "active": "work",
  "revision": 4
}
```

Use the CLI to create and change profiles programmatically:

```sh
stillsuit-plugins profile list
stillsuit-plugins profile current
stillsuit-plugins profile create work --name Work --description 'Moberg development tools'
stillsuit-plugins profile enable work stillsuit.worktrees
stillsuit-plugins profile disable work stillsuit.personal-example
stillsuit-plugins profile place work stillsuit.worktrees left 30
stillsuit-plugins profile set work stillsuit.t3 projectFilter '["moberg"]'
stillsuit-plugins profile unset work stillsuit.t3 projectFilter
stillsuit-plugins profile activate work
stillsuit-plugins profile delete work
```

`list`, `current`, and `activate` print JSON. The other mutation commands are
silent on success. Deleting the active profile is rejected. An unknown profile
or invalid document leaves the active state unchanged.

Home Manager supplies a protected plugin list in `runtime-discovery.json`.
It includes the selected bar and notification owner in this configuration.
Neither global preferences nor profiles may disable those plugins. Protection
keeps shell authority available while profiles suppress ordinary plugins. A
disabled plugin remains discoverable but the host destroys its service,
widgets, and surfaces.
Consumers of a disabled service do not register until that dependency is
enabled again.

`Mod+Alt+P` opens an Elephant picker that lists and activates profiles; it does
not edit them and does not occupy the bar. The picker queries the shell each
time it opens, so newly created profiles appear without a rebuild. A switch
reports `switching` until the watcher publishes the new catalog and the host
has reconciled it. Changed and disabled services, surfaces, and widgets leave
their host registries as one catalog reconciliation before eligible
replacements load. A profile revision change also clears session-only disables
created by the `stillsuit-plugin unload` IPC action. Once settled, a contained
catalog, visual, service, or surface contribution marks the profile `degraded`
and keeps the rest of the profile active.

The `stillsuit-profile` IPC target exposes only `list`, `current`, and
`activate`. Shell status includes the active and requested profile, profile
revision, available profiles, switch state, and error. If a helper call fails
or the new catalog does not arrive within ten seconds, status reports `error`.
The `error` field carries the first diagnostic for both `degraded` and `error`
states. The last catalog keeps running when the watcher cannot parse profile
state.

Profiles do not namespace plugin data or state paths. Two profiles using the
same plugin share its persisted state unless their settings explicitly select
different files.

Profile readiness covers the shell's QML registries and pending component
loads. It does not wait for detached processes, grandchildren, user services,
or work already started on a remote machine. Profile-owned services should keep
long-running work as direct, killable child processes and handle termination
without leaving detached work behind.

The first deployment of profile support needs a Home Manager rebuild because
the host API, picker key binding, helper environment, persistence paths, and
protected plugin list are Nix-owned. Creating, editing, or activating profiles
after that deployment is hot and does not need a rebuild or shell restart.
Changing `programs.stillsuitShell.profiles` options still needs another rebuild.

The `stillsuit-plugin` agent skill (`.agents/skills/stillsuit-plugin/`) walks
this loop and points at `src/plugins/examples/` as starting templates.
Develop against `stillsuit-workbench` first: it runs the same core and
discovery on a nested compositor with fixture-driven services, so a plugin can
be created, edited, broken, and restored without touching the live session.
See `../design-lab/README.md`.

Promote an experiment by moving its whole directory into the tracked root,
keeping its manifest ID, then reviewing and committing its source. Do not leave
two divergent copies. This is a manual source operation, not a profile change.
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
