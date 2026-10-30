from __future__ import annotations

import json
import os
import runpy
import subprocess
import sys
import tomllib
from pathlib import Path
from typing import Any

import pytest

SCRIPT = Path(__file__).parents[1] / "bin" / "meeting-minutes"

ROSTER = """# Example — People

- **Ada Lovelace** — Engineering lead; reviews pipeline work.
- **Grace Hopper** (goes by Amazing Grace) — Compiler engineer.
- **Alan Turing / Alonzo Church** — Theory collaborators; proofs.

External / customers:
- *Example Hospital*
    - **Barbara Liskov** (Example MGH) - clinician; data exports.
    - Edsger Dijkstra (Eddie) - researcher; shortest paths.
"""

STARTED_AT = "2026-10-13T13:10:33-04:00"

TRANSCRIPT: dict[str, Any] = {
    "version": 1,
    "recording_started_at": STARTED_AT,
    "recording_identity": "identity",
    "duration": 300.0,
    "speakers": ["SPEAKER_00", "SPEAKER_01", "SPEAKER_02", "SPEAKER_03"],
    "text": "",
    "segments": [
        {
            "id": 0,
            "start": 1.0,
            "end": 40.0,
            "speaker": "SPEAKER_00",
            "text": "Hi Ada, the DevFlake worktrees are ready.",
        },
        {
            "id": 1,
            "start": 41.0,
            "end": 90.0,
            "speaker": "SPEAKER_01",
            "text": "Thanks Tony. I will review the DevFlake branch by Friday.",
        },
        {
            "id": 2,
            "start": 91.0,
            "end": 150.0,
            "speaker": "SPEAKER_02",
            "text": "Hospitals want to own their data, so DevFlake adoption is slow.",
        },
        {"id": 3, "start": 151.0, "end": 152.0, "speaker": "SPEAKER_03", "text": "Mm."},
        {
            "id": 4,
            "start": 160.0,
            "end": 200.0,
            "speaker": "SPEAKER_00",
            "text": "I'll prototype the container next week.",
        },
    ],
}

CALENDAR = {
    "status": "available",
    "candidates": [
        {
            "title": "Dev environment review",
            "start": "2026-10-13T13:00:00-04:00",
            "end": "2026-10-13T14:00:00-04:00",
            "attendees": ["Ada Lovelace", "Tony Okeke"],
            "calendar": "Work",
        }
    ],
}

CONTEXT = {
    "meet": {
        "status": "not_found",
        "title": "",
        "file_id": "",
        "url": "",
        "notes": "",
        "speakers": [],
        "error": "",
    },
    "slack": {
        "status": "found",
        "searches": ["from:<@U1> on:2026-10-13"],
        "messages": [
            {
                "channel": "dev",
                "author": "Ada Lovelace",
                "timestamp": "2026-10-13T13:05:00-04:00",
                "text": "joining the dev env call",
                "permalink": "https://example.slack.com/archives/C1/p1",
            }
        ],
        "error": "",
    },
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
            "evidence": ["Addressed as Tony at [0:41]"],
        },
        {
            "label": "SPEAKER_01",
            "status": "identified",
            "person_id": "ada-lovelace",
            "name": "Ada Lovelace",
            "likely": [],
            "confidence": "high",
            "evidence": ["Addressed as Ada at [0:01]"],
        },
        {
            "label": "SPEAKER_02",
            "status": "new_person",
            "person_id": "",
            "name": "Margaret Hamilton",
            "likely": [],
            "confidence": "medium",
            "evidence": ["Introduces herself as Margaret Hamilton at [1:31]"],
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
                {
                    "text": "Worktrees are ready.",
                    "citations": [{"start": "0:01", "end": "0:40"}],
                },
                {
                    "text": "Bogus timing.",
                    "citations": [{"start": "59:00", "end": "59:30"}],
                },
            ],
            "detail": "SPEAKER_02 said hospitals want to own their data.",
        },
        {"title": "Empty", "bullets": [], "detail": ""},
    ],
    "decisions": [],
    "ideas": [
        {
            "text": "Use a dev container.",
            "raised_by": "SPEAKER_00",
            "citations": [{"start": "2:40", "end": "3:20"}],
        }
    ],
    "follow_ups": [
        {
            "owner": "Tony Okeke",
            "action": "Prototype the container",
            "timeframe": "next week",
            "citations": [{"start": "2:40", "end": "3:20"}],
        },
        {
            "owner": "SPEAKER_01",
            "action": "Review the DevFlake branch",
            "timeframe": "by Friday",
            "citations": [{"start": "0:41", "end": "1:30"}],
        },
    ],
    "visual_mode": "none",
    "visual_candidates": [],
}

REVIEWED = json.loads(json.dumps(MINUTES))
REVIEWED["topics"][0]["bullets"].append(
    {
        "text": "Hospitals want to own their data, slowing adoption.",
        "citations": [{"start": "1:31", "end": "2:30"}],
    }
)

