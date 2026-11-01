from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from collections.abc import Iterator
from typing import Any

import pytest

from test_meeting_minutes_pipeline import (
    SCRIPT,
    TRANSCRIPT,
    FakeExecutor,
    default_handlers,
    full_fixtures,
    pipeline_env,
    regenerate,
    tree_snapshot,
)

STEM = "2026-10-13-tooling-dev-review"


@pytest.fixture
def executor() -> Iterator[FakeExecutor]:
    fake = FakeExecutor(default_handlers())
    yield fake
    fake.server.shutdown()


def production_note(vault: Path, media: Path, *, identity: str = "identity") -> Path:
    transcript = media / f"{STEM}.json"
    transcript.write_text(json.dumps(TRANSCRIPT))
    note = vault / "01-logs/meetings" / f"{STEM}.md"
    note.write_text(
        "---\n"
        "date: 2026-10-13\n"
        'project: "tooling"\n'
        "attendees:\n"
        '  - "Tony Kabilan Okeke"\n'
        '  - "SPEAKER_01"\n'
        'summary: "Old summary."\n'
        "source: pipeline\n"
        f'recording: "/vault/userdata/media/meetings/{STEM}.mp4"\n'
        f'transcript: "/vault/userdata/media/meetings/{STEM}.json"\n'
        f'pipeline_job: "{"a" * 32}"\n'
        f'recording_identity: "{identity}"\n'
        'codex_session: "jacurutu:old"\n'
        "---\n"
        "# Old note\n\n## notes\n\n"
        f"- Old point\n\n  ![[{STEM}-01.png]]\n- Shared\n\n  ![[{STEM}-02.png]]\n"
    )
    assets = vault / "assets"
    assets.mkdir()
    (assets / f"{STEM}-01.png").write_bytes(b"old frame one")
    (assets / f"{STEM}-02.png").write_bytes(b"old frame two")
    (assets / "unrelated.png").write_bytes(b"someone else")
    (vault / "01-logs/other.md").write_text(
        f"See ![[{STEM}-02.png]] and ![[unrelated.png]]\n"
    )
    (vault / "01-logs/2026-w42.md").write_text(
        "### Tue, Oct 13\n\n- Meeting notes: [[old]]\n"
    )
    return note


def regenerated(env: dict[str, str], tmp_path: Path, fixtures: Path) -> Path:
    full_fixtures(fixtures)
    out = tmp_path / "regen" / STEM
    regenerate(env, STEM, "--out", str(out))
    minutes_path = out / f"{STEM}.minutes.json"
    result = json.loads(minutes_path.read_text())
    (out / "assets").mkdir(exist_ok=True)
    (out / "assets" / f"{STEM}-01.png").write_bytes(b"new frame")
    result["screenshots"] = [
        {
            "asset_name": f"{STEM}-01.png",
            "asset_path": str(out / "assets" / f"{STEM}-01.png"),
            "topic_index": 0,
            "bullet_index": 0,
            "timestamp_seconds": 5.0,
            "caption": "Terminal showing the DevFlake checkout",
        }
    ]
    minutes_path.write_text(json.dumps(result))
    return out


def publish(env: dict[str, str], *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "publish", *args],
        capture_output=True,
        text=True,
        env=env,
    )


def setup(
    tmp_path: Path, fake: FakeExecutor, **note: Any
) -> tuple[dict[str, str], Path, Path, Path]:
    env, vault, media, fixtures = pipeline_env(tmp_path, fake)
    env["MEETING_MINUTES_PUBLISH_BACKUP"] = str(tmp_path / "backup")
    production_note(vault, media, **note)
    return env, vault, media, regenerated(env, tmp_path, fixtures)


