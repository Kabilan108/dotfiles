from __future__ import annotations

import json
from collections.abc import Iterator
from pathlib import Path
from typing import Any

import pytest
from test_meeting_minutes_pipeline import (
    FakeExecutor,
    calls,
    default_handlers,
    full_fixtures,
    load_script,
    make_run,
    meeting_note,
    pipeline_env,
    regenerate,
)

REGISTRY = """version = 1

[owner]
id = "tony"
name = "Tony Kabilan Okeke"
aliases = ["Tony"]

[[people]]
id = "ethan-moyer"
name = "Ethan Moyer"

[[people]]
id = "jackie-lee"
name = "Jackie Lee"

[[people]]
id = "emily-gilmore"
name = "Emily Gilmore"

[[people]]
id = "morteza-zabihi"
name = "Morteza Zabihi"
"""

WORKSHOP = {
    "recording_started_at": "2026-10-07T10:00:00-04:00",
    "duration": 120.0,
    "segments": [
        {
            "id": 0,
            "start": 0.0,
            "end": 9.0,
            "speaker": "SPEAKER_00",
            "text": "Morning. I trimmed the deck.",
        },
        {
            "id": 1,
            "start": 10.0,
            "end": 19.0,
            "speaker": "SPEAKER_01",
            "text": "Fifteen minutes is about right for the workshop.",
        },
        {
            "id": 2,
            "start": 20.0,
            "end": 29.0,
            "speaker": "SPEAKER_00",
            "text": "Okay, that's right, Peter. Tony, did you try the image?",
        },
        {
            "id": 3,
            "start": 30.0,
            "end": 39.0,
            "speaker": "SPEAKER_02",
            "text": "Yes, I have it deployed.",
        },
        {
            "id": 4,
            "start": 40.0,
            "end": 49.0,
            "speaker": "SPEAKER_03",
            "text": "Our IRB covers the REDCap questions.",
        },
        {
            "id": 5,
            "start": 50.0,
            "end": 59.0,
            "speaker": "SPEAKER_04",
            "text": "Hi all, I'm Rina Patel from the sleep lab.",
        },
        {
            "id": 6,
            "start": 60.0,
            "end": 69.0,
            "speaker": "SPEAKER_05",
            "text": "Sounds good to me.",
        },
        {
            "id": 7,
            "start": 70.0,
            "end": 79.0,
            "speaker": "SPEAKER_00",
            "text": "Thanks Omar, that settles the venue.",
        },
        {
            "id": 8,
            "start": 80.0,
            "end": 89.0,
            "speaker": "SPEAKER_02",
            "text": "Omar can send the slides afterwards.",
        },
    ],
}


def model_answer(**overrides: dict[str, Any]) -> dict[str, Any]:
    base = {
        "SPEAKER_00": {
            "status": "identified",
            "person_id": "morteza-zabihi",
            "name": "Morteza Zabihi",
            "likely": [],
            "confidence": "high",
            "evidence": ["Presents the workshop"],
        },
        "SPEAKER_01": {
            "status": "new_person",
            "person_id": "",
            "name": "Peter",
            "likely": [],
            "confidence": "medium",
            "evidence": ["Addressed as Peter at s2"],
        },
        "SPEAKER_02": {
            "status": "identified",
            "person_id": "tony",
            "name": "Tony Kabilan Okeke",
            "likely": [],
            "confidence": "high",
            "evidence": ["Answers to Tony at s2"],
        },
        "SPEAKER_03": {
            "status": "unknown",
            "person_id": "",
            "name": "",
            "likely": ["Jackie Lee", "Emily Gilmore"],
            "confidence": "low",
            "evidence": ["Talks about IRB and REDCap"],
        },
        "SPEAKER_04": {
            "status": "new_person",
            "person_id": "",
            "name": "Rina Patel",
            "likely": [],
            "confidence": "high",
            "evidence": ["Introduces herself at s5"],
        },
        "SPEAKER_05": {
            "status": "new_person",
            "person_id": "",
            "name": "Omar",
            "likely": [],
            "confidence": "medium",
            "evidence": ["Thanked by name at s7"],
        },
    }
    for label, change in overrides.items():
        base[label] = {**base[label], **change}
    return {"speakers": [{"label": label, **entry} for label, entry in base.items()]}


@pytest.fixture
def executor() -> Iterator[FakeExecutor]:
    fake = FakeExecutor(default_handlers())
    yield fake
    fake.server.shutdown()


