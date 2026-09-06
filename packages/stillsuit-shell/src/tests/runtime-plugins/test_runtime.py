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
from typing import Any


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
        plugin = root / "plugins" / "example"
        plugin.mkdir(parents=True)
        manifest = {
            "schemaVersion": 1, "id": "stillsuit.example", "name": "Example",
            "version": "1.0.0", "apiVersion": "1", "kinds": ["bar-widget"],
            "entryPoints": {"barWidget": "Widget.qml"}, "scope": {"barWidget": "per-output"},
            "barWidget": {"defaultSection": "right", "allowMultiple": False},
        }
        (plugin / "manifest.json").write_text(json.dumps(manifest))

        def write_widget(label: str) -> None:
            (plugin / "Widget.qml").write_text(
                'import QtQuick\nimport Stillsuit.Ui\nShellBarCluster {\n'
                'required property var context\nrequired property string outputId\n'
                f'theme: context.theme\nlabel: "{label}"\n}}\n'
            )

        write_widget("first")
        seed = root / "seed.json"
        seed.write_text('{"schemaVersion":1,"selectedBar":"stillsuit.missing","plugins":[]}')
        config = root / "discovery.json"
        config.write_text(json.dumps({"seed": str(seed), "roots": [str(plugin.parent)],
            "state": str(root / "state"), "core": str(package / "src"),
            "schema": str(package / "schemas/manifest.v1.json"),
            "preferences": str(root / "preferences.json")}))
        helper = root / "helper"
        helper.write_text(f"#!{sys.executable}\nimport runpy\nrunpy.run_path({str(package / 'bin/stillsuit-plugins')!r}, run_name='__main__')\n")
        helper.chmod(0o700)
        environment = dict(os.environ)
        environment.pop("DBUS_SESSION_BUS_ADDRESS", None)
        environment.pop("WAYLAND_DISPLAY", None)
        for variable, folder in {"HOME": "home", "XDG_CONFIG_HOME": "config",
            "XDG_STATE_HOME": "state", "XDG_DATA_HOME": "data",
            "XDG_CACHE_HOME": "cache", "XDG_RUNTIME_DIR": "runtime"}.items():
            (root / folder).mkdir(exist_ok=True, mode=0o700)
            environment[variable] = str(root / folder)
        environment.update(QT_QPA_PLATFORM="offscreen", QML_IMPORT_PATH=str(root / "qml"),
            STILLSUIT_PLUGIN_RUNTIME_CONFIG=str(config), STILLSUIT_PLUGIN_HELPER=str(helper))
        with (root / "shell.log").open("w+") as log:
            process = subprocess.Popen(["quickshell", "--no-color", "-p", str(source)],
                env=environment, stdout=log, stderr=log, start_new_session=True)
            try:
                def wait_for(predicate: Callable[[dict[str, Any]], bool]) -> None:
                    deadline = time.monotonic() + 10
                    while time.monotonic() < deadline:
                        response = subprocess.run(["quickshell", "ipc", "--pid", str(process.pid),
                            "call", "runtime-plugin-test", "inspect"], env=environment,
                            text=True, capture_output=True, timeout=2, check=False)
                        if response.returncode == 0:
                            state = json.loads(response.stdout)
                            if predicate(state):
                                return
                        if process.poll() is not None:
                            break
                        time.sleep(0.1)
                    log.flush()
                    raise AssertionError((root / "shell.log").read_text())

                wait_for(lambda state: state.get("rendered") == ["first"])
                write_widget("second")
                wait_for(lambda state: state.get("rendered") == ["second"])
                subprocess.run([str(helper), "--config", str(config), "disable", "stillsuit.example"],
                    env=environment, check=True)
                wait_for(lambda state: state["exists"] and not state["enabled"] and state["rendered"] == [])
                subprocess.run([str(helper), "--config", str(config), "enable", "stillsuit.example"],
                    env=environment, check=True)
                wait_for(lambda state: state.get("rendered") == ["second"])
                (plugin / "manifest.json").write_text("{")
                wait_for(lambda state: state["ready"] and not state["exists"] and state["rendered"] == [])
                (plugin / "manifest.json").write_text(json.dumps(manifest))
                wait_for(lambda state: state.get("rendered") == ["second"])
                def ipc(method: str) -> str:
                    return subprocess.run(["quickshell", "ipc", "--pid", str(process.pid),
                        "call", "runtime-plugin-test", method], env=environment,
                        text=True, capture_output=True, timeout=2, check=True).stdout.strip()
                assert ipc("rescan") == "watching"
                assert ipc("unload") == "ok"
                wait_for(lambda state: state["rendered"] == [])
                assert ipc("reload") == "ok"
                wait_for(lambda state: state["rendered"] == ["second"])
                assert process.poll() is None
            finally:
                os.killpg(process.pid, signal.SIGTERM)
                process.wait(timeout=5)
    print("runtime edit, named UI import, disable/enable, malformed-plugin recovery without restart: ok")


if __name__ == "__main__":
    main()
