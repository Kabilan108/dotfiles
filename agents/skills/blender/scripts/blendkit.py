"""Helpers preloaded as `bk` in `blend run` scripts.

These cover the node-graph and context plumbing that is easy to get wrong in
raw bpy. Everything here is plain bpy; read the source when a helper is close
but not quite what the scene needs.
"""

from __future__ import annotations

from pathlib import Path

import bpy
from mathutils import Vector

GEOMETRY_TYPES = {"MESH", "CURVE", "SURFACE", "META", "FONT", "CURVES", "POINTCLOUD", "VOLUME"}


def clear(everything: bool = False) -> None:
    """Delete every object; everything=True also removes collections, worlds, actions, and all unused data (a clean slate for build scripts)."""
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    if not everything:
        return
    scene = bpy.context.scene
    for coll in list(scene.collection.children):
        scene.collection.children.unlink(coll)
    scene.world = None
    for _ in range(3):
        for datablocks in (
            bpy.data.collections, bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.lights,
            bpy.data.cameras, bpy.data.images, bpy.data.worlds, bpy.data.node_groups, bpy.data.textures,
            bpy.data.actions,
        ):
            for block in list(datablocks):
                if block.users == 0 or (datablocks is bpy.data.actions and not block.use_fake_user):
                    datablocks.remove(block)
    scene.world = bpy.data.worlds.new("World")


def framing_objects(objects=None) -> list:
    """Renderable geometry worth framing for auto views and inspect bounds.

    Flat planes (ground, backdrops) are skipped unless nothing else exists, and so is any
    object with obj["blend_frame"] = False (curved cycloramas, skies, distant scenery).
    """
    candidates = [
        o for o in (objects if objects is not None else bpy.context.scene.objects)
        if o.type in GEOMETRY_TYPES and not o.hide_render and o.get("blend_frame", True)
    ]
    solid = [o for o in candidates if min(o.dimensions) > 1e-4 * max(max(o.dimensions), 1e-9)]
    return solid or candidates


