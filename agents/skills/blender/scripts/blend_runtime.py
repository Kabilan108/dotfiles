"""Runs inside Blender (`blender -b --python blend_runtime.py -- <request.json>`).

The `blend` CLI writes a request file, launches Blender with this script, and
reads the JSON result it writes back. Everything user-visible is decided by
the CLI; this side only performs the operation.
"""

from __future__ import annotations

import contextlib
import io
import json
import math
import os
import sys
import traceback
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import blendkit as bk  # noqa: E402

bpy.context.preferences.filepaths.save_version = 0

VIEW_DIRECTIONS = {
    "front": Vector((0, -1, 0)),
    "back": Vector((0, 1, 0)),
    "right": Vector((1, 0, 0)),
    "left": Vector((-1, 0, 0)),
    "top": Vector((0, -1e-4, 1)),
    "bottom": Vector((0, 1e-4, -1)),
    "iso": Vector((1, -1, 0.8)),
}
ENGINES = {
    "workbench": "BLENDER_WORKBENCH",
    "eevee": "BLENDER_EEVEE",
    "cycles": "CYCLES",
}


def r3(values) -> list[float]:
    return [round(float(v), 4) for v in values]


def save_atomically(path: Path) -> None:
    bpy.context.preferences.filepaths.save_version = 0
    tmp = path.with_name(f".{path.stem}.{os.getpid()}.tmp.blend")
    bpy.ops.wm.save_as_mainfile(filepath=str(tmp), copy=True, compress=True)
    os.replace(tmp, path)


def material_summary(mat: bpy.types.Material) -> dict:
    info: dict = {"name": mat.name, "users": mat.users}
    if not mat.use_nodes:
        info["base_color"] = r3(mat.diffuse_color)
        return info
    images = []
    for node in mat.node_tree.nodes:
        if node.type == "BSDF_PRINCIPLED":
            for key, socket in (
                ("base_color", "Base Color"),
                ("metallic", "Metallic"),
                ("roughness", "Roughness"),
                ("emission_strength", "Emission Strength"),
                ("alpha", "Alpha"),
            ):
                inp = node.inputs.get(socket)
                if inp is None:
                    continue
                if inp.is_linked:
                    info[key] = "linked"
                elif hasattr(inp.default_value, "__len__"):
                    info[key] = r3(inp.default_value)
                else:
                    info[key] = round(float(inp.default_value), 4)
        elif node.type == "TEX_IMAGE" and node.image:
            images.append(node.image.filepath or node.image.name)
    if images:
        info["images"] = images
    return info


def object_summary(obj: bpy.types.Object) -> dict:
    info: dict = {
        "name": obj.name,
        "type": obj.type,
        "location": r3(obj.matrix_world.translation),
        "rotation_deg": r3(math.degrees(a) for a in obj.matrix_world.to_euler()),
        "scale": r3(obj.matrix_world.to_scale()),
        "collection": obj.users_collection[0].name if obj.users_collection else None,
    }
    if obj.parent:
        info["parent"] = obj.parent.name
    if obj.hide_render or obj.hide_get():
        info["hidden"] = True
    if obj.type in bk.GEOMETRY_TYPES:
        info["dimensions"] = r3(obj.dimensions)
        lo, hi = bk.world_bbox([obj])
        info["bbox"] = [r3(lo), r3(hi)]
    if obj.type == "MESH":
        mesh = obj.data
        info["mesh"] = {"verts": len(mesh.vertices), "faces": len(mesh.polygons)}
    if obj.material_slots:
        info["materials"] = [s.material.name if s.material else None for s in obj.material_slots]
    if obj.modifiers:
        info["modifiers"] = [f"{m.name}:{m.type}" for m in obj.modifiers]
    if obj.type == "LIGHT":
        light = obj.data
        info["light"] = {"type": light.type, "energy": light.energy, "color": r3(light.color)}
    if obj.type == "CAMERA":
        cam = obj.data
        info["camera"] = {"type": cam.type, "lens": round(cam.lens, 2), "ortho_scale": round(cam.ortho_scale, 3)}
    if obj.animation_data and obj.animation_data.action:
        info["animated"] = True
    return info


