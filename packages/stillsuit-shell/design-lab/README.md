# Stillsuit design lab

This is a development-only Quickshell surface for settling Stillsuit's visual
system before the production panels adopt it. It runs as a separate Quickshell
process, uses mock data, and has no notification, compositor, or service
authority.

The lab compares three draft themes and lets you tune:

- body, telemetry, and icon fonts;
- 26, 28, 30, and 32 px bar heights;
- anchored and floating bar treatments, with inline workspaces fixed;
- surface opacity, radius, core semantic colors, and a separate OSD color;
- motion speed and reduced-motion behavior.

The default review preset reproduces the accepted screenshot baseline:
Catppuccin Mocha, Noto Sans, JetBrainsMono Nerd Font, rounded Material Symbols,
a 26 px anchored bar, 0.85 opacity, 4 px medium radius, and 0.55 motion scale.
Use `Your pick` to restore it after comparing theme defaults.

The composition preview includes six notification states and five network
states. The network header's borderless `Scan` action switches to the scanning
state. OSDs have a dedicated component background and always use the selected
medium radius; `surface.raised` remains the role for controls and panel
sections.

The previews import the shared components in `../src/ui/`; they are not copies
of production-looking controls. Candidate files live in `themes/` and validate
against `../schemas/theme.v2.draft.json`.

After the declarative fonts have been activated, launch the lab from the
repository root with:

```bash
STILLSUIT_LAB_ROOT="$PWD/packages/stillsuit-shell/design-lab" \
  quickshell --no-duplicate \
  --path "$PWD/packages/stillsuit-shell/src/design-lab.qml"
```

The current production theme schema remains v1. The v2 schema is explicitly a
draft until the lab is approved; `DESIGN.md` and the production panels should
not be migrated before then.
