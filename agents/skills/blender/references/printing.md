# Printed and CAD-style parts

Read this when the output is a solid someone will print, machine, or fit to other parts.

## Units

Model in metres, which is Blender's default, and export with `blend export PROJECT part.stl --scale 1000`.
Slicers read STL numbers as millimetres. `bk.mesh_report(obj, unit="mm")` reports size in mm and volume in cm³,
so the checks read the same way as the spec.

## Building

- Draw profiles and extrude them: `bk.extrude(name, outline, depth, plane=...)`, with
  `bk.rounded_rect(...)` for rounded outlines. Use `bk.box(lo, hi)` for blocks,
  `bk.sweep(name, path, section, scale=)` for arms and hooks whose cross-section follows a curve,
  and `bk.lathe(..., angles_deg=[...])` for turned or faceted parts.
- Make each screw hole with one `bk.hole_cutter(entry, direction, d, depth, countersink_diameter=)`.
  A separate cylinder and cone whose seams line up leave open edges after the boolean.
- Cut with `bk.boolean(target, cutter)` (exact solver). Extend each cutter at least 0.1 mm past
  every face it cuts through. Coplanar faces produce slivers and non-manifold edges.
- Bevel convex edges only. An angle-limited bevel folds through itself at sharp inside corners,
  and it looks fine in a render. Set `bevel_weight_edge` on the convex edges and use
  `limit_method = "WEIGHT"`. Check `use_clamp_overlap`, because it can shrink the bevel to zero.
- Bevel modifiers on low-segment lathes or sweeps break the solid. Put chamfers into the
  profile or the `angles_deg` list instead.
- Choose the print orientation for strength first: layer lines should not cross the section
  that takes the bending load. `bk.overhangs(part)` then reports the area that needs support
  (0 means none). Export in print orientation (flat face on the bed). Keep a separate print-layout state if the
  assembly view differs; see "Several scene states" in SKILL.md.

## Evidence

A render cannot show manifoldness, clearance, or wall thickness. Put the checks in a `check.py`
that you run with `blend run PROJECT check.py --no-save`, and have it `sys.exit(1)` when a check fails:

- `bk.mesh_report(part, unit="mm")["watertight"]` for every part.
- Dimensions against the spec from `size_mm`, or from vertex coordinates for features.
- Fit and interference with `bk.overlap_volume(a, b)`. 0 means clear. For a snap fit, move the
  part to its engaged position and confirm the overlap is the interference you designed.
- Clearance and wall thickness by ray-casting (`obj.ray_cast` or `mathutils.bvhtree.BVHTree`)
  from face centres along their inward normals.
