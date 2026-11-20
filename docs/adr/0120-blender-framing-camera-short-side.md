# The framing camera fits the subject to the image's shorter side

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

With `sensor_fit = "AUTO"`, Blender spans the sensor width across the wider image side. A subject framed by that angle alone gets clipped on the narrower side.

## Decision

`framing_camera` computes `long_over_short` from the aspect ratio. For an orthographic camera it scales `ortho_scale` by it. For a perspective camera it derives the half angle of the short side from the 50 mm lens and sensor width, and sets the distance so the bounding sphere fits that angle with a 5% margin.

## Consequences

Wide and tall renders both keep the whole subject in frame. Changing `sensor_fit` away from `AUTO` invalidates the calculation.

## Where

- `agents/skills/blender/scripts/blend_runtime.py` (`framing_camera`)
