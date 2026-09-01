# Stillsuit design lab

This is a development-only Quickshell surface for settling Stillsuit's visual
system before the production panels adopt it. It runs as a separate Quickshell
process, uses mock data, and has no notification, compositor, or service
authority.

The lab compares three draft themes and lets you tune:

- body, telemetry, and icon fonts;
- 26, 28, 30, and 32 px bar heights;
- anchored and floating bar treatments, with inline workspaces fixed;
- surface opacity, radius, and core semantic colors;
- motion speed and reduced-motion behavior.

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
