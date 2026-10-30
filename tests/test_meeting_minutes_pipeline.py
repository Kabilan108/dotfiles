from __future__ import annotations

import base64
import json
import os
import re
import runpy
import subprocess
import sys
import threading
import tomllib
from collections.abc import Callable, Iterator
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

import pytest

SCRIPT = Path(__file__).parents[1] / "bin" / "meeting-minutes"
STARTED_EPOCH = 1_791_911_433.0

ROSTER = """# Example — People

- **Ada Lovelace** — Engineering lead; reviews pipeline work.
- **Grace Hopper** (goes by Amazing Grace) — Compiler engineer.
- **Alan Turing / Alonzo Church** — Theory collaborators; proofs.

External / customers:
- *Example Hospital*
    - **Barbara Liskov** (Example MGH) - clinician; data exports.
    - Edsger Dijkstra (Eddie) - researcher; shortest paths.
"""

REGISTRY = """version = 1

[owner]
id = "tony"
name = "Tony Kabilan Okeke"
aliases = ["Tony", "Tony Okeke"]
emails = ["tony@example.com"]
slack = [{ workspace = "example", user_id = "UOWNER0001" }]

[[people]]
id = "ada-lovelace"
name = "Ada Lovelace"
slack = [{ workspace = "example", user_id = "UADA000001" }]
contexts = ["tooling"]

[[people]]
id = "grace-hopper"
name = "Grace Hopper"
contexts = ["tooling"]
"""

TRANSCRIPT: dict[str, Any] = {
    "version": 1,
    "recording_started_at": "2026-10-13T13:10:33-04:00",
    "recording_identity": "identity",
    "duration": 300.0,
    "speakers": ["SPEAKER_00", "SPEAKER_01", "SPEAKER_02", "SPEAKER_03"],
    "text": "",
    "segments": [
        {
            "id": 0,
            "start": 1.0,
            "end": 12.0,
            "speaker": "SPEAKER_00",
            "text": "Hi Ada, the DevFlake worktrees are ready.",
        },
        {
            "id": 1,
            "start": 13.0,
            "end": 40.0,
            "speaker": "SPEAKER_00",
            "text": "Each DevFlake checkout gets its own ports.",
        },
        {
            "id": 2,
            "start": 41.0,
            "end": 90.0,
            "speaker": "SPEAKER_01",
            "text": "Thanks Tony. I will review the DevFlake branch by Friday.",
        },
        {
            "id": 3,
            "start": 91.0,
            "end": 150.0,
            "speaker": "SPEAKER_02",
            "text": "Hospitals want to own their data, so adoption is slow.",
        },
        {"id": 4, "start": 151.0, "end": 152.0, "speaker": "SPEAKER_03", "text": "Mm."},
        {
            "id": 5,
            "start": 160.0,
            "end": 200.0,
            "speaker": "SPEAKER_00",
            "text": "I'll prototype the container next week.",
        },
    ],
}

SPEAKERS = {
    "speakers": [
        {
            "label": "SPEAKER_00",
            "status": "identified",
            "person_id": "tony",
            "name": "Tony Kabilan Okeke",
            "likely": [],
            "confidence": "high",
            "evidence": ["Addressed as Tony at s2"],
        },
        {
            "label": "SPEAKER_01",
            "status": "identified",
            "person_id": "ada-lovelace",
            "name": "Ada Lovelace",
            "likely": [],
            "confidence": "high",
            "evidence": ["SPEAKER_00 addresses them as Ada at s0"],
        },
        {
            "label": "SPEAKER_02",
            "status": "new_person",
            "person_id": "",
            "name": "Margaret Hamilton",
            "likely": [],
            "confidence": "medium",
            "evidence": ["SPEAKER_02 introduces herself as Margaret Hamilton at s3"],
        },
        {
            "label": "SPEAKER_03",
            "status": "identified",
            "person_id": "not-in-registry",
            "name": "SPEAKER_03",
            "likely": ["Grace", "SPEAKER_01"],
            "confidence": "low",
            "evidence": [],
        },
    ]
}

MINUTES = {
    "title": "Dev environment review",
    "summary": "SPEAKER_01 agreed to review the DevFlake branch.",
    "slug": "dev-environment-review",
    "context": "tooling",
    "project": "tooling",
    "calendar_match": 0,
    "attendees": ["SPEAKER_00", "Ada", "Tony"],
    "topics": [
        {
            "title": "DevFlake worktrees",
            "bullets": [
                {"text": "Worktrees are ready.", "citations": ["s0"]},
                {"text": "Ports are per checkout.", "citations": ["s0-s1.1"]},
                {"text": "Needs repair.", "citations": ["s99", "0:01"]},
            ],
            "detail": "SPEAKER_02 said hospitals want to own their data.",
        },
        {"title": "Empty", "bullets": [], "detail": ""},
    ],
    "decisions": [{"text": "Unsupported decision.", "citations": ["s0-s5000"]}],
    "ideas": [
        {"text": "Use a dev container.", "raised_by": "SPEAKER_00", "citations": ["s5"]}
    ],
    "follow_ups": [
        {
            "owner": "Tony Okeke",
            "action": "Prototype the container",
            "timeframe": "next week",
            "citations": ["s5"],
        },
        {
            "owner": "SPEAKER_01",
            "action": "Review the DevFlake branch",
            "timeframe": "by Friday",
            "citations": ["s2"],
        },
    ],
    "visual_mode": "none",
    "visual_candidates": [],
}

REVIEWED = json.loads(json.dumps(MINUTES))
REVIEWED["topics"][0]["bullets"].append(
    {"text": "Hospitals want to own their data, slowing adoption.", "citations": ["s3"]}
)

REPAIR = {
    "repairs": [
        {"item": "topics[0].bullets[2]", "citations": ["s1"]},
        {"item": "decisions[0]", "citations": ["s404"]},
    ]
}

MEET_DOC = """# Notes

Summary: Dev environment review.

## **Meeting Oct 13, 2026 at 13:11 EDT - Transcript**

### **00:00:05** {#00:00:05}

**Tony Okeke:** Hi Ada, the dev flake worktrees are ready for you today.

**Ada Lovelace:** Thanks Tony, I will review the dev flake branch by Friday.
"""


def slack_results(messages: list[dict[str, str]]) -> dict[str, Any]:
    blocks = "".join(
        f"### Result {index} of {len(messages)}\n"
        f"Channel: {message['channel']} (ID: {message['channel_id']})\n"
        f"From: {message['author']} <a@example.com> (ID: {message['author_id']}) \n"
        f"Time: whatever\n"
        f"Message_ts: {message['ts']}\n"
        f"Permalink: [link](https://example.slack.com/archives/{message['channel_id']}/p1)\n"
        f"Text: \n{message['text']}\n\n---\n\n"
        for index, message in enumerate(messages, start=1)
    )
    payload = {
        "results": f"# Search Results\n\n## Messages\n{blocks}",
        "pagination_info": "End of results",
    }
    return {"content": [{"type": "text", "text": json.dumps(payload)}]}


SLACK_MESSAGES = [
    {
        "channel": "DM",
        "channel_id": "D00000001",
        "author": "Ada Lovelace",
        "author_id": "UADA000001",
        "ts": str(STARTED_EPOCH - 90),
        "text": "joining the dev env call",
    },
    {
        "channel": "#random",
        "channel_id": "C9",
        "author": "Ada Lovelace",
        "author_id": "UADA000001",
        "ts": str(STARTED_EPOCH + 3 * 86400),
        "text": "far outside the window",
    },
]

UNNAMED_CALLER = {
    "channel": "DM",
    "channel_id": "D00000001",
    "author": "Katherine Johnson",
    "author_id": "UKJ0000001",
    "ts": str(STARTED_EPOCH - 120),
    "text": "free for a quick call?",
}


