from __future__ import annotations

import json
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from collections.abc import Callable
from pathlib import Path
from typing import Any, TextIO


class RuntimeShell:
    def __init__(self, source: Path, environment: dict[str, str], log_path: Path) -> None:
        self.source = source
        self.environment = environment
        self.log_path = log_path
        self.process: subprocess.Popen[str] | None = None
        self.log: TextIO | None = None

    def start(self) -> None:
        self.log = self.log_path.open("a+")
        self.process = subprocess.Popen(
            ["quickshell", "--no-color", "-p", str(self.source)],
            env=self.environment,
            stdout=self.log,
            stderr=self.log,
            start_new_session=True,
            text=True,
        )

    def stop(self) -> None:
        if self.process is not None and self.process.poll() is None:
            os.killpg(self.process.pid, signal.SIGTERM)
            self.process.wait(timeout=5)
        if self.log is not None:
            self.log.close()
        self.process = None
        self.log = None

    def ipc(self, method: str) -> str:
        if self.process is None:
            raise AssertionError("runtime shell is not running")
        return subprocess.run(
            [
                "quickshell",
                "ipc",
                "--pid",
                str(self.process.pid),
                "call",
                "runtime-plugin-test",
                method,
            ],
            env=self.environment,
            text=True,
            capture_output=True,
            timeout=2,
            check=True,
        ).stdout.strip()

    def inspect(self) -> dict[str, Any]:
        return json.loads(self.ipc("inspect"))

    def wait_for(self, predicate: Callable[[dict[str, Any]], bool]) -> dict[str, Any]:
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            try:
                state = self.inspect()
                if predicate(state):
                    return state
            except (json.JSONDecodeError, subprocess.SubprocessError):
                pass
            if self.process is not None and self.process.poll() is not None:
                break
            time.sleep(0.1)
        if self.log is not None:
            self.log.flush()
        raise AssertionError(self.log_path.read_text())


def write_widget(plugin: Path, label_expression: str) -> None:
    (plugin / "Widget.qml").write_text(
        "import QtQuick\nimport Stillsuit.Ui\nShellBarCluster {\n"
        "    required property var context\n"
        "    required property string outputId\n"
        "    theme: context.theme\n"
        f"    label: {label_expression}\n"
        "}\n"
    )


def run_helper(
    helper: Path,
    config: Path,
    environment: dict[str, str],
    *arguments: str,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(helper), "--config", str(config), *arguments],
        env=environment,
        text=True,
        capture_output=True,
        timeout=5,
        check=check,
    )