def world_bbox(objects) -> tuple[Vector, Vector]:
    """Axis-aligned world-space bounds (min, max) of objects, with modifiers applied."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    lo = Vector((float("inf"),) * 3)
    hi = Vector((float("-inf"),) * 3)
    for obj in objects:
        evaluated = obj.evaluated_get(depsgraph)
        for corner in evaluated.bound_box:
            world = evaluated.matrix_world @ Vector(corner)
            lo = Vector(map(min, lo, world))
            hi = Vector(map(max, hi, world))
    return lo, hi


def look_at(obj, target) -> None:
    """Rotate a camera or light so its -Z axis points at target (object or point)."""
    bpy.context.view_layer.update()
    point = target.matrix_world.translation if hasattr(target, "matrix_world") else Vector(target)
    direction = point - obj.matrix_world.translation
    obj.rotation_mode = "XYZ"
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def camera(location, target=(0, 0, 0), lens: float = 50, name: str = "Camera", active: bool = True,
           ortho_scale: float | None = None, fstop: float | None = None, track: bool = False):
    """Add a camera at location aimed at target; the scene camera by default.

    ortho_scale makes it orthographic (width of view in metres). fstop enables depth of
    field focused on target (e.g. 2.8 for a shallow product shot). track=True adds a Track To
    constraint (target must be an object) so the camera keeps aiming while it or the target moves.
    """
    data = bpy.data.cameras.new(name)
    data.lens = lens
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location
    look_at(obj, target)
    aim = target.matrix_world.translation if hasattr(target, "matrix_world") else Vector(target)
    data.clip_start = min(0.1, max((aim - obj.matrix_world.translation).length * 0.01, 1e-5))
    if ortho_scale is not None:
        data.type = "ORTHO"
        data.ortho_scale = ortho_scale
    if fstop is not None:
        point = target.matrix_world.translation if hasattr(target, "matrix_world") else Vector(target)
        data.dof.use_dof = True
        data.dof.aperture_fstop = fstop
        data.dof.focus_distance = (point - obj.matrix_world.translation).length
    if track:
        if not hasattr(target, "matrix_world"):
            raise ValueError("track=True needs an object target (use an empty for a point)")
        constraint = obj.constraints.new("TRACK_TO")
        constraint.target = target
        constraint.track_axis = "TRACK_NEGATIVE_Z"
        constraint.up_axis = "UP_Y"
        if fstop is not None:
            data.dof.focus_object = target
    if active:
        bpy.context.scene.camera = obj
    return obj


def light(kind: str = "AREA", location=(4, -4, 6), target=(0, 0, 0), energy: float = 1000, color=(1, 1, 1), size: float = 2, name: str | None = None, temperature: float | None = None, size_y: float | None = None, visible_camera: bool = True):
    """Add a light aimed at target. kind: POINT, SUN, SPOT, AREA.

    Sun energy is W/m² (1-10 typical). Other lights are watts and fall off with distance²:
    ~1000 W suits a room-sized scene 3-5 m away, single-digit watts a 10 cm object 0.4 m away.
    size is the softness: area size / point-spot radius in metres, sun angle in degrees.
    temperature (kelvin, e.g. 2700 warm bulb, 6500 daylight) replaces color.
    size_y makes an AREA light a rectangle (strip lights: size=0.05, size_y=1).
    visible_camera=False hides the emitter itself from the camera while it still lights and reflects.
    """
    import math

    data = bpy.data.lights.new(name or kind.title(), kind)
    data.energy = energy
    data.color = color
    if temperature is not None:
        data.use_temperature = True
        data.temperature = temperature
    if kind == "AREA":
        data.size = size
        if size_y is not None:
            data.shape = "RECTANGLE"
            data.size_y = size_y
    elif kind == "SUN":
        data.angle = math.radians(size)
    else:
        data.shadow_soft_size = size
    obj = bpy.data.objects.new(data.name, data)
    bpy.context.scene.collection.objects.link(obj)
    obj.visible_camera = visible_camera
    obj.location = location
    look_at(obj, target)
    return obj


def exclude_light(light_obj, *objects) -> None:
    """Light linking (Cycles): light_obj stops lighting these objects, e.g. keep rim strips off a mirror floor."""
    linking = light_obj.light_linking
    if linking.receiver_collection is None:
        linking.receiver_collection = bpy.data.collections.new(f"{light_obj.name}_receivers")
    coll = linking.receiver_collection
    for obj in objects:
        if obj.name not in coll.objects:
            coll.objects.link(obj)
    for entry in coll.collection_objects:
        entry.light_linking.link_state = "EXCLUDE"


def hex_color(value: str) -> tuple[float, float, float]:
    """'#8cc152' (sRGB, as designers and colour pickers give it) -> linear RGB for Blender inputs."""
    value = value.lstrip("#")

    def linear(channel: int) -> float:
        c = channel / 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    return tuple(linear(int(value[i : i + 2], 16)) for i in (0, 2, 4))


def material(name: str, color=(0.8, 0.8, 0.8), metallic: float = 0.0, roughness: float = 0.5, emission=None, emission_strength: float = 1.0, alpha: float = 1.0, **inputs):
    """Principled BSDF material. Colours are linear RGB tuples or '#rrggbb' sRGB hex strings.

    Extra Principled inputs by socket name with spaces as underscores, e.g. Transmission_Weight=1, Coat_Weight=1.
    """
    if isinstance(color, str):
        color = hex_color(color)
    if isinstance(emission, str):
        emission = hex_color(emission)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color[:3], 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Alpha"].default_value = alpha
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = (*emission[:3], 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    for key, value in inputs.items():
        bsdf.inputs[key.replace("_", " ")].default_value = value
    mat.diffuse_color = (*color[:3], alpha)
    return mat


def assign(obj, mat, slot: int | None = None) -> None:
    """Put mat on obj: replace every slot by default, or a single slot index."""
    if slot is None:
        obj.data.materials.clear()
        obj.data.materials.append(mat)
    else:
        while len(obj.data.materials) <= slot:
            obj.data.materials.append(None)
        obj.data.materials[slot] = mat


def _find_map(directory: Path, *keys: str) -> Path | None:
    for path in sorted(directory.rglob("*")):
        stem = path.stem.lower()
        if path.suffix.lower() in (".png", ".jpg", ".jpeg", ".exr", ".tif", ".tiff") and any(k in stem for k in keys):
            return path
    return None


def pbr_material(name: str, texture_dir, scale: float = 1.0, displacement: float = 0.0):
    """Material from a folder of PBR maps (Poly Haven layout: *_diff, *_rough, *_nor_gl, *_metal, *_disp, *_arm).

    Box-projects in Object space, so it works on meshes without UVs. Object scale stretches
    the texture: apply scale first (bpy.ops.object.transform_apply(scale=True) with the
    object active) or size geometry in mesh data. scale = texture repeats per metre.
    displacement > 0 enables displacement (Cycles).
    """
    directory = Path(texture_dir)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    coords = nodes.new("ShaderNodeTexCoord")
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (scale, scale, scale)
    links.new(coords.outputs["Object"], mapping.inputs["Vector"])

    def image(path: Path, non_color: bool):
        node = nodes.new("ShaderNodeTexImage")
        node.image = bpy.data.images.load(str(path), check_existing=True)
        node.projection = "BOX"
        node.projection_blend = 0.2
        if non_color:
            node.image.colorspace_settings.name = "Non-Color"
        links.new(mapping.outputs["Vector"], node.inputs["Vector"])
        return node

    if diff := _find_map(directory, "diff", "albedo", "basecolor", "color", "_col"):
        links.new(image(diff, False).outputs["Color"], bsdf.inputs["Base Color"])
    else:
        print(f"bk.pbr_material: no base colour map found in {directory}; set Base Color yourself")
    arm = _find_map(directory, "_arm")
    if arm:
        split = nodes.new("ShaderNodeSeparateColor")
        links.new(image(arm, True).outputs["Color"], split.inputs["Color"])
        links.new(split.outputs["Green"], bsdf.inputs["Roughness"])
        links.new(split.outputs["Blue"], bsdf.inputs["Metallic"])
    else:
        if rough := _find_map(directory, "rough"):
            links.new(image(rough, True).outputs["Color"], bsdf.inputs["Roughness"])
        if metal := _find_map(directory, "metal"):
            links.new(image(metal, True).outputs["Color"], bsdf.inputs["Metallic"])
    if nor := _find_map(directory, "nor_gl", "normal_gl", "normal", "nor"):
        normal = nodes.new("ShaderNodeNormalMap")
        links.new(image(nor, True).outputs["Color"], normal.inputs["Color"])
        links.new(normal.outputs["Normal"], bsdf.inputs["Normal"])
    if displacement > 0 and (disp := _find_map(directory, "disp", "height")):
        node = nodes.new("ShaderNodeDisplacement")
        node.inputs["Scale"].default_value = displacement
        links.new(image(disp, True).outputs["Color"], node.inputs["Height"])
        links.new(node.outputs["Displacement"], nodes["Material Output"].inputs["Displacement"])
        mat.displacement_method = "BOTH"
    return mat


def hdri(path, strength: float = 1.0, rotation_deg: float = 0.0, background_color=None) -> None:
    """Light the scene with an equirectangular HDRI (.hdr/.exr).

    background_color (colour or '#hex') replaces the HDRI where the camera sees the sky directly,
    while reflections and lighting still come from the HDRI (black studio sweeps, product shots).
    """
    import math

    scene = bpy.context.scene
    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    world = scene.world
    if not world.use_nodes:
        world.use_nodes = True
    nodes, links = world.node_tree.nodes, world.node_tree.links
    nodes.clear()
    coords = nodes.new("ShaderNodeTexCoord")
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Rotation"].default_value = (0, 0, math.radians(rotation_deg))
    env = nodes.new("ShaderNodeTexEnvironment")
    env.image = bpy.data.images.load(str(path), check_existing=True)
    background = nodes.new("ShaderNodeBackground")
    background.inputs["Strength"].default_value = strength
    output = nodes.new("ShaderNodeOutputWorld")
    links.new(coords.outputs["Generated"], mapping.inputs["Vector"])
    links.new(mapping.outputs["Vector"], env.inputs["Vector"])
    links.new(env.outputs["Color"], background.inputs["Color"])
    if background_color is None:
        links.new(background.outputs["Background"], output.inputs["Surface"])
        return
    if isinstance(background_color, str):
        background_color = hex_color(background_color)
    plain = nodes.new("ShaderNodeBackground")
    plain.inputs["Color"].default_value = (*background_color[:3], 1.0)
    path_node = nodes.new("ShaderNodeLightPath")
    mix = nodes.new("ShaderNodeMixShader")
    links.new(path_node.outputs["Is Camera Ray"], mix.inputs["Fac"])
    links.new(background.outputs["Background"], mix.inputs[1])
    links.new(plain.outputs["Background"], mix.inputs[2])
    links.new(mix.outputs["Shader"], output.inputs["Surface"])


def ground(size: float | None = None, margin: float = 4.0, mat=None, name: str = "Ground"):
    """Plane under all current geometry, sized to the scene unless size is given."""
    geometry = [o for o in bpy.context.scene.objects if o.type in GEOMETRY_TYPES]
    if geometry:
        lo, hi = world_bbox(geometry)
        center = (lo + hi) / 2
        extent = size or max(hi.x - lo.x, hi.y - lo.y, 1.0) * margin
        z = lo.z
    else:
        center, extent, z = Vector((0, 0, 0)), size or 10.0, 0.0
    bpy.ops.mesh.primitive_plane_add(size=extent, location=(center.x, center.y, z))
    plane = bpy.context.active_object
    plane.name = name
    if mat is not None:
        assign(plane, mat)
    return plane


def import_file(path) -> list:
    """Import .glb/.gltf/.obj/.fbx/.stl/.ply/.usd*/.blend (appends all objects); returns the new objects."""
    path = Path(path)
    ext = path.suffix.lower()
    before = set(bpy.data.objects)
    if ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=str(path))
    elif ext == ".obj":
        bpy.ops.wm.obj_import(filepath=str(path))
    elif ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=str(path))
    elif ext == ".stl":
        bpy.ops.wm.stl_import(filepath=str(path))
    elif ext == ".ply":
        bpy.ops.wm.ply_import(filepath=str(path))
    elif ext in (".usd", ".usda", ".usdc", ".usdz"):
        bpy.ops.wm.usd_import(filepath=str(path))
    elif ext == ".blend":
        with bpy.data.libraries.load(str(path)) as (src, dst):
            dst.objects = src.objects
        for obj in dst.objects:
            if obj is not None:
                bpy.context.scene.collection.objects.link(obj)
    else:
        raise ValueError(f"unsupported import format {ext!r}")
    return [o for o in bpy.data.objects if o not in before]


def mesh(name: str, verts, faces, materials=None, material_indices=None, smooth: bool = False):
    """Object from raw geometry: verts [(x, y, z)], faces [(i, j, k, ...)].

    materials is a list of materials for slots; material_indices gives each face's slot.
    """
    data = bpy.data.meshes.new(name)
    data.from_pydata([tuple(v) for v in verts], [], [tuple(f) for f in faces])
    data.validate()
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    for mat in materials or []:
        data.materials.append(mat)
    if material_indices is not None:
        data.polygons.foreach_set("material_index", list(material_indices))
    if smooth:
        data.shade_smooth()
    data.update()
    return obj


def lathe(name: str, profile, segments: int = 64, smooth: bool = True, angles_deg=None):
    """Spin a 2D profile [(radius, z), ...] around Z into a closed solid of revolution (vases, mugs, bottles).

    Points with radius 0 become poles. Walk the profile as the outline of the cross-section:
    for a hollow vessel go up the outside and back down the inside. angles_deg overrides the
    uniform segments with explicit ring angles, e.g. facets with built-in chamfers
    ([0, 5, 40, 50, 85, ...]); a Bevel modifier on a low-segment lathe breaks the solid.
    """
    import math

    ring_angles = [math.radians(a) for a in angles_deg] if angles_deg else [2 * math.pi * i / segments for i in range(segments)]
    segments = len(ring_angles)
    verts, faces, rings = [], [], []
    for r, z in profile:
        if r <= 1e-9:
            rings.append([len(verts)])
            verts.append((0.0, 0.0, z))
            continue
        ring = []
        for a in ring_angles:
            ring.append(len(verts))
            verts.append((r * math.cos(a), r * math.sin(a), z))
        rings.append(ring)
    closed = len(profile) > 2 and tuple(profile[0]) == tuple(profile[-1])
    pairs = list(zip(rings, rings[1:]))
    for a, b in pairs:
        if len(a) == 1 and len(b) == 1:
            continue
        for i in range(segments):
            j = (i + 1) % segments
            if len(a) == 1:
                faces.append((a[0], b[i], b[j]))
            elif len(b) == 1:
                faces.append((a[i], b[0], a[j]))
            else:
                faces.append((a[i], a[j], b[j], b[i]))
    obj = mesh(name, verts, faces, smooth=smooth)
    import bmesh

    bm = bmesh.new()
    bm.from_mesh(obj.data)
    if closed:
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-7)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    return obj


def sweep(name: str, path, section, scale=None, cap: bool = True, smooth: bool = True):
    """Sweep a closed 2D section [(x, y), ...] along a 3D path [(x, y, z), ...] (handles, arms, pipes, cables).

    The section is drawn in the plane normal to the path, x toward the path's initial "right" and y
    toward its initial "up" (world Z, or Y for vertical paths). scale is a list of per-point factors
    or a function of t in [0, 1] (tapers, swellings). Frames are rotation-minimizing, so the
    section does not twist. cap=True closes both ends into a solid.
    """
    points = [Vector(p) for p in path]
    count = len(points)
    tangents = []
    for i in range(count):
        a, b = points[max(i - 1, 0)], points[min(i + 1, count - 1)]
        tangents.append((b - a).normalized())
    world_up = Vector((0, 0, 1)) if abs(tangents[0].z) < 0.99 else Vector((0, 1, 0))
    right = tangents[0].cross(world_up).normalized()
    frames = []
    for i, tangent in enumerate(tangents):
        if i:
            right = (right - tangent * right.dot(tangent)).normalized()
        up = right.cross(tangent).normalized() * -1
        frames.append((right, up))
    verts, faces = [], []
    n = len(section)
    for i, (point, (right, up)) in enumerate(zip(points, frames)):
        t = i / (count - 1) if count > 1 else 0.0
        factor = scale(t) if callable(scale) else (scale[i] if scale is not None else 1.0)
        for x, y in section:
            verts.append(point + right * (x * factor) + up * (y * factor))
    for i in range(count - 1):
        for j in range(n):
            k = (j + 1) % n
            faces.append((i * n + j, i * n + k, (i + 1) * n + k, (i + 1) * n + j))
    if cap:
        faces.append(tuple(reversed(range(n))))
        faces.append(tuple((count - 1) * n + j for j in range(n)))
    obj = mesh(name, verts, faces, smooth=smooth)
    import bmesh

    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    return obj


def hole_cutter(location, direction, diameter: float, depth: float, countersink_diameter: float | None = None,
                countersink_angle_deg: float = 90.0, segments: int = 48, name: str = "HoleCutter"):
    """One lathed cutter for a plain or countersunk hole, for bk.boolean.

    location is the hole's entry point on the surface; direction points into the material. The
    cutter overshoots both faces so the boolean never meets coplanar faces. Build a countersunk
    hole from this single solid; separate cylinder + cone cutters with aligned seams leave open edges.
    """
    import math

    r = diameter / 2
    overshoot = max(depth * 0.05, 1e-4)
    profile = [(0, -depth - overshoot), (r, -depth - overshoot)]
    if countersink_diameter:
        R = countersink_diameter / 2
        sink = (R - r) / math.tan(math.radians(countersink_angle_deg) / 2)
        profile += [(r, -sink), (R, 0.0), (R + overshoot, overshoot)]
        profile += [(R + overshoot, 2 * overshoot)]
    else:
        profile += [(r, 2 * overshoot)]
    profile += [(0, 2 * overshoot)]
    cutter = lathe(name, profile, segments=segments, smooth=False)
    axis = Vector(direction).normalized()
    cutter.rotation_mode = "QUATERNION"
    cutter.rotation_quaternion = (-axis).to_track_quat("Z", "Y")
    cutter.location = location
    bpy.context.view_layer.update()
    return cutter


def overhangs(obj, max_angle_deg: float = 45.0, unit: str = "mm") -> dict:
    """Downward faces steeper than max_angle_deg from vertical that aren't on the bed (lowest z): they need support.

    Returns area (mm² with unit="mm", else m²) and the face count; 0 means printable without supports as placed.
    """
    import bmesh
    import math

    depsgraph = bpy.context.evaluated_depsgraph_get()
    bm = bmesh.new()
    bm.from_object(obj, depsgraph)
    bm.transform(obj.matrix_world)
    bm.normal_update()
    bed = min(v.co.z for v in bm.verts)
    limit = -math.cos(math.radians(90 - max_angle_deg))
    tolerance = max((max(v.co.z for v in bm.verts) - bed) * 1e-4, 1e-7)
    faces = [f for f in bm.faces if f.normal.z < limit and max(v.co.z for v in f.verts) > bed + tolerance]
    area = sum(f.calc_area() for f in faces) * (1e6 if unit == "mm" else 1.0)
    bm.free()
    return {"faces": len(faces), f"area_{unit}2": round(area, 3)}


def turntable(obj, start: int = 1, end: int = 96, degrees: float = 360.0) -> None:
    """Constant-speed spin about Z from start to end+1, so frames start..end loop seamlessly."""
    import math

    key(obj, "rotation_euler", {start: 0.0, end + 1: math.radians(degrees)}, index=2, interpolation="LINEAR")


def apply_modifiers(obj) -> None:
    """Bake every modifier on obj into its mesh."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(depsgraph)
    data = bpy.data.meshes.new_from_object(evaluated, preserve_all_data_layers=True, depsgraph=depsgraph)
    obj.modifiers.clear()
    old = obj.data
    obj.data = data
    if old.users == 0:
        bpy.data.meshes.remove(old)