def scene_summary() -> dict:
    scene = bpy.context.scene
    objects = [object_summary(o) for o in scene.objects]
    geometry = bk.framing_objects()
    summary: dict = {
        "file": bpy.data.filepath,
        "scene": scene.name,
        "frame_range": [scene.frame_start, scene.frame_end],
        "fps": scene.render.fps,
        "render": {
            "engine": scene.render.engine,
            "resolution": [scene.render.resolution_x, scene.render.resolution_y],
            "percentage": scene.render.resolution_percentage,
            "samples": {"eevee": scene.eevee.taa_render_samples, "cycles": scene.cycles.samples},
            "view_transform": f"{scene.view_settings.view_transform} / {scene.view_settings.look}",
        },
        "units": {
            "system": scene.unit_settings.system,
            "scale_length": scene.unit_settings.scale_length,
            "length_unit": scene.unit_settings.length_unit,
        },
        "active_camera": scene.camera.name if scene.camera else None,
        "world": world_summary(scene.world),
        "object_count": len(objects),
        "objects": objects,
        "materials": [material_summary(m) for m in bpy.data.materials if m.users],
    }
    if geometry:
        lo, hi = bk.world_bbox(geometry)
        summary["bounds"] = {"min": r3(lo), "max": r3(hi), "size": r3(hi - lo), "of": "framed geometry"}
    return summary


def world_summary(world) -> dict | None:
    if world is None:
        return None
    info: dict = {"name": world.name}
    if world.use_nodes:
        for node in world.node_tree.nodes:
            if node.type == "TEX_ENVIRONMENT" and node.image:
                info["hdri"] = node.image.filepath
            if node.type == "BACKGROUND":
                info["strength"] = round(float(node.inputs["Strength"].default_value), 3)
    return info


class ScriptExit(Exception):
    """A deliberate non-zero sys.exit() from a run script; reported without a traceback."""


def op_run(req: dict) -> dict:
    code = req["code"]
    namespace = {
        "__name__": "__main__",
        "__file__": req.get("script_name", "<blend run>"),
        "bpy": bpy,
        "bk": bk,
        "C": bpy.context,
        "D": bpy.data,
        "Vector": Vector,
        "math": math,
        "PROJECT": Path(req["project"]),
        "ARGS": req.get("args") or {},
    }
    before = {o.name for o in bpy.context.scene.objects}
    out = io.StringIO()
    try:
        with contextlib.redirect_stdout(out):
            try:
                exec(compile(code, namespace["__file__"], "exec"), namespace)
            except SystemExit as exc:
                if exc.code not in (None, 0):
                    raise ScriptExit(f"script called sys.exit({exc.code!r})") from None
    except BaseException as exc:
        exc.blend_stdout = out.getvalue()
        raise
    after = {o.name for o in bpy.context.scene.objects}
    result = {
        "stdout": out.getvalue(),
        "added": sorted(after - before),
        "removed": sorted(before - after),
        "object_count": len(after),
    }
    if req["save"]:
        save_atomically(Path(req["blend"]))
        result["saved"] = True
    return result


def op_new(req: dict) -> dict:
    bk.clear(everything=True)
    scene = bpy.context.scene
    scene.render.resolution_x, scene.render.resolution_y = 1920, 1080
    scene.render.resolution_percentage = 50
    scene.eevee.taa_render_samples = 32
    scene.cycles.samples = 128
    scene.cycles.use_denoising = True
    scene.unit_settings.system = "METRIC"
    save_atomically(Path(req["blend"]))
    return {"saved": True}


def op_inspect(req: dict) -> dict:
    return {"scene": scene_summary()}


