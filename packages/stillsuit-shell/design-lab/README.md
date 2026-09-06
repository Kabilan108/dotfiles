# Stillsuit design lab and plugin workbench

Two development-only surfaces share this directory. Neither has notification,
compositor, or service authority over the real session.

## Plugin workbench

`stillsuit-workbench` runs the production core (plugin catalog, service
registry, surface router, panel hosts, IPC facade) a second time on one
output of the current session, inside an isolated XDG sandbox. Its bar runs
in shadow mode (no exclusive zone) and sits one bar height below the
production bar, with its panels and toasts offset to match; by default it
picks the output you are not focused on, so the real shell stays usable on
the other one, and it steers the live shell's notification banners to the
other output for as long as it runs (a `notifications.avoidOutputs` runtime
preference, cleared on stop). With a single output the two bars stack on it. Real plugin
QML runs unchanged; only the inputs are synthetic:

- services receive fixture `model` objects instead of hardware and helpers;
- the compositor snapshot comes from the fixture, not Niri;
- notifications are injected through the real notification service without
  claiming the D-Bus name;
- the recorder and meeting-worker state files are written from the fixture.

```sh
stillsuit-workbench                              # start; picks the output you are not focused on
stillsuit-workbench --output eDP-1 --fixture battery-low
```

In another terminal, while it runs:

```sh
stillsuit-workbench status                       # output, fixture, open panel, plugin errors
stillsuit-workbench fixtures                     # scenario ids from fixtures/*.json
stillsuit-workbench fixture media-playing        # switch scenario
stillsuit-workbench open audio                   # open a panel on the workbench's output
stillsuit-workbench close
stillsuit-workbench notify "Summary" "Body"
stillsuit-workbench actions                      # service calls plugins made
stillsuit-workbench stop
```

Plugins under `~/.config/stillsuit/workbench/plugins/<name>/` take precedence
over the tracked builtins and are discovered, reloaded, contained, and
restored within about a second, exactly as in production. The workbench also
loads `src/plugins/examples/` (the `stillsuit-plugin` skill's templates) and
`src/workbench/plugins/` (review tools such as the icon gallery); neither is
in the production registry. Every IPC target the
production shell exposes (`stillsuit`, `stillsuit-surface`, `stillsuit-plugin`)
works against the workbench through `stillsuit-workbench call TARGET FN ...`,
the raw escape hatch behind the commands above.

Fixtures live in `fixtures/*.json` (`schemaVersion: 1`). Each one carries the
compositor snapshot, per-service model documents keyed by plugin id,
notifications to present, and recorder/meeting state. Add a scenario by adding
a file; `reloadFixtures` picks it up without a restart. The service model
shapes are the same ones the fixture suites under `src/tests/` use.

`src/tests/workbench/run.sh` boots the workbench with `--headless`, which
owns a headless sway instead of the session, and asserts the acceptance
target: every fixture switches with no service errors, and a plugin
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