def boolean(target, cutter, operation: str = "DIFFERENCE", apply: bool = True, remove_cutter: bool = True):
    """Boolean target with cutter (DIFFERENCE, UNION, INTERSECT) using the exact solver."""
    mod = target.modifiers.new(f"bool_{cutter.name}", "BOOLEAN")
    mod.operation = operation
    mod.solver = "EXACT"
    mod.object = cutter
    cutter.hide_render = True
    cutter.display_type = "WIRE"
    if apply:
        bpy.context.view_layer.update()
        apply_modifiers(target)
        _drop_empty_slots(target)
        if remove_cutter:
            bpy.data.objects.remove(cutter, do_unlink=True)
    return target


def _drop_empty_slots(obj) -> None:
    mats = obj.data.materials
    if len(mats) < 2 or all(m is not None for m in mats):
        return
    keep = [i for i, m in enumerate(mats) if m is not None] or [0]
    remap = {old: keep.index(old) if old in keep else 0 for old in range(len(mats))}
    indices = [0] * len(obj.data.polygons)
    obj.data.polygons.foreach_get("material_index", indices)
    obj.data.polygons.foreach_set("material_index", [remap.get(i, 0) for i in indices])
    for i in reversed(range(len(mats))):
        if i not in keep:
            mats.pop(index=i)


