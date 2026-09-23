---
name: blender
description: Build, render, animate, and export 3D scenes with headless Blender through the `blend` CLI. Use when a task involves 3D models, scenes, renders, or .blend/.glb/.stl files.
metadata:
  fleet-hosts: sietch
---

# Blender

`blend` (on PATH; source in this skill's `scripts/`) drives headless Blender 5
with GPU rendering. Run `blend --help`, `blend <command> --help`, and `blend kit`
for flags and helpers. `blendkit.py` is short; read a helper's source when it
is close to what you need but not quite it.

Before starting, read the reference that matches the task:

- [`references/printing.md`](references/printing.md) for parts to print or fit together (STL, units, booleans, fit checks).
- [`references/lighting.md`](references/lighting.md) for photoreal shots: product, interior, anything lit or glazed.
- [`references/animation.md`](references/animation.md) for keyframes, drivers, moving cameras, and video.

## The loop

Every change goes through **build → render → look**:

1. **Build.** Write bpy code and apply it with `blend run PROJECT build.py`.
   The scene saves only when the script finishes without raising. A failed
   script prints the traceback and leaves `scene.blend` untouched, so fix the
   script and run it again.
2. **Render.** Run `blend render PROJECT`. It auto-frames `iso,front,right,top`
   around the geometry, and when there is more than one image it writes a
   labelled `sheet.png`; the paths are printed. Use `--views camera` once the
   scene has its own camera, `--target OBJ` to zoom in on a detail, `--hide GLOB`
   to take walls or clutter out of one render, and `--frame 1,17,19` for key
   frames in one launch.
3. **Look.** Open the sheet (or the single image) with your image viewer and
   check it against the requirement: proportions, placement, contact with the
   ground, materials, framing. `blend inspect` gives exact numbers for anything
   the image leaves ambiguous.

Some requirements never show up in a picture: watertightness, fit, clearance,
exact motion. Check those numerically with a `--no-save` script. The
references say how.

A step is done when a render you have looked at, plus any numeric checks the
task needs, shows the requirement met. Exit code 0 only means Blender ran.
Report the final render path(s) and the project directory.

## Projects

A project is a directory holding `scene.blend`. Put it at `~/blender/<name>`
unless the task names a location. Renders go to `PROJECT/renders/<stamp>/`,
and logs and the lock file to `PROJECT/.blend-cli/`.

Give each agent or task its own project. `blend run` on one project takes a
lock, so concurrent writers queue instead of clobbering each other. `render`,
`inspect`, and `export` only read, so they run concurrently with anything.

**Several scene states.** Every command also accepts a `.blend` path. For an
exploded view, a print layout, or an alternate camera setup, have the build
script save a copy (`bpy.ops.wm.save_as_mainfile(filepath=str(PROJECT /
"exploded.blend"), copy=True)`), then `blend render PROJECT/exploded.blend`.

## Writing scripts

Keep one **build script** that regenerates the whole scene from
`bk.clear(everything=True)`, and rerun it after each edit. The scene then stays
reproducible, and iterating means editing one file. Put tunable values behind
`ARGS.get("key", default)` and sweep them with `blend run P build.py --set
key=value`. Reserve `blend run -c` snippets for queries (`--no-save`) and
one-off tweaks.

Scripts run in a fresh Blender process each time. Python variables do not
carry over between runs; the `.blend` is the only state. Look objects up again
with `D.objects["Name"]`. The globals `C`, `D`, `bk`, `ARGS`, and `PROJECT` are
live, so give your own variables longer names.

Blender conventions that trip agents:

- Units are metres and Z is up. The `front` view looks along +Y from −Y, and
  `right` looks along −X from +X. Rotations are radians (`math.radians(90)`),
  but `inspect` reports degrees.
- There is no viewport. Operators that need a 3D View context (`bpy.ops.view3d.*`,
  many edit-mode `bpy.ops.mesh.*` tools) fail with a context error. Build geometry
  with `bpy.ops.mesh.primitive_*`, `bk.box`, `bk.extrude`, `bk.lathe`, `bk.sweep`,
  `bk.mesh`, `bmesh`, and modifiers. Bake modifiers with `bk.apply_modifiers` and cut with
  `bk.boolean`.
- Names deduplicate silently (`Cube`, `Cube.001`). Keep the object a call
  returns (`C.active_object` right after a `primitive_*_add`) and set `.name`
  yourself.
- `matrix_world` is stale on objects you just created or moved until
  `bpy.context.view_layer.update()` runs. The `bk` helpers handle this; your own
  code must too.
- Blender 5 has no auto-smooth toggle. Use `bk.smooth(obj, angle_deg=30)`.
- Objects with `hide_render` set do not render or export.

## Render settings

`render` and `animate` use the scene's engine, resolution × percentage, and
samples. A flag overrides them for that one render only. New projects start at
1920×1080 at 50% (960×540 previews), with EEVEE at 32 samples and Cycles at 128
with denoising. For the final image, set `C.scene.render.resolution_percentage = 100`
in the build script or pass `--res 1920x1080`.

- **Engines:** use `workbench` to check geometry. Use `eevee` for quick
  realistic previews. Judge glass, volumes, and emissive or transparent shaders
  (glows, halos, beams) in `cycles`, because EEVEE often renders them wrong or
  not at all.
- **Colour:** material colours are linear. Pass `'#rrggbb'` hex to
  `bk.material` or convert with `bk.hex_color`. For flat or stylized palettes,
  set `C.scene.view_settings.view_transform = "Standard"`; the default, AgX,
  desaturates them.
- **Lighting:** while the scene has no lights or HDRI, `render` adds temporary
  studio lights (never saved) so early geometry passes are readable. Final
  output needs the scene's own lighting.

## Assets

Poly Haven assets are CC0 and cached under `~/.cache/blend/polyhaven`, shared
across projects. `blend polyhaven search WORDS --type hdri|texture|model`, then
`blend polyhaven get ID`, which prints the exact `bk.*` line to paste into a
script, texture scale included. It downloads 1k by default; pass `--res 2k` or
`--res 4k` for finals.
Poly Haven has no assets for many specific objects (lamps, mugs, books). Search
once, and model what is missing.

## Output

- **Stills:** `blend render PROJECT --views camera`.
- **Video:** `blend animate PROJECT`. See `references/animation.md`.
- **Models:** `blend export PROJECT out.glb` (also gltf, obj, fbx, stl, ply,
  usd). Use `--objects` to export a subset, and `--scale 1000` for STL meant
  for a slicer.