def slack_search(arguments: dict[str, Any]) -> dict[str, Any]:
    if arguments["filters"].startswith("in:<#D00000001>"):
        return slack_results([UNNAMED_CALLER, *SLACK_MESSAGES])
    return slack_results(SLACK_MESSAGES)


PATHS = {
    "calendars": "google_calendar.user.tonykabilanokeke.calendar.calendarList.list",
    "events": "google_calendar.user.tonykabilanokeke.calendar.events.list",
    "drive_list": "google_drive.user.tonykabilanokeke.drive.files.list",
    "drive_export": "google_drive.user.tonykabilanokeke.drive.files.export",
    "slack": "slack_mcp.user.moberganalyticsslackmcp.slack_search_public_and_private",
}


def default_handlers() -> dict[str, Callable[[dict[str, Any]], Any]]:
    def events(arguments: dict[str, Any]) -> Any:
        if arguments["calendarId"] == "broken":
            raise RuntimeError("calendar backend error")
        if arguments["calendarId"] != "work":
            return {"items": []}
        return {
            "items": [
                {
                    "summary": "Dev environment review",
                    "start": {"dateTime": "2026-10-13T13:00:00-04:00"},
                    "end": {"dateTime": "2026-10-13T14:00:00-04:00"},
                    "attendees": [
                        {"displayName": "Ada Lovelace"},
                        {"email": "tony@example.com", "self": True},
                        {
                            "displayName": "Declined Person",
                            "responseStatus": "declined",
                        },
                    ],
                }
            ]
        }

    return {
        PATHS["calendars"]: lambda arguments: {
            "items": [
                {"id": "work", "summary": "Work", "selected": True},
                {"id": "hidden", "summary": "Hidden", "selected": False},
            ]
        },
        PATHS["events"]: events,
        PATHS["drive_list"]: lambda arguments: {
            "files": [
                {
                    "id": "doc-0123456789",
                    "name": "Meeting started 2026/10/13 13:11 EDT - Notes by Gemini",
                    "webViewLink": "https://docs.example/d",
                },
                {
                    "id": "doc-other-0123",
                    "name": "Meeting started 2026/10/13 09:00 EDT - Notes by Gemini",
                },
            ]
        },
        PATHS["drive_export"]: lambda arguments: {
            "_tag": "ToolFile",
            "mimeType": "text/markdown",
            "encoding": "base64",
            "data": base64.b64encode(MEET_DOC.encode()).decode(),
        },
        PATHS["slack"]: slack_search,
    }


class FakeExecutor:
    """Executor's MCP endpoint, accepting only `execute` calls of the form
    `return await tools.<path>(<json>);` and recording every call."""

    def __init__(self, handlers: dict[str, Callable[[dict[str, Any]], Any]]) -> None:
        self.handlers = handlers
        self.calls: list[tuple[str, dict[str, Any]]] = []
        self.codes: list[str] = []
        executor = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args: Any) -> None:
                pass

            def do_POST(self) -> None:
                assert self.headers["Authorization"] == "Bearer test-key"
                body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                if "id" not in body:
                    self.send_response(202)
                    self.end_headers()
                    return
                result: dict[str, Any] = {}
                if body["method"] == "tools/call":
                    assert body["params"]["name"] == "execute"
                    result = {
                        "structuredContent": executor.execute(
                            body["params"]["arguments"]["code"]
                        )
                    }
                payload = json.dumps(
                    {"jsonrpc": "2.0", "id": body["id"], "result": result}
                ).encode()
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("mcp-session-id", "session-1")
                self.send_header("Content-Length", str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.url = f"http://127.0.0.1:{self.server.server_address[1]}/mcp"
        threading.Thread(target=self.server.serve_forever, daemon=True).start()

    def execute(self, code: str) -> dict[str, Any]:
        self.codes.append(code)
        match = re.fullmatch(r"return await tools\.([\w.]+)\((\{.*\})\);", code, re.S)
        assert match, code
        path, arguments = match.group(1), json.loads(match.group(2))
        self.calls.append((path, arguments))
        try:
            return {
                "status": "completed",
                "result": {"ok": True, "data": self.handlers[path](arguments)},
            }
        except Exception as error:
            return {
                "status": "completed",
                "result": {
                    "ok": False,
                    "error": {"code": "fake", "message": str(error)},
                },
            }


FAKE_CODEX = r"""#!/usr/bin/env python3
import json, os, sys
from pathlib import Path

args = sys.argv[1:]
fixtures = Path(os.environ["FAKE_CODEX_FIXTURES"])
codex_home = os.environ.get("CODEX_HOME", "")
if args[:2] == ["mcp", "list"]:
    servers = fixtures / "mcp-servers.json"
    print(servers.read_text() if servers.is_file() else "[]")
    sys.exit(0)
if args[:2] == ["features", "list"]:
    import tomllib
    features = tomllib.loads((Path(codex_home) / "config.toml").read_text())["features"]
    for name, value in features.items():
        print(f"{name}  stable  {str(value).lower()}")
    sys.exit(0)
probe = next((arg for arg in args if arg.startswith("model_providers.meeting_minutes_probe=")), "")
if probe:
    import re, urllib.request
    base_url = re.search(r'base_url="([^"]+)"', probe).group(1)
    config = (Path(codex_home) / "config.toml").read_text()
    model = re.search(r'^model = "([^"]+)"', config, re.M).group(1)
    tools_file = fixtures / "tools.json"
    tools = json.loads(tools_file.read_text()) if tools_file.is_file() else [
        {"type": "namespace", "name": "functions", "tools": [
            {"type": "custom", "name": "exec", "description": "".join(
                f"### `{nested}`\n" for nested in (
                    "apply_patch", "list_mcp_resource_templates", "list_mcp_resources",
                    "read_mcp_resource", "clock__curr_time",
                )
            )},
            {"type": "function", "name": "wait"},
            {"type": "function", "name": "request_user_input"},
            {"type": "function", "name": "request_user_input_async"},
        ]}
    ]
    body = json.dumps({"model": model, "input": [{"type": "additional_tools", "tools": tools}]}).encode()
    request = urllib.request.Request(base_url + "/responses", data=body, headers={"Content-Type": "application/json"})
    urllib.request.urlopen(request).read()
    with (fixtures / "probes.jsonl").open("a") as log:
        log.write(json.dumps({"args": args, "codex_home": codex_home, "cwd": os.getcwd()}) + "\n")
    print(json.dumps({"type": "thread.started", "thread_id": "probe"}))
    sys.exit(0)
prompt = sys.stdin.read()
with (fixtures / "calls.jsonl").open("a") as log:
    log.write(json.dumps({"args": args, "prompt": prompt, "codex_home": codex_home, "cwd": os.getcwd()}) + "\n")
schema = json.loads(Path(args[args.index("--output-schema") + 1]).read_text())
output = Path(args[args.index("--output-last-message") + 1])
properties = schema["properties"]
if "speakers" in properties:
    kind = "speakers"
elif "repairs" in properties:
    kind = "repair"
elif "selections" in properties:
    kind = "screenshots"
elif "Review your minutes" in prompt:
    kind = "reviewed"
else:
    kind = "minutes"
fixture = fixtures / f"{kind}.json"
if not fixture.is_file():
    print(f"no {kind} fixture", file=sys.stderr)
    sys.exit(3)
output.write_text(fixture.read_text())
print(json.dumps({"type": "thread.started", "thread_id": "thread-123"}))
if (fixtures / f"{kind}.tool-event").is_file():
    print(json.dumps({"type": "item.completed", "item": {"type": "command_execution"}}))
"""


@pytest.fixture
def executor() -> Iterator[FakeExecutor]:
    fake = FakeExecutor(default_handlers())
    yield fake
    fake.server.shutdown()


def write_fixtures(directory: Path, **fixtures: Any) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    for name, payload in fixtures.items():
        path = directory / f"{name}.json"
        if payload is None:
            path.unlink(missing_ok=True)
        else:
            path.write_text(json.dumps(payload))


def full_fixtures(directory: Path) -> None:
    write_fixtures(
        directory,
        speakers=SPEAKERS,
        minutes=MINUTES,
        reviewed=REVIEWED,
        repair=REPAIR,
    )


def pipeline_env(
    tmp_path: Path, executor: FakeExecutor | None = None
) -> tuple[dict[str, str], Path, Path, Path]:
    vault = tmp_path / "vault"
    media = tmp_path / "media"
    fixtures = tmp_path / "fixtures"
    bin_dir = tmp_path / "bin"
    for directory in (
        vault / "01-logs/meetings",
        vault / "04-projects/example",
        media,
        bin_dir,
    ):
        directory.mkdir(parents=True)
    (vault / "04-projects/example/people.md").write_text(ROSTER)
    (vault / "04-projects/manifest.md").write_text("# Manifest\n")
    (tmp_path / "people.toml").write_text(REGISTRY)
    (tmp_path / "executor-env").write_text("EXECUTOR_API_KEY=test-key\n")
    (tmp_path / "user-codex").mkdir()
    (tmp_path / "user-codex/auth.json").write_text('{"OPENAI_API_KEY": "sk-test"}')
    codex = bin_dir / "codex"
    codex.write_text(FAKE_CODEX)
    codex.chmod(0o755)
    harkctl = bin_dir / "harkctl"
    harkctl.write_text(
        "#!/usr/bin/env bash\n"
        f'printf "%s\\n" "$*" >> {tmp_path}/hark.log\n'
        f"cat >> {tmp_path}/hark.log\n"
    )
    harkctl.chmod(0o755)
    write_fixtures(fixtures)
    env = os.environ.copy()
    env.update(
        {
            "PATH": f"{bin_dir}:{env['PATH']}",
            "COPPERMIND_VAULT": str(vault),
            "MEETING_MINUTES_MEDIA_ROOT": str(media),
            "MEETING_MINUTES_MEDIA_REFERENCE_ROOT": str(tmp_path / "reference"),
            "MEETING_MINUTES_STATE_DIR": str(tmp_path / "state"),
            "MEETING_MINUTES_HARKCTL": str(harkctl),
            "MEETING_MINUTES_PEOPLE_REGISTRY": str(tmp_path / "people.toml"),
            "MEETING_MINUTES_EXECUTOR_KEY_FILE": str(tmp_path / "executor-env"),
            "MEETING_MINUTES_EXECUTOR_URL": executor.url
            if executor
            else "http://127.0.0.1:9/mcp",
            "FAKE_CODEX_FIXTURES": str(fixtures),
            "CODEX_HOME": str(tmp_path / "user-codex"),
            "MEETING_MINUTES_CODEX_HOME": str(tmp_path / "codex-home"),
            "MEETING_MINUTES_CODEX_WORKSPACE": str(tmp_path / "codex-workspace"),
            "MEETING_MINUTES_CODEX_SYSTEM_CONFIG_DIR": str(tmp_path / "etc-codex"),
        }
    )
    env.pop("CREDENTIALS_DIRECTORY", None)
    return env, vault, media, fixtures


def load_script(env: dict[str, str], monkeypatch: pytest.MonkeyPatch) -> dict[str, Any]:
    for name, value in env.items():
        monkeypatch.setenv(name, value)
    monkeypatch.delenv("CREDENTIALS_DIRECTORY", raising=False)
    return runpy.run_path(str(SCRIPT))


def tree_snapshot(root: Path) -> dict[str, bytes]:
    return {
        str(path.relative_to(root)): path.read_bytes()
        for path in sorted(root.rglob("*"))
        if path.is_file()
    }


def calls(fixtures: Path) -> list[dict[str, Any]]:
    log = fixtures / "calls.jsonl"
    if not log.is_file():
        return []
    return [json.loads(line) for line in log.read_text().splitlines()]


def regenerate(
    env: dict[str, str], *args: str, check: bool = True
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "regenerate", *args],
        check=check,
        capture_output=True,
        text=True,
        env=env,
    )