def duplicate(obj, name: str | None = None):
    """Independent copy of obj (own mesh data) linked into the scene."""
    copy = obj.copy()
    if obj.data is not None:
        copy.data = obj.data.copy()
    copy.name = name or f"{obj.name}_copy"
    bpy.context.scene.collection.objects.link(copy)
    return copy


def overlap_volume(a, b) -> float:
    """Volume (m³) where two solids intersect; 0 means they clear each other. For fit/interference checks."""
    probe = duplicate(a, "_overlap_probe")
    cutter = duplicate(b, "_overlap_cutter")
    boolean(probe, cutter, "INTERSECT")
    report_volume = 0.0
    if len(probe.data.polygons):
        import bmesh

        bm = bmesh.new()
        bm.from_mesh(probe.data)
        bm.transform(probe.matrix_world)
        report_volume = abs(bm.calc_volume(signed=True))
        bm.free()
    bpy.data.objects.remove(probe, do_unlink=True)
    return report_volume


def box(lo, hi, name: str = "Box", mat=None):
    """Axis-aligned box from corner lo to corner hi, built in mesh data (object scale stays 1)."""
    (x0, y0, z0), (x1, y1, z1) = lo, hi
    verts = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
    faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return mesh(name, verts, faces, materials=[mat] if mat else None)


