# Animation

Read this before keyframing, rigging motion, or rendering video.

## Keys and curves

- Blender 5 actions are layered, and `action.fcurves` no longer exists. Keyframe with
  `bk.key(obj, "location", {1: 0, 12: 2}, index=2, easing="EASE_OUT")` and reach the curves
  (handles, extrapolation, modifiers) through `bk.fcurves(obj)`.
- Keys are exact only on the frames you key; motion blur and subframes see the interpolation.
  For motion that must satisfy a constraint at every instant (linkages, gears, followers), use
  drivers. Simple-expression drivers (`sin`, `cos`, `sqrt`, `asin`, arithmetic on driver
  variables) evaluate headless with no script auto-run:

  ```python
  fc = obj.driver_add("location", 0)
  fc.driver.expression = "r*cos(a) + sqrt(l*l - (r*sin(a))**2)"
  var = fc.driver.variables.new(); var.name = "a"; var.type = "TRANSFORMS"
  var.targets[0].id = crank; var.targets[0].transform_type = "ROT_Y"; var.targets[0].transform_space = "WORLD_SPACE"
  ```

- Turntables: `bk.turntable(obj, 1, 96)` spins at constant speed and loops seamlessly over
  frames 1–96. Parent the product to an empty and spin the empty if the product has its own
  rotation. Save a static copy of the scene first (see "Several scene states"), because
  auto-framed views and `mesh_report` measure the rotated pose.
- Moving cameras: `bk.camera(..., target=empty, track=True)` keeps aiming at the empty while the
  camera moves, so you only animate the camera's location.
- Seamless loops: render frames `1..N` and key the loop's end state at `N+1`, then check that
  the render at `N+1` matches frame 1.

## Checking motion

- Look at key frames in one launch: `blend render PROJECT --views camera --frame 1,12,24,36`.
- Verify motion numerically, with the same care as geometry. In a `--no-save` script, step
  `C.scene.frame_set(f)` (fractional frames via `frame_set(f, subframe=0.25)`) and read
  `obj.matrix_world` to measure what Blender actually evaluates.
- `blend animate` writes the mp4 only after the whole range renders. A 100-frame EEVEE 720p
  clip takes about a minute; Cycles takes seconds per frame. For progress, `tail` the newest
  `PROJECT/.blend-cli/logs/*-animate.log`, which logs every frame. To check the result,
  extract frames with `nix-shell -p ffmpeg --run "ffmpeg -i in.mp4 -vf select='eq(n\,47)' -vframes 1 f47.png"`.
