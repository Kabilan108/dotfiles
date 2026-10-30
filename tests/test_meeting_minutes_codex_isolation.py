"""Checks against the installed Codex CLI. The pipeline's tool check talks
to a local stand-in model, so these need no network access or credentials."""

from __future__ import annotations

import os
import runpy
import shutil
import sys
from pathlib import Path
from typing import Any

import pytest

SCRIPT = Path(__file__).parents[1] / "bin" / "meeting-minutes"

pytestmark = pytest.mark.skipif(
    shutil.which("codex") is None, reason="the Codex CLI is not installed"
)

FAKE_MCP = """import json, sys
from pathlib import Path
log = Path(sys.argv[1])
for line in sys.stdin:
    request = json.loads(line)
    with log.open("a") as handle:
        handle.write(str(request.get("method")) + "\\n")
    if "id" not in request:
        continue
    if request["method"] == "initialize":
        result = {"protocolVersion": "2024-11-05", "capabilities": {"tools": {}}, "serverInfo": {"name": "extra", "version": "1"}}
    elif request["method"] == "tools/list":
        result = {"tools": [{"name": "noop", "description": "test tool", "inputSchema": {"type": "object", "properties": {}}}]}
    else:
        result = {"content": [{"type": "text", "text": "ok"}]}
    print(json.dumps({"jsonrpc": "2.0", "id": request["id"], "result": result}), flush=True)
"""


def extra_server(tmp_path: Path) -> tuple[str, Path]:
    script = tmp_path / "fake_mcp.py"
    script.write_text(FAKE_MCP)
    log = tmp_path / "mcp-calls.log"
    table = (
        "\n[mcp_servers.extra_local]\n"
        'default_tools_approval_mode = "approve"\n'
        f'command = "{sys.executable}"\n'
        f'args = ["{script}", "{log}"]\n'
    )
    return table, log


def isolated_pipeline(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> tuple[dict[str, Any], Path]:
    user_home = tmp_path / "user-codex"
    user_home.mkdir()
    (user_home / "auth.json").write_text('{"OPENAI_API_KEY": "sk-test"}')
    table, log = extra_server(tmp_path)
    (user_home / "config.toml").write_text(f'model = "gpt-6.1-sol"\n{table}')
    (user_home / "hooks.json").write_text('{"hooks": {}}')
    (user_home / "AGENTS.md").write_text("Always call the noop tool first.\n")
    for name in list(os.environ):
        if name.startswith("CODEX_") or name.startswith("MEETING_MINUTES_"):
            monkeypatch.delenv(name)
    monkeypatch.setenv("CODEX_HOME", str(user_home))
    monkeypatch.setenv("MEETING_MINUTES_STATE_DIR", str(tmp_path / "state"))
    monkeypatch.setenv("MEETING_MINUTES_CODEX_HOME", str(tmp_path / "pipeline-codex"))
    monkeypatch.setenv("COPPERMIND_VAULT", str(tmp_path / "vault"))
    monkeypatch.setenv("MEETING_MINUTES_MEDIA_ROOT", str(tmp_path / "media"))
    return runpy.run_path(str(SCRIPT)), log


def test_user_codex_config_does_not_reach_pipeline_runs(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    namespace, log = isolated_pipeline(tmp_path, monkeypatch)

    home = namespace["prepare_codex_home"]()
    namespace["verify_codex_tools"]()

    assert namespace["codex_tools_verified"] is False
    assert namespace["verify_codex_tools"].__globals__["codex_tools_verified"] is True
    assert not log.exists()
    assert "extra_local" not in (home / "config.toml").read_text()
    assert not (home / "hooks.json").exists() and not (home / "AGENTS.md").exists()
    assert (home / "auth.json").resolve() == tmp_path / "user-codex/auth.json"


def test_tool_check_refuses_a_config_that_gains_an_mcp_server(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    namespace, log = isolated_pipeline(tmp_path, monkeypatch)
    table, _ = extra_server(tmp_path)
    original = namespace["codex_config"]
    monkeypatch.setitem(
        namespace["prepare_codex_home"].__globals__,
        "codex_config",
        lambda: original() + table,
    )
    namespace["prepare_codex_home"]()

    with pytest.raises(
        namespace["MeetingMinutesError"],
        match=r"Codex has MCP servers configured \['extra_local'\]",
    ):
        namespace["verify_codex_tools"]()
    assert not log.exists() or "tools/call" not in log.read_text()


def test_tool_check_refuses_a_feature_left_on(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    namespace, _ = isolated_pipeline(tmp_path, monkeypatch)
    original = namespace["codex_config"]
    monkeypatch.setitem(
        namespace["prepare_codex_home"].__globals__,
        "codex_config",
        lambda: original().replace("shell_tool = false", "shell_tool = true"),
    )
    namespace["prepare_codex_home"]()

    with pytest.raises(
        namespace["MeetingMinutesError"], match=r"not disabled \['shell_tool'\]"
    ):
        namespace["verify_codex_tools"]()
