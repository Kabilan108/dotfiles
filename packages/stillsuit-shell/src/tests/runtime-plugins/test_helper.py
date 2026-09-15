from __future__ import annotations

import importlib.machinery
import json
import subprocess
import tempfile
from pathlib import Path


def main() -> None:
    package = Path(__file__).resolve().parents[3]
    helper_path = package / "bin/stillsuit-plugins"
    helper = importlib.machinery.SourceFileLoader(
        "runtime_plugins", str(helper_path)
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
            "preferences": str(root / "prefs.json"),
            "profiles": str(root / "profiles.json"),
            "activeProfile": str(root / "active-profile.json"),
            "requiredPlugins": [],
        }
        config_path = root / "runtime-discovery.json"
        config_path.write_text(json.dumps(configuration))

        def run_helper(*arguments: str, check: bool = True) -> subprocess.CompletedProcess[str]:
            return subprocess.run(
                [str(helper_path), "--config", str(config_path), *arguments],
                check=check,
                capture_output=True,
                text=True,
            )
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
        assert first["profile"] == {
            "active": "default", "revision": 0,
            "available": [{"id": "default", "name": "Default", "description": "Base plugins"}],
        }
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
        (plugin / "manifest.json").write_text(json.dumps(manifest))
        (clone / "manifest.json").unlink()
        preferences = root / "prefs.json"
        helper.set_preference(preferences, "stillsuit.example", {"enabled": False})
        helper.set_preference(preferences, "stillsuit.example", {"section": "left", "order": 5})
        assert json.loads(preferences.read_text())["stillsuit.example"]["enabled"] is False
        helper.update_setting(preferences, "stillsuit.example", ["globalOnly"], 1, False)
        helper.update_setting(preferences, "stillsuit.example", ["shared"], "global", False)
        helper.update_setting(preferences, "stillsuit.example", ["items"], [1], False)

        run_helper("profile", "create", "work", "--name", "Work", "--description", "Work plugins")
        run_helper("profile", "enable", "work", "stillsuit.example")
        run_helper("profile", "place", "work", "stillsuit.example", "right", "17")
        run_helper("profile", "set", "work", "stillsuit.example", "shared", '"profile"')
        run_helper("profile", "set", "work", "stillsuit.example", "profileOnly", "2")
        run_helper("profile", "set", "work", "stillsuit.example", "items", "[2]")
        profile_schema = json.loads((package / "schemas/profiles.v1.json").read_text())
        helper.Draft202012Validator.check_schema(profile_schema)
        helper.Draft202012Validator(profile_schema).validate(
            json.loads(Path(configuration["profiles"]).read_text())
        )
        listing = json.loads(run_helper("profile", "list").stdout)
        assert listing["active"] == "default"
        assert listing["available"][-1] == {
            "id": "work", "name": "Work", "description": "Work plugins",
        }
        activated = json.loads(run_helper("profile", "activate", "work").stdout)
        assert activated == {"schemaVersion": 1, "active": "work", "revision": 1}
        work_catalog, errors = helper.scan(configuration, json.loads(preferences.read_text()))
        assert not errors and work_catalog["profile"]["active"] == "work"
        work_plugin = work_catalog["plugins"][0]
        assert work_plugin["enabled"] is True
        assert work_plugin["manifest"]["barWidget"] == {
            "defaultSection": "right", "allowMultiple": False, "order": 17,
        }
        assert work_plugin["settings"] == {
            "globalOnly": 1, "shared": "profile", "profileOnly": 2, "items": [2],
        }
        run_helper("profile", "unset", "work", "stillsuit.example", "shared")
        inherited, _ = helper.scan(configuration, json.loads(preferences.read_text()))
        assert inherited["plugins"][0]["settings"]["shared"] == "global"

        unchanged_state = Path(configuration["activeProfile"]).read_text()
        failed = run_helper("profile", "activate", "missing", check=False)
        assert failed.returncode == 1 and "profile does not exist" in failed.stderr
        assert Path(configuration["activeProfile"]).read_text() == unchanged_state
        run_helper("profile", "activate", "default")
        default_catalog, _ = helper.scan(configuration, json.loads(preferences.read_text()))
        assert default_catalog["profile"]["revision"] == 2
        assert default_catalog["plugins"][0]["enabled"] is False

        run_helper("profile", "create", "same")
        run_helper("profile", "activate", "same")
        same_catalog, _ = helper.scan(configuration, json.loads(preferences.read_text()))
        assert same_catalog["plugins"] == default_catalog["plugins"]
        assert same_catalog["profile"]["active"] == "same"
        assert same_catalog["profile"]["revision"] == 3
        failed = run_helper("profile", "delete", "same", check=False)
        assert failed.returncode == 1 and "cannot delete the active profile" in failed.stderr
        run_helper("profile", "activate", "default")
        run_helper("profile", "delete", "same")

        configuration["requiredPlugins"] = ["stillsuit.example"]
        config_path.write_text(json.dumps(configuration))
        failed = run_helper("disable", "stillsuit.example", check=False)
        assert failed.returncode == 1 and "required plugins cannot be disabled" in failed.stderr
        failed = run_helper("profile", "disable", "work", "stillsuit.example", check=False)
        assert failed.returncode == 1 and "required plugins cannot be disabled" in failed.stderr
        required_catalog, _ = helper.scan(configuration, json.loads(preferences.read_text()))
        assert required_catalog["plugins"][0]["enabled"] is True

        bar_manifest = {
            "schemaVersion": 1,
            "id": "stillsuit.bar",
            "name": "Bar",
            "version": "1.0.0",
            "apiVersion": "1",
            "kinds": ["bar"],
            "entryPoints": {"bar": "Bar.qml"},
            "scope": {"bar": "per-output"},
        }
        seed.write_text(
            json.dumps(
                {
                    "schemaVersion": 1,
                    "selectedBar": "stillsuit.bar",
                    "plugins": [
                        {
                            "manifest": bar_manifest,
                            "packageRoot": str(tracked),
                            "enabled": True,
                            "settings": {"source": "seed", "shared": "seed"},
                        }
                    ],
                }
            )
        )
        configuration["requiredPlugins"] = ["stillsuit.bar"]
        config_path.write_text(json.dumps(configuration))
        run_helper("profile", "set", "work", "stillsuit.bar", "shared", '"profile"')
        run_helper("profile", "set", "work", "stillsuit.bar", "profileOnly", "true")
        run_helper("profile", "activate", "work")
        bar_catalog, errors = helper.scan(
            configuration,
            {
                "stillsuit.bar": {
                    "enabled": False,
                    "settings": {"shared": "global", "globalOnly": True},
                }
            },
        )
        assert not errors
        assert bar_catalog["plugins"][0]["enabled"] is True
        assert bar_catalog["plugins"][0]["settings"] == {
            "source": "seed",
            "shared": "profile",
            "globalOnly": True,
            "profileOnly": True,
        }
        run_helper("profile", "activate", "default")
        default_bar_catalog, errors = helper.scan(
            configuration,
            {"stillsuit.bar": {"settings": {"shared": "global"}}},
        )
        assert not errors
        assert default_bar_catalog["plugins"][0]["settings"] == {
            "source": "seed",
            "shared": "global",
        }

        configuration["requiredPlugins"] = []
        config_path.write_text(json.dumps(configuration))
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
