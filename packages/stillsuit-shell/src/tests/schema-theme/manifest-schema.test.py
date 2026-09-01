from copy import deepcopy
from json import loads
from pathlib import Path
from subprocess import run
from typing import Any

from jsonschema import Draft202012Validator

TEST_DIR = Path(__file__).resolve().parent
PACKAGE_ROOT = TEST_DIR.parents[2]
MANIFEST_SCHEMA_PATH = PACKAGE_ROOT / "schemas" / "manifest.v1.json"
THEME_SCHEMA_PATH = PACKAGE_ROOT / "schemas" / "theme.v2.json"
BUILTIN_ROOT = PACKAGE_ROOT / "src" / "plugins" / "builtin"
CANONICAL_THEME_PATH = PACKAGE_ROOT / "themes" / "catppuccin-mocha.nix"
DESIGN_LAB_THEME_ROOT = PACKAGE_ROOT / "design-lab" / "themes"

CONTRIBUTIONS = {
    "bar": ("bar", "per-output"),
    "barWidget": ("bar-widget", "per-output"),
    "service": ("service", "global"),
    "panel": ("panel", "global"),
    "overlay": ("overlay", "global"),
    "menu": ("menu", "global"),
}


def _read_json(path: Path) -> Any:
    return loads(path.read_text())


def _read_canonical_theme() -> dict[str, Any]:
    result = run(
        ["nix", "eval", "--json", "--file", str(CANONICAL_THEME_PATH)],
        check=True,
        capture_output=True,
        text=True,
    )
    return loads(result.stdout)


def _base_manifest() -> dict[str, Any]:
    return {
        "schemaVersion": 1,
        "id": "stillsuit.schema-fixture",
        "name": "Schema fixture",
        "version": "1.0.0",
        "apiVersion": "1",
        "kinds": ["panel"],
        "entryPoints": {"panel": "Panel.qml"},
        "scope": {"panel": "global"},
    }


def _assert_rejected(
    validator: Any,
    manifest: dict[str, Any],
    description: str,
) -> None:
    if not list(validator.iter_errors(manifest)):
        raise AssertionError(f"schema accepted {description}")


def _check_manifest_schema() -> None:
    schema = _read_json(MANIFEST_SCHEMA_PATH)
    Draft202012Validator.check_schema(schema)
    validator = Draft202012Validator(schema)

    for manifest_path in sorted(BUILTIN_ROOT.glob("*/manifest.json")):
        errors = sorted(validator.iter_errors(_read_json(manifest_path)), key=str)
        if errors:
            raise AssertionError(f"{manifest_path}: {errors[0].message}")

    for key, (kind, scope) in CONTRIBUTIONS.items():
        if kind == "panel":
            manifest = _base_manifest()
            manifest["kinds"] = ["service"]
            manifest["entryPoints"] = {"service": "Service.qml"}
            manifest["scope"] = {"service": "global"}
        else:
            manifest = _base_manifest()

        with_entry_point = deepcopy(manifest)
        with_entry_point["entryPoints"][key] = "Extra.qml"
        _assert_rejected(
            validator,
            with_entry_point,
            f"the undeclared {key} entry point",
        )

        with_scope = deepcopy(manifest)
        with_scope["scope"][key] = scope
        _assert_rejected(
            validator,
            with_scope,
            f"the undeclared {key} scope",
        )

    valid_multi = _base_manifest()
    valid_multi["kinds"].append("overlay")
    valid_multi["entryPoints"]["overlay"] = "Overlay.qml"
    valid_multi["scope"]["overlay"] = "per-output"
    validator.validate(valid_multi)