def op_export(req: dict) -> dict:
    out = Path(req["out"])
    out.parent.mkdir(parents=True, exist_ok=True)
    ext = out.suffix.lower()
    if req.get("objects"):
        bpy.ops.object.select_all(action="DESELECT")
        for name in req["objects"]:
            obj = bpy.data.objects.get(name)
            if obj is None:
                raise ValueError(f"no object named {name!r}")
            if obj.hide_render or obj.hide_get():
                raise ValueError(f"{name!r} is hidden (hide_render/hide_viewport); exporters skip hidden objects")
            obj.select_set(True)
    selected = bool(req.get("objects"))
    scale = req.get("scale") or 1.0
    if scale != 1.0 and ext in (".glb", ".gltf", ".usd", ".usda", ".usdc", ".usdz"):
        raise ValueError(f"--scale is supported for stl/obj/ply/fbx, not {ext}")
    if ext in (".glb", ".gltf"):
        bpy.ops.export_scene.gltf(
            filepath=str(out),
            export_format="GLB" if ext == ".glb" else "GLTF_SEPARATE",
            use_selection=selected,
            export_apply=True,
        )
    elif ext == ".obj":
        bpy.ops.wm.obj_export(filepath=str(out), export_selected_objects=selected, global_scale=scale, apply_modifiers=True)
    elif ext == ".fbx":
        bpy.ops.export_scene.fbx(filepath=str(out), use_selection=selected, global_scale=scale)
    elif ext == ".stl":
        bpy.ops.wm.stl_export(filepath=str(out), export_selected_objects=selected, global_scale=scale, apply_modifiers=True)
    elif ext == ".ply":
        bpy.ops.wm.ply_export(filepath=str(out), export_selected_objects=selected, global_scale=scale, apply_modifiers=True)
    elif ext in (".usd", ".usda", ".usdc", ".usdz"):
        bpy.ops.wm.usd_export(filepath=str(out), selected_objects_only=selected)
    else:
        raise ValueError(f"unsupported export format {ext!r}")
    size = out.stat().st_size
    if ext == ".stl":
        head = out.read_bytes()[:84]
        empty = b"facet" not in out.read_bytes() if head.startswith(b"solid") else int.from_bytes(head[80:84], "little") == 0
    else:
        empty = size < 64
    if empty:
        out.unlink()
        raise ValueError("the export contained no geometry (hidden objects or an empty selection?)")
    return {"out": str(out), "bytes": size}


ENGINE_NAMES = {v: k for k, v in ENGINES.items()}


def hide_matching(patterns) -> list[str]:
    import fnmatch

    hidden = []
    for obj in bpy.context.scene.objects:
        if patterns and any(fnmatch.fnmatchcase(obj.name, p) for p in patterns):
            obj.hide_render = True
            hidden.append(obj.name)
    if patterns and not hidden:
        raise ValueError(f"--hide matched no objects: {patterns}")
    return hidden


def scene_bounds(targets=None) -> tuple[Vector, float]:
    geometry = targets or bk.framing_objects()
    lo, hi = bk.world_bbox(geometry) if geometry else (Vector((-1, -1, -1)), Vector((1, 1, 1)))
    return (lo + hi) / 2, max((hi - lo).length / 2, 0.01)


def configure_render(scene, req: dict, radius: float) -> dict:
    """Apply only the flags that were passed; everything else stays as the scene has it."""
    if req.get("engine"):
        scene.render.engine = ENGINES[req["engine"]]
    engine = ENGINE_NAMES.get(scene.render.engine, scene.render.engine)
    if req.get("resolution"):
        scene.render.resolution_x, scene.render.resolution_y = req["resolution"]
        scene.render.resolution_percentage = 100
    samples = req.get("samples")
    device = None
    if engine == "cycles":
        device = bk.enable_gpu()
        scene.cycles.device = "GPU" if device != "CPU" else "CPU"
        if samples:
            scene.cycles.samples = samples
        samples = scene.cycles.samples
    elif engine == "eevee":
        if samples:
            scene.eevee.taa_render_samples = samples
        samples = scene.eevee.taa_render_samples
    elif engine == "workbench":
        shading = scene.display.shading
        shading.light = "STUDIO"
        shading.color_type = "MATERIAL"
        shading.show_cavity = True
        shading.cavity_type = "BOTH"
        scene.display.matcap_ssao_distance = radius * 0.1
    pct = scene.render.resolution_percentage / 100
    return {
        "engine": engine,
        "device": device,
        "samples": samples,
        "resolution": [int(scene.render.resolution_x * pct), int(scene.render.resolution_y * pct)],
    }


