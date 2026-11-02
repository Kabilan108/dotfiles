from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from collections.abc import Iterator
from pathlib import Path

import pytest
from test_meeting_minutes_pipeline import (
    SCRIPT,
    FakeExecutor,
    calls,
    default_handlers,
    full_fixtures,
    pipeline_env,
    regenerate,
)
from test_meeting_minutes_publish import STEM, production_note


@pytest.fixture
def executor() -> Iterator[FakeExecutor]:
    fake = FakeExecutor(default_handlers())
    yield fake
    fake.server.shutdown()


def setup(
    tmp_path: Path, fake: FakeExecutor
) -> tuple[dict[str, str], Path, Path, Path]:
    env, vault, media, fixtures = pipeline_env(tmp_path, fake)
    env["MEETING_MINUTES_PUBLISH_BACKUP"] = str(tmp_path / "backup")
    full_fixtures(fixtures)
    production_note(vault, media)
    return env, vault, media, fixtures


def test_speaker_range_relabels_segments_without_touching_the_transcript(
    tmp_path: Path, executor: FakeExecutor
) -> None:
    env, _, media, fixtures = setup(tmp_path, executor)
    transcript_path = media / f"{STEM}.json"
    original = transcript_path.read_bytes()
    out = tmp_path / "eval"

    completed = regenerate(
        env,
        STEM,
        "--out",
        str(out),
        "--speaker",
        "SPEAKER_00=grace-hopper",
        "--speaker-range",
        "12.5-40.5=ada-lovelace",
    )

    summary = json.loads(completed.stdout)
    assert summary["speakers"]["SPEAKER_00"] == "Grace Hopper"
    assert summary["speakers"]["SPEAKER_04"] == "Ada Lovelace"
    assert transcript_path.read_bytes() == original

    result = json.loads((out / f"{STEM}.minutes.json").read_text())
    assert result["speaker_overrides"] == [
        {
            "start": 12.5,
            "end": 40.5,
            "person": "ada-lovelace",
            "label": "SPEAKER_04",
            "segments": [1],
            "original_labels": ["SPEAKER_00"],
        }
    ]
    ada = next(
        speaker for speaker in result["speakers"] if speaker["label"] == "SPEAKER_04"
    )
    assert (ada["person_id"], ada["evidence"]) == (
        "ada-lovelace",
        ["Confirmed by Tony"],
    )
    anchors = {
        anchor["id"]: anchor["speaker"] for anchor in result["transcript_anchors"]
    }
    assert (anchors["s0"], anchors["s1"]) == ("SPEAKER_00", "SPEAKER_04")
    inputs = result["pipeline"]["inputs"]
    expected = hashlib.sha256(
        json.dumps(json.loads(original), sort_keys=True).encode()
    ).hexdigest()
    assert inputs["transcript"] == expected
    assert json.loads(inputs["speaker_ranges"])[0]["label"] == "SPEAKER_04"

    prompt = calls(fixtures)[0]["prompt"]
    assert "s1 [0:13] SPEAKER_04: Each DevFlake" in prompt
    assert (
        "SPEAKER_04 is Ada Lovelace (`ada-lovelace`); return exactly this mapping."
        in prompt
    )
    note = (out / f"{STEM}.md").read_text()
    assert "SPEAKER_" not in note and '  - "Ada Lovelace"\n' in note

    published = subprocess.run(
        [sys.executable, str(SCRIPT), "publish", str(out)],
        capture_output=True,
        text=True,
        env=env,
    )
    assert published.returncode == 0, published.stdout + published.stderr
    production = json.loads((media / f"{STEM}.minutes.json").read_text())
    assert production["speaker_overrides"][0]["person"] == "ada-lovelace"
    assert transcript_path.read_bytes() == original

    changed = regenerate(
        env,
        STEM,
        "--out",
        str(out),
        "--speaker-range",
        "12.5-41=ada-lovelace",
        check=False,
    )
    assert changed.returncode == 1 and "speaker_ranges" in changed.stderr


@pytest.mark.parametrize(
    ("ranges", "message"),
    [
        (["12.5-40.5"], "expects START-END=person"),
        (["40-12=ada-lovelace"], "END must be after START"),
        (["13.5-14=ada-lovelace"], "no segment lies inside it"),
        (["12-41=ada-lovelace", "0-41=grace-hopper"], "overlaps"),
        (["12-41=margaret-hamilton"], "marked both present and absent"),
    ],
)
def test_speaker_range_refuses_bad_ranges(
    tmp_path: Path, executor: FakeExecutor, ranges: list[str], message: str
) -> None:
    env, _, _, _ = setup(tmp_path, executor)
    arguments = [part for entry in ranges for part in ("--speaker-range", entry)]

    completed = regenerate(
        env,
        STEM,
        "--out",
        str(tmp_path / "eval"),
        *arguments,
        "--absent",
        "margaret-hamilton",
        check=False,
    )

    assert completed.returncode == 1
    assert message in completed.stderr


def test_ranges_for_one_person_share_a_label(
    tmp_path: Path, executor: FakeExecutor
) -> None:
    env, _, _, _ = setup(tmp_path, executor)
    out = tmp_path / "eval"

    regenerate(
        env,
        STEM,
        "--out",
        str(out),
        "--speaker-range",
        "0-12=ada-lovelace",
        "--speaker-range",
        "159-201=Ada Lovelace",
        "--speaker-range",
        "150-153=unknown",
    )

    result = json.loads((out / f"{STEM}.minutes.json").read_text())
    assert [(o["label"], o["segments"]) for o in result["speaker_overrides"]] == [
        ("SPEAKER_04", [0]),
        ("SPEAKER_04", [5]),
        ("SPEAKER_05", [4]),
    ]
    by_label = {speaker["label"]: speaker for speaker in result["speakers"]}
    assert by_label["SPEAKER_04"]["display"] == "Ada Lovelace"
    assert by_label["SPEAKER_05"]["display"] == "Unknown speaker"
