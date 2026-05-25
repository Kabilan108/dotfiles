from __future__ import annotations

import json
import shutil
import subprocess
from collections.abc import Sequence
from typing import Any, cast


TOOL_PACKAGES = {
    "dotool": "dotool",
    "grim": "grim",
    "jq": "jq",
    "niri": "niri",
    "slurp": "slurp",
    "wtype": "wtype",
}


def run(args: Sequence[str], *, text: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, check=True, text=text, capture_output=True)


def run_tool(args: Sequence[str], *, text: bool = True) -> subprocess.CompletedProcess[str]:
    if not args:
        raise ValueError("missing command")

    tool = args[0]
    if shutil.which(tool):
        return run(args, text=text)

    package = TOOL_PACKAGES.get(tool)
    if package and shutil.which("nix-shell"):
        quoted = " ".join(subprocess.list2cmdline([arg]) for arg in args)
        return run(["nix-shell", "-p", package, "--run", quoted], text=text)

    raise SystemExit(f"missing required tool: {tool}")


def niri_json(command: str) -> Any:
    result = run_tool(["niri", "msg", "-j", command])
    return json.loads(result.stdout)


def niri_action(action: str, args: Sequence[str] = ()) -> str:
    result = run_tool(["niri", "msg", "action", action, *args])
    return result.stdout


def windows() -> list[dict[str, object]]:
    value = niri_json("windows")
    if not isinstance(value, list):
        raise SystemExit("niri windows did not return a list")
    return cast(list[dict[str, object]], value)


def focused_window_id() -> int | None:
    focused = niri_json("focused-window")
    if not isinstance(focused, dict):
        return None
    window_id = cast(dict[str, object], focused).get("id")
    return window_id if isinstance(window_id, int) else None