def meeting_note(vault: Path, media: Path) -> Path:
    transcript_path = media / "2026-10-13-tooling-dev-review.json"
    transcript_path.write_text(json.dumps(TRANSCRIPT))
    note = vault / "01-logs/meetings/2026-10-13-tooling-dev-review.md"
    note.write_text(
        f"---\ntranscript: {json.dumps(str(transcript_path))}\n---\n# Old\n"
    )
    return note


def make_run(namespace: dict[str, Any], work: Path, **overrides: Any) -> Any:
    work.mkdir(parents=True, exist_ok=True)
    return namespace["MeetingRun"](
        work=work,
        transcript=overrides.pop("transcript", TRANSCRIPT),
        started_at=STARTED_EPOCH,
        duration=300.0,
        **overrides,
    )


def test_legacy_rosters_seed_a_parseable_registry(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    env, _, _, _ = pipeline_env(tmp_path)
    seeded = subprocess.run(
        [sys.executable, str(SCRIPT), "seed-people"],
        check=True,
        capture_output=True,
        text=True,
        env=env,
    ).stdout
    data = tomllib.loads(seeded)
    people = {person["id"]: person for person in data["people"]}

    assert data["owner"]["id"] == "tony"
    assert set(people) == {
        "ada-lovelace",
        "grace-hopper",
        "alan-turing",
        "alonzo-church",
        "barbara-liskov",
        "edsger-dijkstra",
    }
    assert people["grace-hopper"]["aliases"] == ["Amazing Grace"]
    assert people["alonzo-church"]["role"] == "Theory collaborators; proofs."
    assert people["barbara-liskov"]["org"] == "Example MGH"
    assert people["edsger-dijkstra"]["aliases"] == ["Eddie"]
    assert people["edsger-dijkstra"]["org"] == "Example Hospital"
    assert people["ada-lovelace"]["contexts"] == ["example"]

    namespace = load_script(env, monkeypatch)
    registry = namespace["registry_from_legacy_rosters"]()
    assert namespace["registry_toml"](registry) == seeded


def test_registry_file_wins_and_resolves_aliases(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    env, _, _, _ = pipeline_env(tmp_path)
    (tmp_path / "people.toml").write_text(
        """version = 1
[owner]
id = "tony"
name = "Tony Kabilan Okeke"
aliases = ["Tony"]

[[people]]
id = "ada"
name = "Ada Lovelace"
aliases = ["Countess"]
emails = ["ada@example.com"]
slack = [{ workspace = "example", user_id = "U1" }]

[[people]]
id = "ada-b"
name = "Ada Byron"

[[people]]
id = "grace"
name = "Grace Hopper"
"""
    )
    registry = load_script(env, monkeypatch)["load_registry"]()

    assert registry.lookup("countess").id == "ada"
    assert registry.lookup("Lovelace, Ada").id == "ada"
    assert registry.lookup("ADA@example.com").id == "ada"
    assert registry.lookup("Grace").id == "grace"
    assert registry.lookup("Ada") is None
    assert registry.is_owner("Tony Okeke")
    assert "slack: U1" in registry.prompt_text()


def test_speaker_map_requires_evidence_and_confidence(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    env, _, _, _ = pipeline_env(tmp_path)
    namespace = load_script(env, monkeypatch)
    registry = namespace["load_registry"]()

    def mapped(**overrides: dict[str, Any]) -> dict[str, dict[str, Any]]:
        payload = json.loads(json.dumps(SPEAKERS))
        for speaker in payload["speakers"]:
            speaker.update(overrides.get(speaker["label"], {}))
        return {
            speaker["label"]: speaker
            for speaker in namespace["validate_speaker_map"](
                payload, TRANSCRIPT, registry
            )
        }

    speakers = mapped()
    assert [speaker["display"] for speaker in speakers.values()] == [
        "Tony",
        "Ada Lovelace",
        "Margaret Hamilton",
        "Unknown (likely Grace Hopper)",
    ]
    assert speakers["SPEAKER_01"]["evidence"] == ["Tony addresses them as Ada at s0"]
    assert speakers["SPEAKER_02"]["evidence"] == [
        "Margaret Hamilton introduces herself as Margaret Hamilton at s3"
    ]

    weak = mapped(
        SPEAKER_00={"confidence": "medium"},
        SPEAKER_01={"confidence": "low"},
        SPEAKER_02={"evidence": []},
    )
    assert weak["SPEAKER_00"]["display"] == "Unknown (likely Tony Kabilan Okeke)"
    assert weak["SPEAKER_01"]["display"] == "Unknown (likely Ada Lovelace)"
    assert weak["SPEAKER_02"]["display"] == "Unknown (likely Margaret Hamilton)"

    no_evidence = mapped(SPEAKER_01={"evidence": [], "confidence": "high"})
    assert no_evidence["SPEAKER_01"]["status"] == "unknown"


def test_executor_reads_are_allowlisted_and_json_encoded(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    env, _, _, _ = pipeline_env(tmp_path)
    namespace = load_script(env, monkeypatch)
    code_for = namespace["executor_read_code"]
    error = namespace["MeetingMinutesError"]

    hostile = '"}); await tools.slack_mcp.user.moberganalyticsslackmcp.slack_send_message({"text": "x'
    code = code_for(
        "slack.search", {"filters": "after:2026-10-12", "keywords": [hostile]}
    )
    match = re.fullmatch(r"return await tools\.([\w.]+)\((\{.*\})\);", code, re.S)
    assert match is not None
    assert match.group(1) == PATHS["slack"]
    assert json.loads(match.group(2))["keywords"] == [hostile]
    assert code.count("tools.") == 1 + hostile.count("tools.")
    assert "\u2028" not in code_for("slack.search", {"filters": "\u2028"})

    rejected = [
        ("slack.send", {"filters": "x"}),
        ("slack_send_message", {"text": "x"}),
        ("slack.search", {"filters": "x", "channel_id": "C1"}),
        ("slack.search", {"keywords": ["x"]}),
        ("slack.search", {"filters": "x", "response_format": "concise"}),
        ("slack.search", {"filters": {"$gt": ""}}),
        ("drive.files.export", {"fileId": "abc", "mimeType": "application/pdf"}),
        (
            "calendar.events.list",
            {"calendarId": "x", "timeMin": "a", "timeMax": "b", "q": "x"},
        ),
    ]
    for operation, arguments in rejected:
        with pytest.raises(error):
            code_for(operation, arguments)

    allowed = {spec.path for spec in namespace["EXECUTOR_READ_OPERATIONS"].values()}
    assert allowed == set(PATHS.values())
    assert not any(
        word in path
        for path in allowed
        for word in (
            "send",
            "draft",
            "schedule",
            "upload",
            "create",
            "delete",
            "update",
        )
    )


def test_regenerate_writes_cited_minutes_without_touching_the_vault(
    tmp_path: Path, executor: FakeExecutor
) -> None:
    env, vault, media, fixtures = pipeline_env(tmp_path, executor)
    full_fixtures(fixtures)
    note = meeting_note(vault, media)
    before = tree_snapshot(vault)
    out = tmp_path / "eval"

    summary = json.loads(regenerate(env, note.stem, "--out", str(out)).stdout)

    assert tree_snapshot(vault) == before
    assert not (tmp_path / "state").exists()
    assert summary["calendar_status"] == "matched"
    assert summary["speakers"]["SPEAKER_02"] == "Margaret Hamilton"
    assert summary["uncited"] == 1

    rendered = (out / f"{note.stem}.md").read_text()
    result = json.loads((out / f"{note.stem}.minutes.json").read_text())
    assert "SPEAKER_" not in rendered
    assert result["schema_version"] == 3
    assert result["calendar"]["matched_event"]["attendees"] == [
        "Ada Lovelace",
        "tony@example.com",
    ]
    assert result["calendar"]["errors"] == []
    meet = result["context"]["meet"]
    assert meet["status"] == "found" and meet["file_id"] == "doc-0123456789"
    assert [speaker["name"] for speaker in meet["speakers"]] == [
        "Tony Okeke",
        "Ada Lovelace",
    ]
    assert [message["text"] for message in result["context"]["slack"]["messages"]] == [
        "free for a quick call?",
        "joining the dev env call",
    ]
    assert result["coverage_review"]["final_bullets"] == 4
    assert result["citation_repair"] == {
        "status": "completed",
        "requested": 2,
        "repaired": 1,
        "unresolved": 1,
        "unresolved_items": ["decisions[0]"],
    }
    bullets = result["minutes"]["topics"][0]["bullets"]
    assert bullets[1]["anchors"] == ["s0", "s1", "s1.1"]
    assert bullets[1]["citations"] == [{"start": 1.0, "end": 40.0}]
    assert bullets[2]["anchors"] == ["s1"]
    assert result["minutes"]["attendees"] == [
        "Tony Kabilan Okeke",
        "Ada Lovelace",
        "Margaret Hamilton",
    ]

    assert (
        'calendar_status: matched\ncalendar_event: "Dev environment review"' in rendered
    )
    assert "calendar_errors: []\n" in rendered
    assert "- Worktrees are ready. [0:01–0:12]\n" in rendered
    assert "- Ports are per checkout. [0:01–0:40]\n" in rendered
    assert "- Needs repair. [0:13–0:26]\n" in rendered
    assert "- Unsupported decision. [no transcript citation]\n" in rendered
    assert "<summary>Discussion detail</summary>\n\nMargaret Hamilton said" in rendered
    assert "- **Tony** — Use a dev container. [2:40–3:00]\n" in rendered
    assert "- [ ] Prototype the container (next week) [2:40–3:00]\n" in rendered
    assert (
        "- **Ada Lovelace** — Review the DevFlake branch (by Friday) [0:41–1:05]\n"
        in rendered
    )
    assert rendered.count("- [ ]") == 1

    invocations = calls(fixtures)
    assert [call["args"][1] == "resume" for call in invocations] == [
        False,
        True,
        True,
        True,
    ]
    codex_home = tmp_path / "codex-home"
    config = tomllib.loads((codex_home / "config.toml").read_text())
    assert config["approval_policy"] == "never"
    assert config["sandbox_mode"] == "read-only"
    assert config["agents"] == {"enabled": False}
    assert config["features"]["apps"] is False
    assert config["features"]["shell_tool"] is False
    assert config["features"]["hooks"] is False
    assert not {"mcp_servers", "projects", "profiles", "hooks"} & set(config)
    assert (codex_home / "auth.json").is_symlink()
    assert (codex_home / "auth.json").resolve() == tmp_path / "user-codex/auth.json"
    for call in invocations:
        assert call["codex_home"] == str(codex_home)
        assert "--ignore-rules" in call["args"]
    probes = [
        json.loads(line)
        for line in (fixtures / "probes.jsonl").read_text().splitlines()
    ]
    assert [probe["codex_home"] for probe in probes] == [str(codex_home)]
    assert "s2 [0:41] SPEAKER_01: Thanks Tony." in invocations[0]["prompt"]

    paths = {path for path, _ in executor.calls}
    assert paths == set(PATHS.values())
    slack_filters = [
        arguments["filters"]
        for path, arguments in executor.calls
        if path == PATHS["slack"]
    ]
    assert "from:<@UOWNER0001> after:2026-10-12 before:2026-10-15" in slack_filters
    assert "from:<@UADA000001> after:2026-10-12 before:2026-10-15" in slack_filters
    assert slack_filters[-1] == "in:<#D00000001> after:2026-10-12 before:2026-10-15"
    for code in executor.codes:
        assert "Hi Ada" not in code and "Hospitals" not in code

    second = regenerate(env, note.stem, "--out", str(out))
    assert json.loads(second.stdout)["calendar_status"] == "matched"
    assert len(calls(fixtures)) == len(invocations)


def test_regenerate_rejects_changed_inputs_until_fresh(
    tmp_path: Path, executor: FakeExecutor
) -> None:
    env, vault, media, fixtures = pipeline_env(tmp_path, executor)
    full_fixtures(fixtures)
    note = meeting_note(vault, media)
    out = tmp_path / "eval"
    regenerate(env, note.stem, "--out", str(out))

    changed = json.loads(json.dumps(TRANSCRIPT))
    changed["segments"][0]["text"] = "Hi Ada, the worktrees moved."
    alternate = tmp_path / "alternate.json"
    alternate.write_text(json.dumps(changed))
    refused = regenerate(
        env, note.stem, "--transcript", str(alternate), "--out", str(out), check=False
    )
    assert refused.returncode == 1
    assert "different inputs (transcript)" in refused.stderr

    (tmp_path / "people.toml").write_text(
        REGISTRY.replace("Grace Hopper", "Grace Brewster Hopper")
    )
    refused = regenerate(env, note.stem, "--out", str(out), check=False)
    assert "registry" in refused.stderr

    first_calls = len(calls(fixtures))
    regenerate(
        env, note.stem, "--transcript", str(alternate), "--out", str(out), "--fresh"
    )
    assert len(calls(fixtures)) == first_calls + 4
    assert json.loads((out / "inputs.json").read_text())["inputs"]["transcript"] != ""

    reused = tmp_path / "reuse"
    regenerate(env, note.stem, "--out", str(reused), "--reuse-context", str(out))
    executor_calls = len(executor.calls)
    (out / "context.json").write_text(json.dumps({"meet": {}, "slack": {}}))
    refused = regenerate(
        env, note.stem, "--out", str(reused), "--reuse-context", str(out), check=False
    )
    assert "reused_context" in refused.stderr
    assert len(executor.calls) == executor_calls


def test_regenerate_refuses_vault_output(tmp_path: Path) -> None:
    env, vault, media, _ = pipeline_env(tmp_path)
    (media / "meeting.json").write_text(json.dumps(TRANSCRIPT))
    completed = regenerate(
        env, str(media / "meeting.json"), "--out", str(vault / "x"), check=False
    )
    assert completed.returncode == 1
    assert "outside the vault" in completed.stderr
    assert not (vault / "x").exists()


@pytest.mark.parametrize(
    ("missing", "message"),
    [
        ("speakers", "speaker identification failed"),
        ("minutes", "minutes-draft failed"),
    ],
)
def test_required_codex_stage_failures_fail_the_run(
    tmp_path: Path, executor: FakeExecutor, missing: str, message: str
) -> None:
    env, vault, media, fixtures = pipeline_env(tmp_path, executor)
    full_fixtures(fixtures)
    write_fixtures(fixtures, **{missing: None})
    note = meeting_note(vault, media)
    completed = regenerate(env, note.stem, "--out", str(tmp_path / "eval"), check=False)
    assert completed.returncode == 1
    assert message in completed.stderr


def test_optional_codex_stage_failures_keep_the_draft_and_mark_citations(
    tmp_path: Path, executor: FakeExecutor
) -> None:
    env, vault, media, fixtures = pipeline_env(tmp_path, executor)
    full_fixtures(fixtures)
    write_fixtures(fixtures, reviewed=None, repair=None)
    note = meeting_note(vault, media)
    out = tmp_path / "eval"

    regenerate(env, note.stem, "--out", str(out))

    result = json.loads((out / f"{note.stem}.minutes.json").read_text())
    assert result["coverage_review"]["status"] == "failed"
    assert result["citation_repair"]["status"] == "failed"
    assert result["citation_repair"]["unresolved"] == 2
    rendered = (out / f"{note.stem}.md").read_text()
    assert "- Needs repair. [no transcript citation]\n" in rendered
    assert len(result["minutes"]["topics"][0]["bullets"]) == 3


def test_codex_tool_use_fails_the_stage(tmp_path: Path, executor: FakeExecutor) -> None:
    env, vault, media, fixtures = pipeline_env(tmp_path, executor)
    full_fixtures(fixtures)
    (fixtures / "speakers.tool-event").write_text("")
    note = meeting_note(vault, media)
    completed = regenerate(env, note.stem, "--out", str(tmp_path / "eval"), check=False)
    assert completed.returncode == 1
    assert "Codex used tools despite the lockdown" in completed.stderr


def test_partial_calendar_failure_keeps_candidates_and_notifies(
    tmp_path: Path, executor: FakeExecutor, monkeypatch: pytest.MonkeyPatch
) -> None:
    executor.handlers[PATHS["calendars"]] = lambda arguments: {
        "items": [
            {"id": "work", "summary": "Work", "selected": True},
            {"id": "broken", "summary": "Broken", "selected": True},
        ]
    }
    env, _, _, _ = pipeline_env(tmp_path, executor)
    env["MEETING_MINUTES_CALENDAR_SOURCES"] = "google,outlook"
    namespace = load_script(env, monkeypatch)
    run = make_run(namespace, tmp_path / "work")
    client, error = namespace["connect_executor"]()
    assert error == ""

    calendar = namespace["lookup_calendar"](run, client, error)

    assert calendar["status"] == "available"
    assert [source["status"] for source in calendar["sources"]] == ["partial", "failed"]
    assert [candidate["title"] for candidate in calendar["candidates"]] == [
        "Dev environment review"
    ]
    assert calendar["errors"][0].startswith(
        "google: partial (Broken: Executor calendar.events.list failed"
    )
    assert calendar["errors"][1] == "outlook: failed (unknown calendar source)"
    assert not (run.work / "calendar-google.json").exists()

    job: dict[str, Any] = {
        "job_id": "b" * 32,
        "title": "Standup",
        "calendar_enrichment": {},
    }
    monkeypatch.setitem(
        namespace["notify_calendar_failure"].__globals__, "save_job", lambda job: None
    )
    namespace["notify_calendar_failure"](job, calendar)
    namespace["notify_calendar_failure"](job, calendar)
    hark = (tmp_path / "hark.log").read_text()
    assert hark.count(f"meeting-minutes:{'b' * 32}:calendar") == 1
    assert "Meeting calendar lookup incomplete" in hark
    assert "Standup was written with partial calendar data" in hark

    result = {
        "minutes": {
            **MINUTES,
            "attendees": [],
            "topics": [],
            "decisions": [],
            "ideas": [],
            "follow_ups": [],
        },
        "calendar": {**calendar, "status": "no_match", "matched_event": None},
        "speakers": [],
    }
    note = namespace["render_note"](
        result, namespace["NoteArtifacts"]("2026-10-13", "r", "t", "m"), []
    )
    assert 'calendar_errors:\n  - "google: partial (Broken:' in note


def test_missing_executor_key_marks_calendar_and_context_unavailable(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    env, _, _, _ = pipeline_env(tmp_path)
    (tmp_path / "executor-env").unlink()
    namespace = load_script(env, monkeypatch)
    run = make_run(namespace, tmp_path / "work")
    client, error = namespace["connect_executor"]()
    assert client is None and "No Executor API key" in error

    calendar = namespace["lookup_calendar"](run, client, error)
    context = namespace["gather_context"](
        run, calendar, namespace["load_registry"](), client, error
    )

    assert calendar["status"] == "unavailable"
    assert "No Executor API key" in calendar["errors"][0]
    assert context["meet"]["status"] == context["slack"]["status"] == "unavailable"


def test_stale_screenshot_review_is_not_reused(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    env, _, _, fixtures = pipeline_env(tmp_path)
    write_fixtures(
        fixtures,
        screenshots={
            "selections": [{"candidate_index": 0, "frame_index": 0, "caption": "first"}]
        },
    )
    namespace = load_script(env, monkeypatch)
    run = make_run(namespace, tmp_path / "work")
    run.session_path.write_text("thread-123\n")
    frame_bytes = {"value": b"frame-a"}

    def fake_frames(run: Any, candidates: list[dict[str, Any]]) -> list[dict[str, Any]]:
        frame = run.work / "frame.png"
        frame.write_bytes(frame_bytes["value"])
        return [
            {
                **candidate,
                "frames": [
                    {"path": frame, "timestamp_seconds": candidate["timestamp_seconds"]}
                ],
            }
            for candidate in candidates
        ]

    monkeypatch.setitem(
        namespace["select_screenshots"].__globals__,
        "extract_screenshot_frames",
        fake_frames,
    )
    minutes = {
        "visual_mode": "ordinary",
        "topics": [
            {"title": "T", "bullets": [{"text": "Code on screen"}], "detail": ""}
        ],
        "visual_candidates": [
            {
                "timestamp_seconds": 10.0,
                "topic_index": 0,
                "bullet_index": 0,
                "reason": "code",
            }
        ],
    }

    first, _ = namespace["select_screenshots"](run, minutes)
    again, _ = namespace["select_screenshots"](run, minutes)
    assert first[0]["caption"] == again[0]["caption"] == "first"
    assert len(calls(fixtures)) == 1

    write_fixtures(
        fixtures,
        screenshots={
            "selections": [
                {"candidate_index": 0, "frame_index": 0, "caption": "second"}
            ]
        },
    )
    frame_bytes["value"] = b"frame-b"
    changed, enrichment = namespace["select_screenshots"](run, minutes)
    assert enrichment["status"] == "completed"
    assert changed[0]["caption"] == "second"
    assert len(calls(fixtures)) == 2

    assets = Path(env["COPPERMIND_VAULT"]) / "assets"
    assets.mkdir()
    (assets / "stem-01.png").write_bytes(b"old frame")
    (assets / "stem-02.png").write_bytes(b"stale extra")
    (assets / "stem-2-01.png").write_bytes(b"another meeting")
    globals_ = namespace["publish_screenshots"].__globals__
    monkeypatch.setitem(globals_, "save_job", lambda job: None)
    published = namespace["publish_screenshots"]({}, "stem", changed)
    assert [item["asset_name"] for item in published] == ["stem-01.png"]
    assert (assets / "stem-01.png").read_bytes() == b"frame-b"
    assert not (assets / "stem-02.png").exists()
    assert (assets / "stem-2-01.png").exists()


def test_finalize_writes_minutes_data_and_only_proposes_named_new_people(
    tmp_path: Path, executor: FakeExecutor, monkeypatch: pytest.MonkeyPatch
) -> None:
    env, vault, media, fixtures = pipeline_env(tmp_path, executor)
    full_fixtures(fixtures)
    (vault / "01-logs/2026-w42.md").write_text("### Tue, Oct 13\n\n- work\n")
    namespace = load_script(env, monkeypatch)
    run = make_run(namespace, tmp_path / "work")
    result = namespace["run_minutes_pipeline"](run)
    recording = media / ".inbox/job.mp4"
    recording.parent.mkdir()
    recording.write_bytes(b"video")
    transcript_path = tmp_path / "work/transcript.json"
    transcript_path.write_text(json.dumps(TRANSCRIPT))
    job = {
        "job_id": "c" * 32,
        "recording_started_at": STARTED_EPOCH,
        "recording_identity": "identity",
        "recording_path": str(recording),
        "codex_session": "host:thread-123",
    }
    globals_ = namespace["finalize_artifacts"].__globals__
    monkeypatch.setitem(globals_, "save_job", lambda job: None)
    monkeypatch.setitem(globals_, "update_status", lambda job, **kwargs: None)

    namespace["finalize_artifacts"](job, result, transcript_path, [])

    stem = "2026-10-13-tooling-dev-environment-review"
    note = (vault / f"01-logs/meetings/{stem}.md").read_text()
    data = json.loads((media / f"{stem}.minutes.json").read_text())
    reference = tmp_path / "reference"
    assert f'recording: "{reference}/{stem}.mp4"' in note
    assert f'transcript: "{reference}/{stem}.json"' in note
    assert f'minutes_data: "{reference}/{stem}.minutes.json"' in note
    assert (media / f"{stem}.mp4").read_bytes() == b"video"
    assert data["artifacts"]["note"].endswith(f"{stem}.md")
    proposals = sorted((vault / "04-projects/_pipeline/proposals").iterdir())
    assert [path.name for path in proposals] == ["meeting-person-margaret-hamilton.md"]
    proposal = proposals[0].read_text()
    assert (
        "- Margaret Hamilton introduces herself as Margaret Hamilton at s3" in proposal
    )
    assert f'target: "{tmp_path}/people.toml"' in proposal
    assert "SPEAKER_" not in note + proposal
    assert (
        f"[[01-logs/meetings/{stem}|Dev environment review]]"
        in (vault / "01-logs/2026-w42.md").read_text()
    )


def test_anchors_merge_short_turns_and_cap_span(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    env, _, _, _ = pipeline_env(tmp_path)
    namespace = load_script(env, monkeypatch)
    segments = [
        {
            "id": index,
            "start": index * 5.0,
            "end": index * 5.0 + 4.5,
            "speaker": "SPEAKER_00",
            "text": f"part {index}",
        }
        for index in range(12)
    ]
    anchors, warnings = namespace["build_anchors"]({"segments": segments}, 60.0)
    assert warnings == []
    assert [anchor["id"] for anchor in anchors] == ["s0", "s5", "s10"]
    assert all(anchor["end"] - anchor["start"] <= 25 for anchor in anchors)
    index = {anchor["id"]: position for position, anchor in enumerate(anchors)}
    resolved, dropped = namespace["resolve_citations"](
        ["s0-s10", "s5", "s99", "9:59"], anchors, index
    )
    assert resolved == ["s0", "s5", "s10"] and dropped == 2
    assert namespace["citation_ranges"](["s0", "s10"], anchors, index) == [
        {"start": 0.0, "end": 24.5},
        {"start": 50.0, "end": 59.5},
    ]


def test_long_segments_split_into_bounded_anchors(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    env, _, _, _ = pipeline_env(tmp_path)
    namespace = load_script(env, monkeypatch)
    build = namespace["build_anchors"]
    words = [f"w{index}" for index in range(20)]
    long_turn = {
        "id": 7,
        "start": 10.0,
        "end": 110.0,
        "speaker": "SPEAKER_00",
        "text": " ".join(words),
    }

    anchors, warnings = build({"segments": [long_turn]}, 600.0)
    assert warnings == []
    assert [anchor["id"] for anchor in anchors] == ["s7", "s7.1", "s7.2", "s7.3"]
    assert [(anchor["start"], anchor["end"]) for anchor in anchors] == [
        (10.0, 35.0),
        (35.0, 60.0),
        (60.0, 85.0),
        (85.0, 110.0),
    ]
    assert " ".join(anchor["text"] for anchor in anchors) == " ".join(words)

    timed = {
        **long_turn,
        "words": [
            {"word": word, "start": 10.0 + index * 5, "end": 14.0 + index * 5}
            for index, word in enumerate(words)
        ],
    }
    anchors, _ = build({"segments": [timed]}, 600.0)
    assert all(anchor["end"] - anchor["start"] <= 25 for anchor in anchors)
    assert anchors[0]["text"].startswith("w0 w1") and anchors[0]["end"] <= 35.0
    assert anchors[1]["text"].split()[0] == "w5"
    assert anchors[-1]["end"] == 110.0
    assert " ".join(anchor["text"] for anchor in anchors) == " ".join(words)


def test_invalid_and_out_of_range_timestamps_are_bounded(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    env, _, _, _ = pipeline_env(tmp_path)
    namespace = load_script(env, monkeypatch)
    segments = [
        {
            "id": 0,
            "start": 50.0,
            "end": 500.0,
            "speaker": "SPEAKER_00",
            "text": "runs past the end",
        },
        {
            "id": 1,
            "start": 70.0,
            "end": 80.0,
            "speaker": "SPEAKER_00",
            "text": "after the end",
        },
        {
            "id": 2,
            "start": "soon",
            "end": 5.0,
            "speaker": "SPEAKER_00",
            "text": "not a number",
        },
        {
            "id": 3,
            "start": float("nan"),
            "end": 5.0,
            "speaker": "SPEAKER_00",
            "text": "not finite",
        },
        {
            "id": 4,
            "start": -1.0,
            "end": 3.0,
            "speaker": "SPEAKER_00",
            "text": "negative",
        },
        {
            "id": 5,
            "start": 9.0,
            "end": 4.0,
            "speaker": "SPEAKER_00",
            "text": "reversed",
        },
        {"id": 6, "start": 1.0, "speaker": "SPEAKER_00", "text": "no end"},
    ]
    run = make_run(namespace, tmp_path / "work", transcript={"segments": segments})
    run.duration = 60.0

    anchors, warnings = run.anchor_result
    assert [(anchor["id"], anchor["start"], anchor["end"]) for anchor in anchors] == [
        ("s0", 50.0, 60.0)
    ]
    assert warnings == [
        "segment s1 skipped: starts at 70.0s, after the recording ends at 60.0s",
        "segment s2 skipped: non-numeric timestamps",
        "segment s3 skipped: non-finite timestamps",
        "segment s4 skipped: negative timestamps",
        "segment s5 skipped: reversed timestamps",
        "segment s6 skipped: non-numeric timestamps",
    ]
    index = {anchor["id"]: position for position, anchor in enumerate(anchors)}
    resolved, _ = namespace["resolve_citations"](["s0"], anchors, index)
    assert namespace["citation_ranges"](resolved, anchors, index) == [
        {"start": 50.0, "end": 60.0}
    ]

    fallback = make_run(
        namespace, tmp_path / "fallback", transcript={"segments": segments[:1]}
    )
    fallback.duration = 0.0
    assert fallback.anchors[0]["start"] == 50.0
    assert fallback.anchors[-1]["end"] <= 500.0
    assert all(anchor["end"] - anchor["start"] <= 25 for anchor in fallback.anchors)


def test_tool_check_fails_closed_before_any_meeting_content(
    tmp_path: Path, executor: FakeExecutor
) -> None:
    env, vault, media, fixtures = pipeline_env(tmp_path, executor)
    full_fixtures(fixtures)
    (fixtures / "tools.json").write_text(
        json.dumps(
            [
                {
                    "type": "namespace",
                    "name": "functions",
                    "tools": [{"type": "function", "name": "wait"}],
                },
                {
                    "type": "namespace",
                    "name": "mcp__extra_local",
                    "tools": [{"type": "function", "name": "noop"}],
                },
            ]
        )
    )
    note = meeting_note(vault, media)

    completed = regenerate(env, note.stem, "--out", str(tmp_path / "eval"), check=False)

    assert completed.returncode == 1
    assert "unexpected tools ['namespace:mcp__extra_local', 'noop']" in completed.stderr
    assert calls(fixtures) == []


def test_tool_check_refuses_configured_mcp_servers(
    tmp_path: Path, executor: FakeExecutor
) -> None:
    env, vault, media, fixtures = pipeline_env(tmp_path, executor)
    full_fixtures(fixtures)
    (fixtures / "mcp-servers.json").write_text(
        json.dumps([{"name": "extra_local", "enabled": True}])
    )
    note = meeting_note(vault, media)

    completed = regenerate(env, note.stem, "--out", str(tmp_path / "eval"), check=False)

    assert completed.returncode == 1
    assert "Codex has MCP servers configured ['extra_local']" in completed.stderr
    assert calls(fixtures) == []
    assert not (fixtures / "probes.jsonl").exists()


def test_out_of_order_word_timestamps_fall_back_to_even_splits(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    env, _, _, _ = pipeline_env(tmp_path)
    namespace = load_script(env, monkeypatch)
    segment = {
        "id": 0,
        "start": 0.0,
        "end": 110.0,
        "speaker": "SPEAKER_00",
        "text": "a b c d e",
        "words": [
            {"word": word, "start": start, "end": start + 1}
            for word, start in zip("abcde", (0.0, 40.0, 10.0, 70.0, 100.0), strict=True)
        ],
    }

    anchors, warnings = namespace["build_anchors"]({"segments": [segment]}, 600.0)

    assert warnings == ["segment s0 split evenly: word timestamps out of order"]
    assert all(0 < anchor["end"] - anchor["start"] <= 25 for anchor in anchors)
    assert [anchor["start"] for anchor in anchors] == sorted(
        anchor["start"] for anchor in anchors
    )
    index = {anchor["id"]: position for position, anchor in enumerate(anchors)}
    for anchor in anchors:
        for citation in namespace["citation_ranges"]([anchor["id"]], anchors, index):
            assert 0 < citation["end"] - citation["start"] <= 25


def test_zero_length_segments_are_dropped_with_a_warning(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    env, _, _, _ = pipeline_env(tmp_path)
    namespace = load_script(env, monkeypatch)
    segments = [
        {"id": 0, "start": 5.0, "end": 5.0, "speaker": "SPEAKER_00", "text": "instant"},
        {"id": 1, "start": 6.0, "end": 8.0, "speaker": "SPEAKER_00", "text": "spoken"},
    ]

    anchors, warnings = namespace["build_anchors"]({"segments": segments}, 60.0)

    assert [anchor["id"] for anchor in anchors] == ["s1"]
    assert warnings == ["segment s0 skipped: zero-length"]


def test_duration_fallback_ignores_unparseable_timestamps(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    env, _, _, _ = pipeline_env(tmp_path)
    namespace = load_script(env, monkeypatch)
    transcript = {
        "duration": "unknown",
        "segments": [
            {
                "id": 0,
                "start": 1.0,
                "end": "soon",
                "speaker": "SPEAKER_00",
                "text": "later",
            },
            {"id": 1, "start": 2.0, "end": 9.0, "speaker": "SPEAKER_00", "text": "now"},
            {
                "id": 2,
                "start": 3.0,
                "end": float("inf"),
                "speaker": "SPEAKER_00",
                "text": "never",
            },
        ],
    }

    assert namespace["transcript_duration"](transcript) == 9.0
    assert (
        namespace["transcript_duration"]({"segments": transcript["segments"][:1]})
        == 0.0
    )
    run = make_run(namespace, tmp_path / "work", transcript=transcript)
    run.duration = 0.0
    anchors, warnings = run.anchor_result
    assert [(anchor["id"], anchor["end"]) for anchor in anchors] == [("s1", 9.0)]
    assert warnings == [
        "segment s0 skipped: non-numeric timestamps",
        "segment s2 skipped: non-finite timestamps",
    ]


def test_citation_ranges_are_capped_at_three_lines_and_sixty_seconds(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    env, _, _, _ = pipeline_env(tmp_path)
    namespace = load_script(env, monkeypatch)
    resolve, ranges = namespace["resolve_citations"], namespace["citation_ranges"]
    short = [
        {
            "id": f"s{index}",
            "start": index * 10.0,
            "end": index * 10.0 + 9,
            "speaker": "A",
            "text": "x",
        }
        for index in range(6)
    ]
    index = {anchor["id"]: position for position, anchor in enumerate(short)}

    assert resolve(["s0-s2"], short, index) == (["s0", "s1", "s2"], 0)
    assert resolve(["s0-s3"], short, index) == ([], 1)
    singles, _ = resolve(["s0", "s1", "s2", "s3", "s4"], short, index)
    assert ranges(singles, short, index) == [
        {"start": 0.0, "end": 29.0},
        {"start": 30.0, "end": 49.0},
    ]

    long = [
        {
            "id": f"s{index}",
            "start": index * 25.0,
            "end": index * 25.0 + 24,
            "speaker": "A",
            "text": "x",
        }
        for index in range(4)
    ]
    long_index = {anchor["id"]: position for position, anchor in enumerate(long)}
    assert resolve(["s0-s1"], long, long_index) == (["s0", "s1"], 0)
    assert resolve(["s0-s2"], long, long_index) == ([], 1)
    assert ranges(["s0", "s1", "s2"], long, long_index) == [
        {"start": 0.0, "end": 49.0},
        {"start": 50.0, "end": 74.0},
    ]
    assert "at most 3 consecutive lines and 60 seconds" in namespace["CITATION_RULE"]
    assert namespace["CITATION_RULE"] in namespace["CITATION_REPAIR_PROMPT"]


def test_tool_check_requires_the_exact_tool_set(
    tmp_path: Path, executor: FakeExecutor
) -> None:
    env, vault, media, fixtures = pipeline_env(tmp_path, executor)
    full_fixtures(fixtures)
    note = meeting_note(vault, media)
    (fixtures / "tools.json").write_text(
        json.dumps(
            [
                {
                    "type": "namespace",
                    "name": "functions",
                    "tools": [
                        {
                            "type": "custom",
                            "name": "exec",
                            "description": "### `apply_patch`\n",
                        },
                        {"type": "function", "name": "wait"},
                        {"type": "function", "name": "request_user_input"},
                        {"type": "function", "name": "request_user_input_async"},
                    ],
                }
            ]
        )
    )
    missing = regenerate(
        env, note.stem, "--out", str(tmp_path / "missing"), check=False
    )
    assert missing.returncode == 1
    assert (
        "lacks expected tools ['clock__curr_time', 'list_mcp_resource_templates'"
        in missing.stderr
    )

    (fixtures / "tools.json").write_text(
        json.dumps([{"type": "mcp", "server_label": "extra", "server_url": "http://x"}])
    )
    unfamiliar = regenerate(
        env, note.stem, "--out", str(tmp_path / "unfamiliar"), check=False
    )
    assert unfamiliar.returncode == 1
    assert "unfamiliar request encoding" in unfamiliar.stderr
    assert calls(fixtures) == []


def test_tool_parser_rejects_unfamiliar_request_shapes(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    env, _, _, _ = pipeline_env(tmp_path)
    namespace = load_script(env, monkeypatch)
    parse, error = namespace["codex_tool_names"], namespace["MeetingMinutesError"]
    function = {"type": "function", "name": "wait"}
    assert parse({"tools": [function], "input": []}) == {"wait"}
    for request in (
        {"tools": [{"type": "web_search"}], "input": []},
        {"tools": {"wait": function}, "input": []},
        {"input": [{"type": "function_call_output", "output": "x"}]},
        {"input": [{"type": "message", "tools": [function]}]},
        {
            "input": [
                {
                    "type": "additional_tools",
                    "tools": [{"type": "namespace", "name": "x"}],
                }
            ]
        },
        {
            "input": [
                {
                    "type": "additional_tools",
                    "tools": [
                        {
                            "type": "namespace",
                            "name": "x",
                            "tools": [{"type": "local_shell"}],
                        }
                    ],
                }
            ]
        },
        {"tools": []},
    ):
        with pytest.raises(error, match="unfamiliar request encoding"):
            parse(request)


def test_every_codex_call_runs_from_the_empty_workspace(
    tmp_path: Path, executor: FakeExecutor
) -> None:
    env, vault, media, fixtures = pipeline_env(tmp_path, executor)
    full_fixtures(fixtures)
    note = meeting_note(vault, media)
    env["OPENAI_API_KEY"] = "sk-should-not-pass"
    env["CODEX_SQLITE_HOME"] = str(tmp_path / "elsewhere")
    elsewhere = tmp_path / "caller"
    elsewhere.mkdir()

    subprocess.run(
        [
            sys.executable,
            str(SCRIPT),
            "regenerate",
            note.stem,
            "--out",
            str(tmp_path / "eval"),
        ],
        check=True,
        capture_output=True,
        text=True,
        env=env,
        cwd=elsewhere,
    )

    workspace = str(tmp_path / "codex-workspace")
    invocations = calls(fixtures)
    probes = [
        json.loads(line)
        for line in (fixtures / "probes.jsonl").read_text().splitlines()
    ]
    assert [call["args"][1] == "resume" for call in invocations] == [
        False,
        True,
        True,
        True,
    ]
    assert {call["cwd"] for call in [*invocations, *probes]} == {workspace}
    assert not any(
        workspace_entry for workspace_entry in (tmp_path / "codex-workspace").iterdir()
    )


def test_codex_environment_keeps_only_the_pipeline_home(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    env, _, _, _ = pipeline_env(tmp_path)
    env.update(
        {
            "OPENAI_API_KEY": "sk-x",
            "OPENAI_BASE_URL": "http://x",
            "CODEX_SQLITE_HOME": "/x",
        }
    )
    namespace = load_script(env, monkeypatch)

    environment = namespace["codex_environment"]()

    assert not [name for name in environment if name.startswith("OPENAI_")]
    assert [name for name in environment if name.startswith("CODEX_")] == ["CODEX_HOME"]
    assert environment["CODEX_HOME"] == str(tmp_path / "codex-home")
    assert not [
        name for name in environment if name.startswith("MEETING_MINUTES_EXECUTOR")
    ]


def test_pipeline_home_shares_the_login_and_its_lock(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    env, _, _, _ = pipeline_env(tmp_path)
    namespace = load_script(env, monkeypatch)
    error = namespace["MeetingMinutesError"]
    user, home = tmp_path / "user-codex", tmp_path / "codex-home"
    assert not (user / "auth.lock").exists()

    namespace["prepare_codex_home"]()

    for name in ("auth.json", "auth.lock"):
        assert (home / name).is_symlink()
        assert os.readlink(home / name) == str(user / name)
        assert (home / name).stat().st_ino == (user / name).stat().st_ino
    assert (user / "auth.lock").stat().st_mode & 0o777 == 0o600

    (home / "auth.lock").unlink()
    (home / "auth.lock").write_text("")
    with pytest.raises(error, match="auth.lock is a regular file"):
        namespace["prepare_codex_home"]()

    (home / "auth.lock").unlink()
    (home / "auth.lock").symlink_to(tmp_path / "other.lock")
    with pytest.raises(error, match="points to"):
        namespace["prepare_codex_home"]()
    assert (user / "auth.lock").exists() and not (tmp_path / "other.lock").exists()

    (home / "auth.lock").unlink()
    (home / "auth.json").unlink()
    (home / "auth.json").write_text('{"OPENAI_API_KEY": "sk-copy"}')
    with pytest.raises(error, match="auth.json is a regular file"):
        namespace["prepare_codex_home"]()
    assert (home / "auth.json").read_text() == '{"OPENAI_API_KEY": "sk-copy"}'


@pytest.mark.parametrize("layer", ["system", "ancestor", "workspace"])
def test_codex_config_outside_the_pipeline_home_stops_the_run(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, layer: str
) -> None:
    env, _, _, _ = pipeline_env(tmp_path)
    if layer == "system":
        (tmp_path / "etc-codex").mkdir()
        (tmp_path / "etc-codex/managed_config.toml").write_text("")
        expected = "etc-codex/managed_config.toml"
    elif layer == "ancestor":
        (tmp_path / ".codex").mkdir()
        (tmp_path / ".codex/config.toml").write_text("")
        expected = ".codex/config.toml"
    else:
        (tmp_path / "codex-workspace").mkdir()
        (tmp_path / "codex-workspace/AGENTS.md").write_text("use tools")
        expected = "(not empty)"
    namespace = load_script(env, monkeypatch)

    with pytest.raises(
        namespace["MeetingMinutesError"], match="outside the pipeline home"
    ) as raised:
        namespace["prepare_codex_home"]()
    assert expected in str(raised.value)