def extrude(name: str, outline, depth: float, plane: str = "XY", offset: float = 0.0, mat=None):
    """Prism from a closed 2D outline [(u, v), ...] (no repeated last point), extruded depth along the plane's normal.

    plane "XY" extrudes along +Z from z=offset; "XZ" along +Y; "YZ" along +X. Use it for plates,
    gears, brackets, and anything drawn as a profile; cut holes afterwards with bk.boolean.
    """
    import bmesh

    axes = {"XY": (0, 1, 2), "XZ": (0, 2, 1), "YZ": (1, 2, 0)}[plane]

    def point(u, v, w):
        p = [0.0, 0.0, 0.0]
        p[axes[0]], p[axes[1]], p[axes[2]] = u, v, w
        return p

    bm = bmesh.new()
    base = [bm.verts.new(point(u, v, offset)) for u, v in outline]
    face = bm.faces.new(base)
    extruded = bmesh.ops.extrude_face_region(bm, geom=[face])
    top = [g for g in extruded["geom"] if isinstance(g, bmesh.types.BMVert)]
    shift = point(0, 0, depth)
    bmesh.ops.translate(bm, verts=top, vec=shift)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    data = bpy.data.meshes.new(name)
    bm.to_mesh(data)
    bm.free()
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    if mat is not None:
        data.materials.append(mat)
    return obj


