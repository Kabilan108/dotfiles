from __future__ import annotations

import json
import os
import runpy
import subprocess
import sys
from pathlib import Path
from typing import Any

import pytest

SCRIPT = Path(__file__).parents[1] / "bin" / "meeting-minutes"


def cli_env(tmp_path: Path) -> tuple[dict[str, str], Path, Path]:
    media = tmp_path / "media"
    vault = tmp_path / "vault"
    (vault / "01-logs/meetings").mkdir(parents=True)
    media.mkdir()
    env = os.environ.copy()
    env.update(
        {
            "COPPERMIND_VAULT": str(vault),
            "MEETING_MINUTES_MEDIA_ROOT": str(media),
            "MEETING_MINUTES_MEDIA_REFERENCE_ROOT": str(media),
            "MEETING_MINUTES_STATE_DIR": str(tmp_path / "state"),
        }
    )
    return env, media, vault


def run_cli(env: dict[str, str], *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        check=True,
        capture_output=True,
        text=True,
        env=env,
    )


def test_transcript_command_renders_note_metadata(tmp_path: Path) -> None:
    env, media, vault = cli_env(tmp_path)
    transcript = {
        "segments": [
            {"speaker": "SPEAKER_00", "start": 1, "text": "First."},
            {"speaker": "SPEAKER_00", "start": 3, "text": "Second."},
            {"speaker": "SPEAKER_01", "start": 65, "text": "Reply."},
        ]
    }
    transcript_path = media / "2026-09-17-tooling-test.json"
    transcript_path.write_text(json.dumps(transcript))
    note = vault / "01-logs/meetings/2026-09-17-tooling-test.md"
    note.write_text(
        f"---\ntranscript: {json.dumps(str(transcript_path))}\n---\n# Test\n"
    )

    rendered = run_cli(env, "transcript", note.stem)
    assert rendered.stdout == (
        "[0:01] SPEAKER_00: First. Second.\n[1:05] SPEAKER_01: Reply.\n"
    )

    raw = run_cli(env, "transcript", str(note), "--json")
    assert json.loads(raw.stdout) == transcript


def test_transcript_command_supports_legacy_recording_metadata(tmp_path: Path) -> None:
    env, media, vault = cli_env(tmp_path)
    transcript_path = media / "legacy.json"
    transcript_path.write_text(json.dumps({"text": "Legacy transcript"}))
    note = vault / "01-logs/meetings/legacy.md"
    note.write_text(f"---\nrecording: {media / 'legacy.mp4'}\n---\n# Legacy\n")

    rendered = run_cli(env, "transcript", "legacy")
    assert json.loads(rendered.stdout) == {"text": "Legacy transcript"}


def test_sync_copies_json_and_moves_only_top_level_mp4(tmp_path: Path) -> None:
    env, media, _ = cli_env(tmp_path)
    destination = tmp_path / "sietch"
    destination.mkdir()
    env["MEETING_MINUTES_SYNC_DESTINATION"] = str(destination)
    (media / "meeting.json").write_text('{"text":"hello"}\n')
    (media / "meeting.mp4").write_bytes(b"recording")
    (media / "keep.txt").write_text("local")
    (media / ".work").mkdir()
    (media / ".work/incomplete.mp4").write_bytes(b"incomplete")

    run_cli(env, "sync-artifacts")

    assert (media / "meeting.json").is_file()
    assert not (media / "meeting.mp4").exists()
    assert (destination / "meeting.json").read_text() == '{"text":"hello"}\n'
    assert (destination / "meeting.mp4").read_bytes() == b"recording"
    assert not (destination / "keep.txt").exists()
    assert not (destination / ".work/incomplete.mp4").exists()
    assert (media / ".work/incomplete.mp4").is_file()


def test_pipeline_note_uses_shared_artifact_references(tmp_path: Path) -> None:
    namespace = runpy.run_path(str(SCRIPT))
    namespace["render_note"].__globals__["MEDIA_ROOT"] = tmp_path / "media"
    namespace["render_note"].__globals__["MEDIA_REFERENCE_ROOT"] = Path(
        "/vault/userdata/media/meetings"
    )
    job = {
        "recording_started_at": 1_700_000_000,
        "job_id": "a" * 32,
        "recording_identity": "identity",
        "codex_session": "session",
    }
    minutes: dict[str, Any] = {
        "attendees": [],
        "summary": "Summary",
        "project": "tooling",
        "title": "Artifact test",
        "notes": [],
        "decisions": [],
        "follow_ups": [],
    }

    note = namespace["render_note"](
        job,
        minutes,
        tmp_path / "media/artifact-test.mp4",
        tmp_path / "media/artifact-test.json",
        [],
    )

    assert 'recording: "/vault/userdata/media/meetings/artifact-test.mp4"' in note
    assert 'transcript: "/vault/userdata/media/meetings/artifact-test.json"' in note


def test_artifact_sync_kick_is_non_blocking(monkeypatch: pytest.MonkeyPatch) -> None:
    namespace = runpy.run_path(str(SCRIPT))
    kick = namespace["kick_artifact_sync"]
    calls: list[tuple[list[str], dict[str, Any]]] = []

    def fake_run(args: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
        calls.append((args, kwargs))
        return subprocess.CompletedProcess(args, 0)

    monkeypatch.setattr(kick.__globals__["subprocess"], "run", fake_run)

    assert kick() is True
    assert calls[0][0] == [
        "systemctl",
        "--user",
        "start",
        "--no-block",
        "meeting-minutes-artifact-sync.service",
    ]