def test_publish_installs_the_regenerated_note(
    tmp_path: Path, executor: FakeExecutor
) -> None:
    env, vault, media, out = setup(tmp_path, executor)
    original = (vault / "01-logs/meetings" / f"{STEM}.md").read_text()
    weekly = (vault / "01-logs/2026-w42.md").read_text()

    completed = publish(env, str(out))

    assert completed.returncode == 0, completed.stderr
    summary = json.loads(completed.stdout)[0]
    assert summary["assets_written"] == [f"{STEM}-01.png"]
    assert summary["assets_removed"] == []
    assert summary["assets_kept_for_other_notes"] == [f"{STEM}-02.png"]

    note = (vault / "01-logs/meetings" / f"{STEM}.md").read_text()
    reference = tmp_path / "reference"
    assert f'minutes_data: "{reference}/{STEM}.minutes.json"\n' in note
    assert f'pipeline_job: "{"a" * 32}"\n' in note
    assert 'recording_identity: "identity"\n' in note
    assert f'recording: "/vault/userdata/media/meetings/{STEM}.mp4"\n' in note
    assert f'transcript: "/vault/userdata/media/meetings/{STEM}.json"\n' in note
    assert "/regen/" not in note and "SPEAKER_" not in note
    assert f"![[{STEM}-01.png]]" in note and f"![[{STEM}-02.png]]" not in note
    assert "# Dev environment review\n" in note
    assert "- Worktrees are ready. [0:01–0:12]\n\n  ![[" in note
    assert "_Terminal showing the DevFlake checkout (00:00:05)_" in note

    data = json.loads((media / f"{STEM}.minutes.json").read_text())
    assert data["artifacts"]["note"] == str(vault / "01-logs/meetings" / f"{STEM}.md")
    assert data["artifacts"]["published_from"] == str(out)
    assert data["screenshots"][0]["asset_path"] == str(
        vault / "assets" / f"{STEM}-01.png"
    )

    assets = vault / "assets"
    assert (assets / f"{STEM}-01.png").read_bytes() == b"new frame"
    assert (assets / f"{STEM}-02.png").read_bytes() == b"old frame two"
    assert (assets / "unrelated.png").read_bytes() == b"someone else"
    backup = tmp_path / "backup" / STEM
    assert (backup / f"{STEM}.md").read_text() == original
    assert (backup / "assets" / f"{STEM}-01.png").read_bytes() == b"old frame one"
    assert (vault / "01-logs/2026-w42.md").read_text() == weekly
    assert not (vault / "04-projects/_pipeline/proposals").exists()

    again = publish(env, str(out))
    assert again.returncode == 0, again.stderr
    assert (backup / f"{STEM}.md").read_text() == original


def test_publish_removes_original_assets_nothing_else_links(
    tmp_path: Path,
    executor: FakeExecutor,
) -> None:
    env, vault, _, out = setup(tmp_path, executor)
    (vault / "01-logs/other.md").write_text("Nothing embedded here.\n")

    summary = json.loads(publish(env, str(out)).stdout)[0]

    assert summary["assets_removed"] == [f"{STEM}-02.png"]
    assert not (vault / "assets" / f"{STEM}-02.png").exists()
    assert (
        tmp_path / "backup" / STEM / "assets" / f"{STEM}-02.png"
    ).read_bytes() == b"old frame two"


def test_publish_dry_run_writes_nothing(tmp_path: Path, executor: FakeExecutor) -> None:
    env, vault, media, out = setup(tmp_path, executor)
    before = tree_snapshot(vault), tree_snapshot(media)

    completed = publish(env, "--dry-run", str(out))

    assert completed.returncode == 0, completed.stderr
    assert json.loads(completed.stdout)[0]["dry_run"] is True
    assert (tree_snapshot(vault), tree_snapshot(media)) == before
    assert not (tmp_path / "backup").exists()


def test_publish_refuses_mismatched_meetings(
    tmp_path: Path, executor: FakeExecutor
) -> None:
    env, vault, media, out = setup(tmp_path, executor, identity="other-recording")
    before = tree_snapshot(vault)
    refused = publish(env, str(out))
    assert refused.returncode == 1
    assert "recording identity does not match" in json.loads(refused.stdout)[0]["error"]
    assert tree_snapshot(vault) == before

    note = vault / "01-logs/meetings" / f"{STEM}.md"
    note.write_text(note.read_text().replace('"other-recording"', '"identity"'))
    changed = json.loads(json.dumps(TRANSCRIPT))
    changed["segments"][0]["text"] = "A different transcript."
    (media / f"{STEM}.json").write_text(json.dumps(changed))
    refused = publish(env, str(out))
    assert "different transcript" in json.loads(refused.stdout)[0]["error"]

    (media / f"{STEM}.json").write_text(json.dumps(TRANSCRIPT))
    note.write_text(note.read_text().replace("source: pipeline", "source: manual"))
    refused = publish(env, str(out))
    assert "is not a pipeline note" in json.loads(refused.stdout)[0]["error"]
    assert not (tmp_path / "backup").exists()


def test_publish_will_not_overwrite_another_notes_asset(
    tmp_path: Path,
    executor: FakeExecutor,
) -> None:
    env, vault, _, out = setup(tmp_path, executor)
    note = vault / "01-logs/meetings" / f"{STEM}.md"
    note.write_text(note.read_text().replace(f"![[{STEM}-01.png]]", ""))
    (vault / "01-logs/other.md").write_text(f"![[{STEM}-01.png]]\n")

    refused = publish(env, str(out))

    assert refused.returncode == 1
    assert "belongs to another note" in json.loads(refused.stdout)[0]["error"]
    assert (vault / "assets" / f"{STEM}-01.png").read_bytes() == b"old frame one"