def rounded_rect(width: float, height: float, radius: float, segments: int = 8, center=(0.0, 0.0)) -> list:
    """Closed outline of a rounded rectangle for bk.extrude."""
    import math

    cx, cy = center
    hw, hh = width / 2 - radius, height / 2 - radius
    points = []
    for corner, (sx, sy) in enumerate(((1, 1), (-1, 1), (-1, -1), (1, -1))):
        for i in range(segments + 1):
            a = math.pi / 2 * (corner + i / segments)
            points.append((cx + sx * hw + radius * math.cos(a), cy + sy * hh + radius * math.sin(a)))
    return points


def smooth(obj, angle_deg: float = 30.0) -> None:
    """Smooth shading with edges sharper than angle_deg kept sharp (Blender 5 has no auto-smooth toggle)."""
    import math

    obj.data.shade_smooth()
    obj.data.set_sharp_from_angle(angle=math.radians(angle_deg))


def socket(node, identifier: str):
    """Node socket by identifier, e.g. socket(mix, "A_Color"); string keys on node.inputs only match display names."""
    for sock in (*node.inputs, *node.outputs):
        if sock.identifier == identifier:
            return sock
    raise KeyError(f"{node.name} has no socket with identifier {identifier!r}")


def place(path, location=(0, 0, 0), rotation_deg=(0, 0, 0), scale: float = 1.0, name: str | None = None):
    """Import a model file under one empty and position it; returns the empty (move/rotate/scale that)."""
    import math

    objects = import_file(path)
    root = bpy.data.objects.new(name or Path(path).stem, None)
    bpy.context.scene.collection.objects.link(root)
    for obj in objects:
        if obj.parent is None:
            obj.parent = root
    root.location = location
    root.rotation_euler = [math.radians(a) for a in rotation_deg]
    root.scale = (scale, scale, scale)
    bpy.context.view_layer.update()
    return root