def studio_lighting(center: Vector, radius: float) -> list[bpy.types.Object]:
    made = []
    for name, direction, energy in (
        ("key", Vector((1, -1, 1.2)), 3.0),
        ("fill", Vector((-1.2, -0.8, 0.5)), 1.2),
        ("rim", Vector((0, 1.2, 1.0)), 2.0),
    ):
        data = bpy.data.lights.new(f"_blend_{name}", "SUN")
        data.energy = energy
        data.angle = math.radians(8)
        obj = bpy.data.objects.new(f"_blend_{name}", data)
        bpy.context.scene.collection.objects.link(obj)
        obj.location = center + direction.normalized() * radius * 3
        bk.look_at(obj, center)
        made.append(obj)
    return made


def apply_lighting(scene, mode: str, engine: str, center: Vector, radius: float) -> bool:
    if engine == "workbench" or mode == "scene":
        return False
    has_lights = any(o.type == "LIGHT" and not o.hide_render for o in scene.objects)
    has_hdri = "hdri" in (world_summary(scene.world) or {})
    if mode == "auto" and (has_lights or has_hdri):
        return False
    studio_lighting(center, radius)
    if scene.world is None:
        scene.world = bpy.data.worlds.new("_blend_world")
    world = scene.world
    if not world.use_nodes:
        world.use_nodes = True
    bg = next((n for n in world.node_tree.nodes if n.type == "BACKGROUND"), None)
    if bg is not None and not bg.inputs["Color"].is_linked:
        bg.inputs["Color"].default_value = (0.18, 0.18, 0.2, 1)
        bg.inputs["Strength"].default_value = 1.0
    return True


def framing_camera(direction: Vector, center: Vector, radius: float, aspect: float, ortho: bool):
    data = bpy.data.cameras.new("_blend_cam")
    data.clip_start = max(radius / 1000, 1e-5)
    data.clip_end = radius * 100
    data.sensor_fit = "AUTO"
    obj = bpy.data.objects.new("_blend_cam", data)
    bpy.context.scene.collection.objects.link(obj)
    # Sensor fit AUTO spans the wider image side; the narrower side decides the fit.
    long_over_short = max(aspect, 1 / aspect)
    if ortho:
        data.type = "ORTHO"
        data.ortho_scale = radius * 2.2 * long_over_short
        distance = radius * 4
    else:
        data.lens = 50
        half_long = math.atan(data.sensor_width / 2 / data.lens)
        half_short = math.atan(math.tan(half_long) / long_over_short)
        distance = radius / math.sin(half_short) * 1.05
    obj.location = center + direction.normalized() * distance
    bk.look_at(obj, center)
    return obj


def op_render(req: dict) -> dict:
    scene = bpy.context.scene
    out_dir = Path(req["out_dir"])
    out_dir.mkdir(parents=True, exist_ok=True)
    scene.render.image_settings.media_type = "IMAGE"
    scene.render.image_settings.file_format = "PNG"
    if req.get("transparent"):
        scene.render.film_transparent = True

    missing = [n for n in req.get("targets") or [] if n not in bpy.data.objects]
    if missing:
        raise ValueError(f"no object named {', '.join(missing)}")
    targets = [bpy.data.objects[n] for n in req.get("targets") or []]
    hidden = hide_matching(req.get("hide"))
    center, radius = scene_bounds(targets)
    if req.get("camera"):
        cam = bpy.data.objects.get(req["camera"])
        if cam is None or cam.type != "CAMERA":
            raise ValueError(f"no camera object named {req['camera']!r}")
        scene.camera = cam
    settings = configure_render(scene, req, radius)
    width, height = settings["resolution"]
    added_studio = apply_lighting(scene, req.get("lighting", "auto"), settings["engine"], center, radius)

    frames = req.get("frames") or [None]
    renders = []
    for frame in frames:
        if frame is not None:
            scene.frame_set(frame)
        for view in req["views"]:
            if view == "camera":
                if scene.camera is None:
                    raise ValueError("view 'camera' requested but the scene has no active camera")
                cam = scene.camera
            else:
                ortho = view in ("front", "back", "left", "right", "top", "bottom")
                cam = framing_camera(VIEW_DIRECTIONS[view], center, radius, width / height, ortho)
            previous = scene.camera
            scene.camera = cam
            label = view if frame is None else f"{view} f{frame}"
            name = view if frame is None else f"{view}_f{frame:04d}"
            path = out_dir / f"{name}.png"
            scene.render.filepath = str(path)
            bpy.ops.render.render(write_still=True)
            scene.camera = previous
            renders.append({"view": view, "frame": frame, "label": label, "path": str(path)})
    return {
        "renders": renders,
        **settings,
        "studio_lighting": added_studio,
        "framed": [o.name for o in targets] if targets else "all geometry",
        "hidden": hidden,
    }