def _check_theme_schema() -> None:
    schema = _read_json(THEME_SCHEMA_PATH)
    Draft202012Validator.check_schema(schema)
    validator = Draft202012Validator(schema)
    theme = _read_canonical_theme()
    validator.validate(theme)

    expected_top_level = {
        "schemaVersion",
        "identity",
        "palette",
        "semantic",
        "component",
        "typography",
        "metrics",
        "motion",
        "effects",
    }
    if set(theme) != expected_top_level:
        raise AssertionError(f"unexpected production theme levels: {sorted(theme)}")

    locked_values = {
        "schemaVersion": theme["schemaVersion"],
        "bodyFamily": theme["typography"]["bodyFamily"],
        "monoFamily": theme["typography"]["monoFamily"],
        "iconFamily": theme["typography"]["iconFamily"],
        "barHeight": theme["metrics"]["barHeight"],
        "barOuterGap": theme["metrics"]["barOuterGap"],
        "radiusMedium": theme["metrics"]["radiusMedium"],
        "surfaceOpacity": theme["effects"]["surfaceOpacity"],
        "accent": theme["semantic"]["accent"]["primary"],
        "panel": theme["semantic"]["surface"]["panel"],
        "raised": theme["semantic"]["surface"]["raised"],
        "primaryText": theme["semantic"]["content"]["primary"],
        "motionFast": theme["motion"]["fast"],
        "motionNormal": theme["motion"]["normal"],
        "motionSlow": theme["motion"]["slow"],
        "motionEasing": theme["motion"]["easing"],
    }
    expected_locked_values = {
        "schemaVersion": 2,
        "bodyFamily": "Noto Sans",
        "monoFamily": "JetBrainsMono Nerd Font",
        "iconFamily": "Material Symbols Rounded",
        "barHeight": 26,
        "barOuterGap": 0,
        "radiusMedium": 7,
        "surfaceOpacity": 0.8,
        "accent": "#89b4fa",
        "panel": "#181825",
        "raised": "#313244",
        "primaryText": "#cdd6f4",
        "motionFast": 66,
        "motionNormal": 99,
        "motionSlow": 143,
        "motionEasing": "out-cubic",
    }
    if locked_values != expected_locked_values:
        raise AssertionError(
            f"production theme differs from the locked baseline: {locked_values}"
        )

    motion = theme["motion"]
    if not motion["fast"] < motion["normal"] < motion["slow"]:
        raise AssertionError(f"motion tiers are not strictly ordered: {motion}")

    palette = theme["palette"]
    semantic = theme["semantic"]
    component = theme["component"]
    if semantic["accent"]["primary"] != palette["chromatic"]["blue"]:
        raise AssertionError(
            "semantic accent does not derive from palette.chromatic.blue"
        )
    if semantic["surface"]["panel"] != palette["neutral"]["mantle"]:
        raise AssertionError(
            "semantic panel does not derive from palette.neutral.mantle"
        )
    if semantic["surface"]["raised"] != palette["neutral"]["surface0"]:
        raise AssertionError(
            "semantic raised does not derive from palette.neutral.surface0"
        )
    if semantic["content"]["primary"] != palette["neutral"]["text"]:
        raise AssertionError(
            "semantic primary text does not derive from palette.neutral.text"
        )
    if component["osd"].get("background") is not None:
        raise AssertionError("production theme defines component.osd.background")

    missing_surface_panel = deepcopy(theme)
    del missing_surface_panel["semantic"]["surface"]["panel"]
    _assert_rejected(
        validator,
        missing_surface_panel,
        "a production theme without semantic.surface.panel",
    )

    missing_content_primary = deepcopy(theme)
    del missing_content_primary["semantic"]["content"]["primary"]
    _assert_rejected(
        validator,
        missing_content_primary,
        "a production theme without semantic.content.primary",
    )

    unexpected_semantic_role = deepcopy(theme)
    unexpected_semantic_role["semantic"]["surface"]["tooltip"] = "#181825"
    _assert_rejected(
        validator,
        unexpected_semantic_role,
        "a production theme with unexpected semantic.surface.tooltip",
    )

    unexpected_osd_background = deepcopy(theme)
    unexpected_osd_background["component"]["osd"]["background"] = "#181825"
    _assert_rejected(
        validator,
        unexpected_osd_background,
        "a production theme with component.osd.background",
    )


def _check_design_lab_theme_schema() -> None:
    schema = _read_json(THEME_SCHEMA_PATH)
    Draft202012Validator.check_schema(schema)
    validator = Draft202012Validator(schema)

    themes = [_read_json(path) for path in sorted(DESIGN_LAB_THEME_ROOT.glob("*.json"))]
    if len(themes) != 3:
        raise AssertionError(f"expected three design-lab themes, found {len(themes)}")
    for theme in themes:
        validator.validate(theme)

    unexpected_osd_background = deepcopy(themes[0])
    unexpected_osd_background["component"]["osd"]["background"] = "#181825"
    _assert_rejected(
        validator,
        unexpected_osd_background,
        "a design-lab theme with the retired component.osd.background token",
    )

    missing_osd_border = deepcopy(themes[0])
    del missing_osd_border["component"]["osd"]["border"]
    _assert_rejected(
        validator, missing_osd_border, "a design-lab theme without component.osd.border"
    )

    missing_panel_row_danger = deepcopy(themes[0])
    del missing_panel_row_danger["component"]["panel"]["rowDanger"]
    _assert_rejected(
        validator,
        missing_panel_row_danger,
        "a design-lab theme without component.panel.rowDanger",
    )

    missing_notification_warning = deepcopy(themes[0])
    del missing_notification_warning["component"]["notification"]["warning"]
    _assert_rejected(
        validator,
        missing_notification_warning,
        "a design-lab theme without component.notification.warning",
    )


def main() -> None:
    _check_manifest_schema()
    _check_theme_schema()
    _check_design_lab_theme_schema()
    print(
        "schema contracts ok: builtin manifests, reverse contribution constraints, "
        "production theme v2 locked baseline, design-lab themes"
    )


if __name__ == "__main__":
    main()