def mesh_report(obj, unit: str = "m") -> dict:
    """Solid-model checks with modifiers applied: manifold, open edges, pieces, volume, self-intersections.

    watertight is True only when there are no non-manifold edges, no open edges, positive volume,
    and no self-intersections. Use it before exporting anything meant to be printed or booleaned.
    unit="mm" reports size in mm and volume in cm³ (for a scene modelled in metres).
    """
    import bmesh
    from mathutils.bvhtree import BVHTree

    depsgraph = bpy.context.evaluated_depsgraph_get()
    bm = bmesh.new()
    bm.from_object(obj, depsgraph)
    bm.transform(obj.matrix_world)
    open_edges = sum(1 for e in bm.edges if e.is_boundary)
    non_manifold = sum(1 for e in bm.edges if not e.is_manifold)
    non_manifold_verts = sum(1 for v in bm.verts if not v.is_manifold)
    pieces, seen = 0, set()
    for vert in bm.verts:
        if vert.index in seen:
            continue
        pieces += 1
        stack = [vert]
        while stack:
            v = stack.pop()
            if v.index in seen:
                continue
            seen.add(v.index)
            stack.extend(e.other_vert(v) for e in v.link_edges)
    volume = bm.calc_volume(signed=True)
    bm.faces.ensure_lookup_table()
    tree = BVHTree.FromBMesh(bm, epsilon=0.0)
    face_verts = [{v.index for v in f.verts} for f in bm.faces]
    self_hits = sum(
        1 for i, j in tree.overlap(tree)
        if i < j and not (face_verts[i] & face_verts[j])
    )
    lo, hi = world_bbox([obj])
    length, vol = (1000.0, 1e6) if unit == "mm" else (1.0, 1.0)
    report = {
        "verts": len(bm.verts),
        "faces": len(bm.faces),
        "open_edges": open_edges,
        "non_manifold_edges": non_manifold,
        "non_manifold_verts": non_manifold_verts,
        "pieces": pieces,
        f"volume_{'cm3' if unit == 'mm' else 'm3'}": round(volume * vol, 9),
        "self_intersections": self_hits,
        f"size_{unit}": [round(v * length, 6) for v in (hi - lo)],
    }
    bm.free()
    report["watertight"] = open_edges == 0 and non_manifold == 0 and volume > 0 and self_hits == 0
    return report