def op_animate(req: dict) -> dict:
    scene = bpy.context.scene
    out = Path(req["out"])
    out.parent.mkdir(parents=True, exist_ok=True)
    if req.get("frames"):
        scene.frame_start, scene.frame_end = req["frames"]
    if req.get("fps"):
        scene.render.fps = req["fps"]
    if req.get("camera"):
        cam = bpy.data.objects.get(req["camera"])
        if cam is None or cam.type != "CAMERA":
            raise ValueError(f"no camera object named {req['camera']!r}")
        scene.camera = cam
    center, radius = scene_bounds()
    settings = configure_render(scene, req, radius)
    width, height = settings["resolution"]
    if req["view"] != "camera":
        scene.camera = framing_camera(VIEW_DIRECTIONS[req["view"]], center, radius, width / height, False)
    elif scene.camera is None:
        raise ValueError("view 'camera' requested but the scene has no active camera")
    added_studio = apply_lighting(scene, req.get("lighting", "auto"), settings["engine"], center, radius)
    image = scene.render.image_settings
    image.media_type = "VIDEO"
    image.file_format = "FFMPEG"
    scene.render.ffmpeg.format = "MPEG4"
    scene.render.ffmpeg.codec = "H264"
    scene.render.ffmpeg.constant_rate_factor = "HIGH"
    partial = out.with_name(f".{out.stem}.{os.getpid()}.part{out.suffix}")
    scene.render.filepath = str(partial)
    scene.render.use_file_extension = False
    try:
        bpy.ops.render.render(animation=True)
    except BaseException:
        partial.unlink(missing_ok=True)
        raise
    os.replace(partial, out)
    return {
        "out": str(out),
        "frames": [scene.frame_start, scene.frame_end],
        "fps": scene.render.fps,
        "studio_lighting": added_studio,
        **settings,
    }


def op_doctor(req: dict) -> dict:
    return {
        "blender": bpy.app.version_string,
        "gpu_device": bk.enable_gpu(),
        "cycles_devices": bk.gpu_devices(),
    }


OPS = {
    "run": op_run,
    "new": op_new,
    "inspect": op_inspect,
    "export": op_export,
    "render": op_render,
    "animate": op_animate,
    "doctor": op_doctor,
}


def main() -> None:
    request_path = Path(sys.argv[sys.argv.index("--") + 1])
    req = json.loads(request_path.read_text())
    result_path = Path(req["result"])
    try:
        payload = {"ok": True, **OPS[req["op"]](req)}
    except BaseException as exc:  # noqa: BLE001 - report every failure to the CLI
        te = traceback.TracebackException.from_exception(exc)
        te.stack = traceback.StackSummary.from_list([f for f in te.stack if f.filename != __file__])
        tb = "".join(te.format())
        if isinstance(exc, ScriptExit):
            tb = ""
        payload = {"ok": False, "error": f"{type(exc).__name__}: {exc}", "traceback": tb}
        payload["stdout"] = getattr(exc, "blend_stdout", "")
    result_path.write_text(json.dumps(payload))


main()
