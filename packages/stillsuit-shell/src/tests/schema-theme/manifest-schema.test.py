from copy import deepcopy
from json import loads
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator

TEST_DIR = Path(__file__).resolve().parent
PACKAGE_ROOT = TEST_DIR.parents[2]
MANIFEST_SCHEMA_PATH = PACKAGE_ROOT / "schemas" / "manifest.v1.json"
THEME_SCHEMA_PATH = PACKAGE_ROOT / "schemas" / "theme.v1.json"
BUILTIN_ROOT = PACKAGE_ROOT / "src" / "plugins" / "builtin"
THEME_FIXTURE_PATH = TEST_DIR.parent / "fixtures" / "theme.v1.json"

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
    Draft202012Validator(schema).validate(_read_json(THEME_FIXTURE_PATH))


def main() -> None:
    _check_manifest_schema()
    _check_theme_schema()
    print("schema contracts ok: builtin manifests, reverse contribution constraints, theme fixture")


if __name__ == "__main__":
    main()
