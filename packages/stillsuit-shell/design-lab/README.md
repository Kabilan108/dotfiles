# Stillsuit design lab and plugin workbench

Two development-only surfaces share this directory. Neither has notification,
compositor, or service authority over the real session.

## Plugin workbench

`stillsuit-workbench` runs the production core (plugin catalog, service
registry, surface router, panel hosts, IPC facade) on a nested compositor
inside an isolated XDG sandbox. Real plugin QML runs unchanged; only the
inputs are synthetic:

- services receive fixture `model` objects instead of hardware and helpers;
- the compositor snapshot comes from the fixture, not Niri;
- notifications are injected through the real notification service without
  claiming the D-Bus name;
- the recorder and meeting-worker state files are written from the fixture.

```sh
stillsuit-workbench run                       # visible nested window, default fixture
stillsuit-workbench --fixture battery-low run
stillsuit-workbench fixtures                  # ids from fixtures/*.json
stillsuit-workbench call stillsuit-workbench select media-playing
stillsuit-workbench call stillsuit-surface open stillsuit.audio '{}'
stillsuit-workbench call stillsuit-workbench notify "Summary" "Body"
stillsuit-workbench call stillsuit-workbench actions   # service calls made by plugins
stillsuit-workbench status
```

Plugins under `~/.config/stillsuit/workbench/plugins/<name>/` take precedence
over the tracked builtins and are discovered, reloaded, contained, and
restored within about a second, exactly as in production. Every IPC target the
production shell exposes (`stillsuit`, `stillsuit-surface`, `stillsuit-plugin`)
works against the workbench through `stillsuit-workbench call`. The
`stillsuit-workbench` target adds fixture selection and the recorded action log.

Fixtures live in `fixtures/*.json` (`schemaVersion: 1`). Each one carries the
compositor snapshot, per-service model documents keyed by plugin id,
notifications to present, and recorder/meeting state. Add a scenario by adding
a file; `reloadFixtures` picks it up without a restart. The service model
shapes are the same ones the fixture suites under `src/tests/` use.

`src/tests/workbench/run.sh` boots the workbench headless and asserts the
acceptance target: every fixture switches with no service errors, and a plugin
can be created, edited, broken, and restored without a restart while the bar
keeps running.

## Design lab

`src/design-lab.qml` is the earlier theme playground. It compares the three
draft themes in `themes/` and lets you tune fonts, bar height, anchoring,
opacity, radius, semantic colors, and motion against mock previews built from
the shared `src/ui/` components. The approved preset reproduces the accepted
baseline; use `Approved` to restore it.

```sh
STILLSUIT_LAB_ROOT="$PWD/packages/stillsuit-shell/design-lab" \
  quickshell --no-duplicate \
  --path "$PWD/packages/stillsuit-shell/src/design-lab.qml"
```

Candidate themes validate against `../schemas/theme.v2.json`. Design decisions
are recorded in `DESIGN.md`; deploying them remains a separate human gate.