def main() -> None:
    package = Path(__file__).resolve().parents[3]
    with tempfile.TemporaryDirectory(prefix="stillsuit-runtime-test-") as temporary:
        root = Path(temporary)
        source = root / "shell"
        shutil.copytree(package / "src", source)
        shutil.copyfile(Path(__file__).with_name("fixture-shell.qml"), source / "shell.qml")
        exports = root / "qml" / "Stillsuit"
        exports.mkdir(parents=True)
        (exports / "Ui").symlink_to(package / "src/ui")

        plugins = root / "plugins"
        example = plugins / "example"
        example.mkdir(parents=True)
        example_manifest = {
            "schemaVersion": 1,
            "id": "stillsuit.example",
            "name": "Example",
            "version": "1.0.0",
            "apiVersion": "1",
            "kinds": ["bar-widget"],
            "entryPoints": {"barWidget": "Widget.qml"},
            "scope": {"barWidget": "per-output"},
            "barWidget": {"defaultSection": "right", "allowMultiple": False},
        }
        (example / "manifest.json").write_text(json.dumps(example_manifest))
        write_widget(example, 'String(context.settings.label || "missing")')

        work_only = plugins / "work-only"
        work_only.mkdir()
        work_manifest = {
            "schemaVersion": 1,
            "id": "stillsuit.work-only",
            "name": "Work only",
            "version": "1.0.0",
            "apiVersion": "1",
            "kinds": ["service", "bar-widget"],
            "entryPoints": {"service": "Service.qml", "barWidget": "Widget.qml"},
            "scope": {"service": "global", "barWidget": "per-output"},
            "barWidget": {"defaultSection": "right", "allowMultiple": False},
        }
        (work_only / "manifest.json").write_text(json.dumps(work_manifest))
        (work_only / "Service.qml").write_text(
            "import QtQuick\nQtObject {\n"
            "    required property var context\n"
            '    readonly property string label: String(context.settings.label || "work-only")\n'
            "}\n"
        )
        (work_only / "Widget.qml").write_text(
            "import QtQuick\nimport Stillsuit.Ui\nShellBarCluster {\n"
            "    required property var context\n"
            "    required property string outputId\n"
            "    required property var service\n"
            "    theme: context.theme\n"
            "    label: service.label\n"
            "}\n"
        )

        bar_manifest = {
            "schemaVersion": 1,
            "id": "stillsuit.test-bar",
            "name": "Test bar",
            "version": "1.0.0",
            "apiVersion": "1",
            "kinds": ["bar"],
            "entryPoints": {"bar": "TestBar.qml"},
            "scope": {"bar": "per-output"},
        }

        seed = root / "seed.json"
        seed.write_text(
            json.dumps(
                {
                    "schemaVersion": 1,
                    "selectedBar": "stillsuit.test-bar",
                    "plugins": [
                        {
                            "manifest": bar_manifest,
                            "packageRoot": str(source / "tests/runtime-plugins"),
                            "enabled": True,
                            "settings": {},
                        },
                        {
                            "manifest": example_manifest,
                            "packageRoot": str(example),
                            "enabled": True,
                            "settings": {"label": "base"},
                        },
                        {
                            "manifest": work_manifest,
                            "packageRoot": str(work_only),
                            "enabled": False,
                            "settings": {"label": "base-work"},
                        },
                    ],
                }
            )
        )
        profiles = root / "profiles.json"
        profile_document = {
            "schemaVersion": 1,
            "profiles": {
                "same": {
                    "name": "Same",
                    "description": "Same effective plugins as default",
                    "plugins": {},
                },
                "work": {
                    "name": "Work",
                    "description": "Work plugins",
                    "plugins": {
                        "stillsuit.example": {"settings": {"label": "work"}},
                        "stillsuit.work-only": {
                            "enabled": True,
                            "settings": {"label": "work-service"},
                        },
                    },
                },
            },
        }
        profiles.write_text(json.dumps(profile_document))
        active_profile = root / "active-profile.json"
        preferences = root / "preferences.json"
        config = root / "discovery.json"
        config.write_text(
            json.dumps(
                {
                    "seed": str(seed),
                    "roots": [str(plugins)],
                    "state": str(root / "state"),
                    "core": str(package / "src"),
                    "schema": str(package / "schemas/manifest.v1.json"),
                    "preferences": str(preferences),
                    "profiles": str(profiles),
                    "activeProfile": str(active_profile),
                    "requiredPlugins": [],
                }
            )
        )
        helper = root / "helper"
        helper.write_text(
            f"#!{sys.executable}\nimport runpy\n"
            f"runpy.run_path({str(package / 'bin/stillsuit-plugins')!r}, run_name='__main__')\n"
        )
        helper.chmod(0o700)

        environment = dict(os.environ)
        environment.pop("DBUS_SESSION_BUS_ADDRESS", None)
        environment.pop("WAYLAND_DISPLAY", None)
        for variable, folder in {
            "HOME": "home",
            "XDG_CONFIG_HOME": "config",
            "XDG_STATE_HOME": "state-home",
            "XDG_DATA_HOME": "data",
            "XDG_CACHE_HOME": "cache",
            "XDG_RUNTIME_DIR": "runtime",
        }.items():
            (root / folder).mkdir(exist_ok=True, mode=0o700)
            environment[variable] = str(root / folder)
        environment.update(
            QT_QPA_PLATFORM="offscreen",
            QML_IMPORT_PATH=str(root / "qml"),
            STILLSUIT_PLUGIN_RUNTIME_CONFIG=str(config),
            STILLSUIT_PLUGIN_HELPER=str(helper),
        )

        shell = RuntimeShell(source, environment, root / "shell.log")
        try:
            shell.start()
            initial = shell.wait_for(
                lambda state: state.get("ready")
                and state.get("activeProfile") == "default"
                and state.get("activeBarId") == "stillsuit.test-bar"
                and state.get("rendered") == ["base"]
                and state.get("workServiceState") == "unloaded"
                and state.get("serviceCount") == 0
            )
            initial_revision = initial["profileRevision"]

            write_widget(example, 'String(context.settings.label || "missing") + "-edited"')
            shell.wait_for(lambda state: state.get("rendered") == ["base-edited"])

            run_helper(helper, config, environment, "disable", "stillsuit.example")
            shell.wait_for(
                lambda state: state.get("exists")
                and not state.get("enabled")
                and state.get("rendered") == []
            )
            run_helper(helper, config, environment, "enable", "stillsuit.example")
            shell.wait_for(lambda state: state.get("rendered") == ["base-edited"])

            (example / "manifest.json").write_text("{")
            shell.wait_for(
                lambda state: state.get("ready")
                and not state.get("exists")
                and state.get("rendered") == []
            )
            (example / "manifest.json").write_text(json.dumps(example_manifest))
            shell.wait_for(lambda state: state.get("rendered") == ["base-edited"])
            assert shell.ipc("rescan") == "watching"
            assert shell.ipc("unload") == "ok"
            shell.wait_for(lambda state: state.get("rendered") == [])
            assert shell.ipc("reload") == "ok"
            shell.wait_for(lambda state: state.get("rendered") == ["base-edited"])

            run_helper(helper, config, environment, "profile", "activate", "work")
            work = shell.wait_for(
                lambda state: state.get("ready")
                and state.get("activeProfile") == "work"
                and set(state.get("rendered", [])) == {"work-edited", "work-service"}
                and state.get("settings", {}).get("label") == "work"
                and state.get("workServiceState") == "loaded"
                and state.get("workServiceLabel") == "work-service"
                and state.get("serviceCount") == 1
            )
            assert work["profileRevision"] > initial_revision

            run_helper(helper, config, environment, "profile", "activate", "default")
            default = shell.wait_for(
                lambda state: state.get("ready")
                and state.get("activeProfile") == "default"
                and state.get("rendered") == ["base-edited"]
                and state.get("workServiceState") == "unloaded"
                and state.get("workServiceLabel") == ""
                and state.get("serviceCount") == 0
            )

            identical_revision = default["profileRevision"]
            run_helper(helper, config, environment, "profile", "activate", "same")
            same = shell.wait_for(
                lambda state: state.get("ready")
                and state.get("activeProfile") == "same"
                and state.get("rendered") == ["base-edited"]
            )
            assert same["profileRevision"] > identical_revision

            assert shell.ipc("unloadBar") == "ok"
            shell.wait_for(
                lambda state: state.get("barRuntimeDisabled") is True
                and state.get("fallbackActive") is True
            )
            run_helper(helper, config, environment, "profile", "activate", "default")
            shell.wait_for(
                lambda state: state.get("activeProfile") == "default"
                and state.get("barRuntimeDisabled") is False
                and state.get("activeBarId") == "stillsuit.test-bar"
                and state.get("fallbackActive") is False
            )
            assert shell.ipc("unload") == "ok"
            shell.wait_for(
                lambda state: state.get("runtimeDisabled") is True
                and state.get("rendered") == []
            )
            run_helper(helper, config, environment, "profile", "activate", "work")
            shell.wait_for(
                lambda state: state.get("activeProfile") == "work"
                and state.get("runtimeDisabled") is False
                and set(state.get("rendered", [])) == {"work-edited", "work-service"}
            )

            run_helper(helper, config, environment, "profile", "activate", "default")
            stable = shell.wait_for(lambda state: state.get("activeProfile") == "default")
            unknown = run_helper(
                helper,
                config,
                environment,
                "profile",
                "activate",
                "unknown",
                check=False,
            )
            assert unknown.returncode != 0
            assert shell.wait_for(
                lambda state: state.get("activeProfile") == "default"
            )["profileRevision"] == stable["profileRevision"]

            profiles.write_text("{")
            malformed = run_helper(
                helper,
                config,
                environment,
                "profile",
                "activate",
                "work",
                check=False,
            )
            assert malformed.returncode != 0
            time.sleep(1.2)
            assert shell.inspect()["activeProfile"] == "default"
            assert shell.process is not None and shell.process.poll() is None
            profiles.write_text(json.dumps(profile_document))

            run_helper(helper, config, environment, "profile", "activate", "work")
            run_helper(helper, config, environment, "profile", "activate", "default")
            rapid_revision = json.loads(active_profile.read_text())["revision"]
            shell.wait_for(
                lambda state: state.get("ready")
                and state.get("activeProfile") == "default"
                and state.get("profileRevision") == rapid_revision
                and state.get("rendered") == ["base-edited"]
                and state.get("workServiceState") == "unloaded"
            )

            run_helper(helper, config, environment, "profile", "activate", "work")
            persisted = shell.wait_for(
                lambda state: state.get("ready")
                and state.get("activeProfile") == "work"
                and state.get("workServiceState") == "loaded"
            )
            persisted_revision = persisted["profileRevision"]
            shell.stop()
            shell.start()
            shell.wait_for(
                lambda state: state.get("ready")
                and state.get("activeProfile") == "work"
                and state.get("profileRevision") == persisted_revision
                and set(state.get("rendered", [])) == {"work-edited", "work-service"}
                and state.get("workServiceState") == "loaded"
                and state.get("serviceCount") == 1
            )
        finally:
            shell.stop()
    print(
        "runtime profile switching, settings, teardown, identity, validation, "
        "last-write-wins and persistence without restart: ok"
    )


if __name__ == "__main__":
    main()
