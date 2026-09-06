from __future__ import annotations

import importlib.machinery
import json
import subprocess
import tempfile
from pathlib import Path


def main() -> None:
    package = Path(__file__).resolve().parents[3]
    helper = importlib.machinery.SourceFileLoader(
        "runtime_plugins", str(package / "bin/stillsuit-plugins")
    ).load_module()
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        tracked = root / "tracked"
        scratch = root / "scratch"
        tracked.mkdir()
        scratch.mkdir()
        seed = root / "seed.json"
        seed.write_text(json.dumps({"schemaVersion": 1, "selectedBar": "stillsuit.bar", "plugins": []}))
        configuration = {
            "seed": str(seed), "roots": [str(tracked), str(scratch)],
            "state": str(root / "state"), "core": str(package / "src"),
            "schema": str(package / "schemas/manifest.v1.json"),
        }
        manifest = {
            "schemaVersion": 1, "id": "stillsuit.example", "name": "Example",
            "version": "1.0.0", "apiVersion": "1", "kinds": ["bar-widget"],
            "entryPoints": {"barWidget": "Widget.qml"},
            "scope": {"barWidget": "per-output"},
            "barWidget": {"defaultSection": "right", "allowMultiple": False},
        }
        plugin = tracked / "example"
        plugin.mkdir()
        (plugin / "manifest.json").write_text(json.dumps(manifest))
        (plugin / "Widget.qml").write_text('import QtQuick\nItem { implicitWidth: 20 }\n')
        first, errors = helper.scan(configuration, {})
        assert not errors and len(first["plugins"]) == 1
        path = Path(first["plugins"][0]["packageRoot"])
        assert (path / "Widget.qml").read_text() == (plugin / "Widget.qml").read_text()
        same, _ = helper.scan(configuration, {})
        assert first == same
        (plugin / "Widget.qml").write_text('import QtQuick\nItem { implicitWidth: 40 }\n')
        changed, _ = helper.scan(configuration, {})
        assert changed["plugins"][0]["packageRoot"] != str(path)
        assert "20" in (path / "Widget.qml").read_text()
        placed, _ = helper.scan(configuration, {"stillsuit.example": {"enabled": False, "section": "left", "order": 7}})
        assert not placed["plugins"][0]["enabled"]
        assert placed["plugins"][0]["manifest"]["barWidget"]["order"] == 7
        clone = scratch / "duplicate"
        clone.mkdir()
        (clone / "manifest.json").write_text(json.dumps(manifest))
        (clone / "Widget.qml").write_text("invalid QML")
        duplicate, errors = helper.scan(configuration, {})
        assert len(duplicate["plugins"]) == 1 and "precedence" in errors[0]
        (plugin / "leak").symlink_to(seed)
        rejected, errors = helper.scan(configuration, {})
        assert not rejected["plugins"], "invalid preferred plugin must not activate a lower-priority copy"
        assert any("symlink" in error for error in errors)
        (plugin / "leak").unlink()
        invalid = dict(manifest, apiVersion="999")
        (plugin / "manifest.json").write_text(json.dumps(invalid))
        _, errors = helper.scan(configuration, {})
        assert errors
        preferences = root / "prefs.json"
        helper.set_preference(preferences, "stillsuit.example", {"enabled": False})
        helper.set_preference(preferences, "stillsuit.example", {"section": "left", "order": 5})
        assert json.loads(preferences.read_text())["stillsuit.example"]["enabled"] is False
        evaluated = subprocess.run([
            "nix", "eval", "--impure", "--json", "--expr",
            f'let pkgs = import <nixpkgs> {{}}; in import {package}/tests/registry-evaluation.nix {{ inherit pkgs; }}',
        ], check=True, capture_output=True, text=True)
        registry = json.loads(evaluated.stdout)
        assert all(row["manifest"]["id"] != "stillsuit.battery" for row in registry["catalogData"]["plugins"])
        seed.write_text(json.dumps(registry["discoveryData"]))
        configuration["roots"] = [str(package / "src/plugins/builtin")]
        discovered, _ = helper.scan(configuration, {})
        battery = next(row for row in discovered["plugins"] if row["manifest"]["id"] == "stillsuit.battery")
        assert battery["enabled"] is False, "evaluated disabled defaults must survive actual discovery"
    print("runtime plugin discovery, generations, preferences, schema and containment: ok")


if __name__ == "__main__":
    main()