FAKE_CODEX = r"""#!/usr/bin/env python3
import json, os, sys
from pathlib import Path

args = sys.argv[1:]
prompt = sys.stdin.read()
fixtures = Path(os.environ["FAKE_CODEX_FIXTURES"])
with (fixtures / "calls.jsonl").open("a") as log:
    log.write(json.dumps({"args": args, "prompt": prompt}) + "\n")
schema = json.loads(Path(args[args.index("--output-schema") + 1]).read_text())
output = Path(args[args.index("--output-last-message") + 1])
properties = schema["properties"]
if "candidates" in properties:
    kind = "calendar"
elif "meet" in properties:
    kind = "context"
elif "speakers" in properties:
    kind = "speakers"
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
"""


def write_fixtures(directory: Path, **fixtures: Any) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    for name, payload in fixtures.items():
        (directory / f"{name}.json").write_text(json.dumps(payload))


def pipeline_env(tmp_path: Path) -> tuple[dict[str, str], Path, Path, Path]:
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
            "FAKE_CODEX_FIXTURES": str(fixtures),
        }
    )
    return env, vault, media, fixtures


def load_script(env: dict[str, str], monkeypatch: pytest.MonkeyPatch) -> dict[str, Any]:
    for name, value in env.items():
        monkeypatch.setenv(name, value)
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
    registry_path = tmp_path / "people.toml"
    registry_path.write_text(
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
    env["MEETING_MINUTES_PEOPLE_REGISTRY"] = str(registry_path)
    registry = load_script(env, monkeypatch)["load_registry"]()

    assert registry.lookup("countess").id == "ada"
    assert registry.lookup("Lovelace, Ada").id == "ada"
    assert registry.lookup("ADA@example.com").id == "ada"
    assert registry.lookup("Grace").id == "grace"
    assert registry.lookup("Ada") is None
    assert registry.is_owner("Tony Okeke")
    assert "slack: U1" in registry.prompt_text()


def test_speaker_map_covers_every_label_and_degrades_weak_ids(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    env, _, _, _ = pipeline_env(tmp_path)
    namespace = load_script(env, monkeypatch)
    registry = namespace["load_registry"]()
    payload = json.loads(json.dumps(SPEAKERS))
    payload["speakers"] = [
        speaker for speaker in payload["speakers"] if speaker["label"] != "SPEAKER_01"
    ]
    payload["speakers"][1]["evidence"] = []

    speakers = {
        speaker["label"]: speaker
        for speaker in namespace["validate_speaker_map"](payload, TRANSCRIPT, registry)
    }

    assert list(speakers) == ["SPEAKER_00", "SPEAKER_01", "SPEAKER_02", "SPEAKER_03"]
    assert speakers["SPEAKER_00"]["display"] == "Tony"
    assert speakers["SPEAKER_01"]["display"] == "Unknown speaker"
    assert speakers["SPEAKER_02"]["status"] == "unknown"
    assert speakers["SPEAKER_03"]["status"] == "unknown"
    assert speakers["SPEAKER_03"]["display"] == "Unknown (likely Grace Hopper)"


def test_regenerate_writes_structured_minutes_without_touching_the_vault(
    tmp_path: Path,
) -> None:
    env, vault, media, fixtures = pipeline_env(tmp_path)
    write_fixtures(
        fixtures,
        calendar=CALENDAR,
        context=CONTEXT,
        speakers=SPEAKERS,
        minutes=MINUTES,
        reviewed=REVIEWED,
    )
    transcript_path = media / "2026-10-13-tooling-dev-review.json"
    transcript_path.write_text(json.dumps(TRANSCRIPT))
    note = vault / "01-logs/meetings/2026-10-13-tooling-dev-review.md"
    note.write_text(
        f"---\ntranscript: {json.dumps(str(transcript_path))}\n---\n# Old\n"
    )
    before = tree_snapshot(vault)
    out = tmp_path / "eval"

    completed = subprocess.run(
        [sys.executable, str(SCRIPT), "regenerate", note.stem, "--out", str(out)],
        check=True,
        capture_output=True,
        text=True,
        env=env,
    )

    assert tree_snapshot(vault) == before
    assert not (tmp_path / "state").exists()
    summary = json.loads(completed.stdout)
    assert summary["calendar_status"] == "matched"
    assert summary["speakers"]["SPEAKER_02"] == "Margaret Hamilton"

    rendered = (out / f"{note.stem}.md").read_text()
    result = json.loads((out / f"{note.stem}.minutes.json").read_text())
    assert "SPEAKER_" not in rendered
    assert result["schema_version"] == 2
    assert result["context"]["slack"]["messages"][0]["author"] == "Ada Lovelace"
    assert result["calendar"]["matched_event"]["title"] == "Dev environment review"
    assert result["coverage_review"] == {
        "status": "completed",
        "draft_bullets": 2,
        "final_bullets": 3,
    }
    assert result["minutes"]["attendees"] == [
        "Tony Kabilan Okeke",
        "Ada Lovelace",
        "Margaret Hamilton",
    ]
    assert result["minutes"]["topics"][0]["bullets"][1]["citations"] == []
    assert any(
        "dropped 1 citation" in warning for warning in result["validation"]["warnings"]
    )
    assert len(result["minutes"]["topics"]) == 1

    assert "calendar_status: matched\n" in rendered
    assert 'calendar_event: "Dev environment review"\n' in rendered
    assert "- Worktrees are ready. [0:01–0:40]\n" in rendered
    assert "<summary>Discussion detail</summary>\n\nMargaret Hamilton said" in rendered
    assert (
        "## ideas raised\n\n- **Tony** — Use a dev container. [2:40–3:20]\n" in rendered
    )
    assert "- [ ] Prototype the container (next week) [2:40–3:20]\n" in rendered
    assert (
        "- **Ada Lovelace** — Review the DevFlake branch (by Friday) [0:41–1:30]\n"
        in rendered
    )
    assert rendered.count("- [ ]") == 1
    assert "## decisions\n\n- None\n" in rendered

    invocations = calls(fixtures)
    speaker_call = next(
        call
        for call in invocations
        if "Identifying" in call["prompt"]
        or "identifies the speakers" in call["prompt"]
    )
    assert "mcp_servers.executor.enabled=false" in speaker_call["args"]
    context_call = next(
        call for call in invocations if "gather read-only context" in call["prompt"]
    )
    assert "Hi Ada" not in context_call["prompt"]
    assert "DevFlake" in context_call["prompt"]
    assert sum("resume" in call["args"] for call in invocations) == 2

    second = subprocess.run(
        [sys.executable, str(SCRIPT), "regenerate", note.stem, "--out", str(out)],
        check=True,
        capture_output=True,
        text=True,
        env=env,
    )
    assert json.loads(second.stdout)["calendar_status"] == "matched"
    assert len(calls(fixtures)) == len(invocations)


def test_regenerate_refuses_vault_output(tmp_path: Path) -> None:
    env, vault, media, _ = pipeline_env(tmp_path)
    (media / "meeting.json").write_text(json.dumps(TRANSCRIPT))
    completed = subprocess.run(
        [
            sys.executable,
            str(SCRIPT),
            "regenerate",
            str(media / "meeting.json"),
            "--out",
            str(vault / "x"),
        ],
        capture_output=True,
        text=True,
        env=env,
    )
    assert completed.returncode == 1
    assert "outside the vault" in completed.stderr
    assert not (vault / "x").exists()


def test_calendar_failure_is_recorded_and_notified(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    env, _, _, _ = pipeline_env(tmp_path)
    namespace = load_script(env, monkeypatch)
    run = namespace["MeetingRun"](
        work=tmp_path / "work",
        transcript=TRANSCRIPT,
        started_at=1_791_911_433.0,
        duration=300.0,
    )
    run.work.mkdir()

    calendar = namespace["lookup_calendar"](run)

    assert calendar["status"] == "unavailable"
    assert calendar["sources"][0]["source"] == "google"
    assert calendar["sources"][0]["status"] == "failed"
    assert "no calendar fixture" in calendar["sources"][0]["error"]

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
    assert "Standup was written without calendar data" in hark
    assert job["calendar_enrichment"]["notification_sent"] is True


def test_finalize_writes_minutes_data_and_only_proposes_named_new_people(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    env, vault, media, fixtures = pipeline_env(tmp_path)
    write_fixtures(
        fixtures,
        calendar=CALENDAR,
        context=CONTEXT,
        speakers=SPEAKERS,
        minutes=MINUTES,
        reviewed=REVIEWED,
    )
    (vault / "01-logs/2026-w42.md").write_text("### Tue, Oct 13\n\n- work\n")
    namespace = load_script(env, monkeypatch)
    started_at = 1_791_911_433.0
    run = namespace["MeetingRun"](
        work=tmp_path / "work",
        transcript=TRANSCRIPT,
        started_at=started_at,
        duration=300.0,
    )
    result = namespace["run_minutes_pipeline"](run)
    recording = media / ".inbox/job.mp4"
    recording.parent.mkdir()
    recording.write_bytes(b"video")
    transcript_path = tmp_path / "work/transcript.json"
    transcript_path.write_text(json.dumps(TRANSCRIPT))
    job = {
        "job_id": "c" * 32,
        "recording_started_at": started_at,
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
    assert f'minutes_data: "{tmp_path}/reference/{stem}.minutes.json"' in note
    assert f'transcript: "{tmp_path}/reference/{stem}.json"' in note
    assert data["artifacts"]["note"].endswith(f"{stem}.md")
    proposals = sorted((vault / "04-projects/_pipeline/proposals").iterdir())
    assert [path.name for path in proposals] == ["meeting-person-margaret-hamilton.md"]
    proposal = proposals[0].read_text()
    assert "Introduces herself as Margaret Hamilton" in proposal
    assert 'target: "04-projects/people.toml"' in proposal
    assert "SPEAKER_" not in note + proposal
    assert (
        f"[[01-logs/meetings/{stem}|Dev environment review]]"
        in (vault / "01-logs/2026-w42.md").read_text()
    )