def fcurves(obj):
    """F-curves of obj's action (Blender 5 layered actions: action.fcurves no longer exists)."""
    from bpy_extras.anim_utils import action_get_channelbag_for_slot

    ad = obj.animation_data
    if not ad or not ad.action:
        return []
    channelbag = action_get_channelbag_for_slot(ad.action, ad.action_slot)
    return list(channelbag.fcurves) if channelbag else []


def key(obj, path: str, frames: dict, index: int = -1, interpolation: str = "BEZIER", easing: str = "AUTO") -> None:
    """Keyframe obj.<path> at {frame: value}. index picks one component (e.g. 2 for location z).

    interpolation: CONSTANT, LINEAR, BEZIER, SINE, QUAD, CUBIC, BOUNCE, ELASTIC, ...;
    easing: AUTO, EASE_IN, EASE_OUT, EASE_IN_OUT.
    """
    for frame, value in frames.items():
        if index >= 0:
            getattr(obj, path)[index] = value
        else:
            setattr(obj, path, value)
        obj.keyframe_insert(path, index=index, frame=frame)
    for curve in fcurves(obj):
        if curve.data_path == path and (index < 0 or curve.array_index == index):
            for point in curve.keyframe_points:
                if point.co.x in frames:
                    point.interpolation = interpolation
                    point.easing = easing


def enable_gpu() -> str:
    """Point Cycles at the best GPU backend; returns OPTIX, CUDA, or CPU."""
    prefs = bpy.context.preferences.addons["cycles"].preferences
    for backend in ("OPTIX", "CUDA"):
        try:
            prefs.compute_device_type = backend
        except TypeError:
            continue
        prefs.get_devices()
        devices = [d for d in prefs.devices if d.type == backend]
        if devices:
            for d in prefs.devices:
                d.use = d.type == backend
            return backend
    prefs.compute_device_type = "NONE"
    return "CPU"


def gpu_devices() -> list[str]:
    """Cycles compute devices Blender can see."""
    prefs = bpy.context.preferences.addons["cycles"].preferences
    return [f"{d.type}: {d.name}" for d in prefs.devices]