@pytest.fixture
def workshop(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> dict[str, Any]:
    env, _, _, _ = pipeline_env(tmp_path)
    (tmp_path / "people.toml").write_text(REGISTRY)
    namespace = load_script(env, monkeypatch)
    return {
        "namespace": namespace,
        "registry": namespace["load_registry"](),
        "tmp_path": tmp_path,
    }


def mapped(
    workshop: dict[str, Any],
    payload: dict[str, Any],
    *,
    calendar: dict[str, Any] | None = None,
    context: dict[str, Any] | None = None,
    **hints: Any,
) -> dict[str, dict[str, Any]]:
    namespace, registry = workshop["namespace"], workshop["registry"]
    speaker_hints = namespace["SpeakerHints"](**hints)
    run = make_run(
        namespace,
        workshop["tmp_path"] / "work",
        transcript=WORKSHOP,
        hints=speaker_hints,
    )
    ties = namespace["MeetingTies"](
        run,
        calendar or {"candidates": []},
        context or {"meet": {}, "slack": {"messages": []}},
        registry,
    )
    speakers = namespace["validate_speaker_map"](
        payload, WORKSHOP, registry, ties, speaker_hints
    )
    return {speaker["label"]: speaker for speaker in speakers}


def test_likely_candidates_need_a_tie_to_the_meeting(workshop: dict[str, Any]) -> None:
    speakers = mapped(workshop, model_answer())
    assert speakers["SPEAKER_03"]["display"] == "Unknown speaker"
    assert speakers["SPEAKER_03"]["likely"] == []

    slack = {
        "meet": {},
        "slack": {
            "messages": [
                {"author": "Jackie Lee", "participants": "", "text": "joining"}
            ]
        },
    }
    assert mapped(workshop, model_answer(), context=slack)["SPEAKER_03"]["likely"] == [
        "Jackie Lee"
    ]
    calendar = {
        "candidates": [{"title": "Workshop prep", "attendees": ["Emily Gilmore"]}]
    }
    assert mapped(workshop, model_answer(), calendar=calendar)["SPEAKER_03"][
        "likely"
    ] == ["Emily Gilmore"]
    meet = {
        "meet": {"speakers": [{"name": "Jackie Lee", "samples": []}]},
        "slack": {"messages": []},
    }
    assert mapped(workshop, model_answer(), context=meet)["SPEAKER_03"]["likely"] == [
        "Jackie Lee"
    ]
    confirmed = mapped(workshop, model_answer(), attendees=["emily-gilmore"])
    assert confirmed["SPEAKER_03"]["display"] == "Unknown (likely Emily Gilmore)"
    addressed = mapped(
        workshop, model_answer(SPEAKER_03={"likely": ["Tony", "Ethan Moyer"]})
    )
    assert addressed["SPEAKER_03"]["likely"] == ["Tony Kabilan Okeke"]


def test_unregistered_names_need_an_introduction_or_an_outside_source(
    workshop: dict[str, Any],
) -> None:
    speakers = mapped(workshop, model_answer())

    assert speakers["SPEAKER_04"]["status"] == "new_person"
    assert speakers["SPEAKER_04"]["display"] == "Rina Patel"
    for label in ("SPEAKER_01", "SPEAKER_05"):
        assert speakers[label]["status"] == "unknown"
        assert speakers[label]["display"] == "Unknown speaker"

    calendar = {"candidates": [{"title": "Prep with Peter", "attendees": []}]}
    assert (
        mapped(workshop, model_answer(), calendar=calendar)["SPEAKER_01"]["status"]
        == "new_person"
    )
    slack = {
        "meet": {},
        "slack": {"messages": [{"author": "Omar", "participants": "", "text": "hi"}]},
    }
    assert (
        mapped(workshop, model_answer(), context=slack)["SPEAKER_05"]["status"]
        == "new_person"
    )


def test_names_only_said_in_the_transcript_are_not_likely_candidates(
    workshop: dict[str, Any],
) -> None:
    talked_about = mapped(
        workshop, model_answer(SPEAKER_03={"likely": ["Omar", "Peter"]})
    )
    assert talked_about["SPEAKER_03"]["display"] == "Unknown speaker"

    introduced = mapped(workshop, model_answer(SPEAKER_03={"likely": ["Rina Patel"]}))
    assert introduced["SPEAKER_03"]["likely"] == ["Rina Patel"]
    confirmed = mapped(
        workshop, model_answer(SPEAKER_03={"likely": ["Omar"]}), attendees=["Omar"]
    )
    assert confirmed["SPEAKER_03"]["likely"] == ["Omar"]


def test_forced_mappings_replace_the_model_answer(workshop: dict[str, Any]) -> None:
    speakers = mapped(
        workshop,
        model_answer(),
        forced={
            "SPEAKER_01": "ethan-moyer",
            "SPEAKER_03": "unknown",
            "SPEAKER_05": "Omar Haddad",
        },
    )

    ethan = speakers["SPEAKER_01"]
    assert (ethan["status"], ethan["person_id"], ethan["display"]) == (
        "identified",
        "ethan-moyer",
        "Ethan Moyer",
    )
    assert (ethan["confidence"], ethan["evidence"], ethan["likely"]) == (
        "high",
        ["Confirmed by Tony"],
        [],
    )
    assert speakers["SPEAKER_03"]["status"] == "unknown"
    assert speakers["SPEAKER_03"]["display"] == "Unknown speaker"
    assert speakers["SPEAKER_03"]["evidence"] == ["Confirmed by Tony"]
    assert speakers["SPEAKER_05"]["display"] == "Omar Haddad"
    assert speakers["SPEAKER_05"]["status"] == "identified"
    assert (
        mapped(workshop, model_answer(), forced={"SPEAKER_02": "Tony"})["SPEAKER_02"][
            "display"
        ]
        == "Tony"
    )


def test_absent_people_are_never_mapped_or_listed(workshop: dict[str, Any]) -> None:
    payload = model_answer(
        SPEAKER_00={"person_id": "ethan-moyer", "name": "Ethan Moyer"},
        SPEAKER_03={"likely": ["Ethan Moyer", "Tony"]},
    )
    speakers = mapped(workshop, payload, absent=["Ethan Moyer"])

    assert speakers["SPEAKER_00"]["status"] == "unknown"
    assert "Ethan Moyer" not in speakers["SPEAKER_00"]["likely"]
    assert speakers["SPEAKER_03"]["likely"] == ["Tony Kabilan Okeke"]
    namespace, registry = workshop["namespace"], workshop["registry"]
    hints = namespace["SpeakerHints"](attendees=["jackie-lee"], absent=["ethan-moyer"])
    attendees = namespace["merge_attendees"](
        ["Ethan Moyer", "Morteza Zabihi"], [], registry, {}, hints
    )
    assert attendees == ["Morteza Zabihi", "Jackie Lee"]


def test_regenerate_applies_speaker_flags_and_fingerprints_them(
    tmp_path: Path, executor: FakeExecutor
) -> None:
    env, vault, media, fixtures = pipeline_env(tmp_path, executor)
    full_fixtures(fixtures)
    note = meeting_note(vault, media)
    out = tmp_path / "eval"

    completed = regenerate(
        env,
        note.stem,
        "--out",
        str(out),
        "--speaker",
        "SPEAKER_03=grace-hopper",
        "--attendee",
        "Ada Lovelace",
        "--absent",
        "Margaret Hamilton",
    )

    summary = json.loads(completed.stdout)
    assert summary["speakers"]["SPEAKER_03"] == "Grace Hopper"
    assert summary["speakers"]["SPEAKER_02"] == "Unknown speaker"
    prompt = calls(fixtures)[0]["prompt"]
    assert (
        "SPEAKER_03 is Grace Hopper (`grace-hopper`); return exactly this mapping."
        in prompt
    )
    assert "Attended the meeting: Ada Lovelace (`ada-lovelace`)" in prompt
    assert (
        "never map a label to them or list them as likely: Margaret Hamilton" in prompt
    )
    inputs = json.loads((out / "inputs.json").read_text())["inputs"]
    assert json.loads(inputs["speaker_hints"])["forced"] == {
        "SPEAKER_03": "grace-hopper"
    }

    changed = regenerate(
        env,
        note.stem,
        "--out",
        str(out),
        "--speaker",
        "SPEAKER_03=unknown",
        check=False,
    )
    assert changed.returncode == 1 and "speaker_hints" in changed.stderr
    missing = regenerate(
        env,
        note.stem,
        "--out",
        str(tmp_path / "x"),
        "--speaker",
        "SPEAKER_09=tony",
        check=False,
    )
    assert "not a speaker in this transcript" in missing.stderr
    conflict = regenerate(
        env,
        note.stem,
        "--out",
        str(tmp_path / "y"),
        "--attendee",
        "ada-lovelace",
        "--absent",
        "Ada Lovelace",
        check=False,
    )
    assert "marked both present and absent" in conflict.stderr
    malformed = regenerate(
        env,
        note.stem,
        "--out",
        str(tmp_path / "z"),
        "--speaker",
        "SPEAKER_03",
        check=False,
    )
    assert "expects LABEL=person" in malformed.stderr
