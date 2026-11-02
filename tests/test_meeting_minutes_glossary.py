from __future__ import annotations

import json
from collections.abc import Iterator
from pathlib import Path
from typing import Any

import pytest
from test_meeting_minutes_pipeline import (
    MINUTES,
    PATHS,
    REPAIR,
    SLACK_MESSAGES,
    SPEAKERS,
    STARTED_EPOCH,
    TRANSCRIPT,
    FakeExecutor,
    default_handlers,
    load_script,
    make_run,
    meeting_note,
    pipeline_env,
    regenerate,
    slack_results,
    write_fixtures,
)

STEM = "2026-10-13-tooling-dev-environment-review"
BRANCH_MESSAGE = {
    "channel": "#dev",
    "channel_id": "C00000002",
    "author": "Ada Lovelace",
    "author_id": "UADA000001",
    "ts": str(STARTED_EPOCH + 300),
    "text": "pushed the dev/flake branch for review",
}
CORROBORATED = {
    "heard_as": "DevFlake",
    "term": "dev/flake",
    "source": "slack",
    "quote": "pushed the dev/flake branch",
}


@pytest.fixture
def executor() -> Iterator[FakeExecutor]:
    handlers = default_handlers()
    handlers[PATHS["slack"]] = lambda arguments: slack_results(
        [*SLACK_MESSAGES, BRANCH_MESSAGE]
    )
    fake = FakeExecutor(handlers)
    yield fake
    fake.server.shutdown()


def minutes_with(*candidates: dict[str, str], marked: bool = True) -> dict[str, Any]:
    minutes = json.loads(json.dumps(MINUTES))
    if marked:
        minutes["topics"][0]["bullets"][0]["text"] = (
            "The dev/flake [approximate transcription] worktrees are ready."
        )
    minutes["glossary_candidates"] = list(candidates)
    return minutes


def generate(
    tmp_path: Path,
    executor: FakeExecutor,
    monkeypatch: pytest.MonkeyPatch,
    minutes: dict[str, Any],
    glossary: str = "",
) -> tuple[dict[str, Any], Path]:
    env, vault, media, fixtures = pipeline_env(tmp_path, executor)
    write_fixtures(
        fixtures, speakers=SPEAKERS, minutes=minutes, reviewed=minutes, repair=REPAIR
    )
    (vault / "04-projects/glossary.toml").write_text(glossary)
    (vault / "01-logs/2026-w42.md").write_text("### Tue, Oct 13\n\n- work\n")
    namespace = load_script(env, monkeypatch)
    result = namespace["run_minutes_pipeline"](make_run(namespace, tmp_path / "work"))
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
    return result, vault / "04-projects/_pipeline/proposals"


def glossary_proposals(proposals: Path) -> list[Path]:
    return sorted(proposals.glob("meeting-glossary-*.md")) if proposals.is_dir() else []


def test_corroborated_spelling_becomes_a_glossary_proposal(
    tmp_path: Path, executor: FakeExecutor, monkeypatch: pytest.MonkeyPatch
) -> None:
    result, proposals = generate(
        tmp_path, executor, monkeypatch, minutes_with(CORROBORATED)
    )

    [candidate] = result["glossary_candidates"]
    assert candidate["verified"] is True and candidate["reason"] == ""
    assert candidate["location"].startswith("Slack message from Ada Lovelace in #dev")
    assert [path.name for path in glossary_proposals(proposals)] == [
        "meeting-glossary-dev-flake.md"
    ]
    proposal = (proposals / "meeting-glossary-dev-flake.md").read_text()
    assert proposal.startswith(
        "---\ntype: glossary-addition\n"
        'target: "04-projects/glossary.toml"\n'
        f'meeting_job: "{"c" * 32}"\n'
        "status: proposed\n---\n"
    )
    assert (
        '```toml\n[[terms]]\nterm = "dev/flake"\nheard_as = ["DevFlake"]\nnote = ""\n```'
        in proposal
    )
    assert "> pushed the dev/flake branch" in proposal
    assert f"[[01-logs/meetings/{STEM}|Dev environment review]]" in proposal
    note = (tmp_path / "vault/01-logs/meetings" / f"{STEM}.md").read_text()
    assert "glossary" not in note.split("---\n", 2)[1]


@pytest.mark.parametrize(
    ("candidate", "marked", "reason"),
    [
        (
            {**CORROBORATED, "quote": "renamed the dev/flake branch"},
            True,
            "quote not found in the slack data",
        ),
        ({**CORROBORATED, "source": "meet"}, True, "quote not found in the meet data"),
        (
            {**CORROBORATED, "quote": "pushed the", "term": "dev/flake"},
            True,
            "quote does not spell the term",
        ),
        (
            {**CORROBORATED, "heard_as": "dev flakes"},
            True,
            "heard-as form is not in the transcript",
        ),
        (
            CORROBORATED,
            False,
            "the minutes do not mark it as an approximate transcription",
        ),
        (
            {**CORROBORATED, "term": "devflake"},
            True,
            "incomplete or unchanged spelling",
        ),
    ],
)
def test_uncorroborated_spellings_propose_nothing(
    tmp_path: Path,
    executor: FakeExecutor,
    monkeypatch: pytest.MonkeyPatch,
    candidate: dict[str, str],
    marked: bool,
    reason: str,
) -> None:
    result, proposals = generate(
        tmp_path, executor, monkeypatch, minutes_with(candidate, marked=marked)
    )

    assert result["glossary_candidates"][0]["verified"] is False
    assert result["glossary_candidates"][0]["reason"] == reason
    assert glossary_proposals(proposals) == []


@pytest.mark.parametrize(
    "glossary",
    [
        '[[terms]]\nterm = "DEV/FLAKE"\nheard_as = []\n',
        '[[terms]]\nterm = "dev-flake"\nheard_as = ["devflake"]\n',
    ],
)
def test_terms_already_in_the_glossary_propose_nothing(
    tmp_path: Path,
    executor: FakeExecutor,
    monkeypatch: pytest.MonkeyPatch,
    glossary: str,
) -> None:
    result, proposals = generate(
        tmp_path, executor, monkeypatch, minutes_with(CORROBORATED), glossary
    )

    assert result["glossary_candidates"][0]["verified"] is True
    assert glossary_proposals(proposals) == []


def test_an_existing_proposal_is_left_alone(
    tmp_path: Path, executor: FakeExecutor, monkeypatch: pytest.MonkeyPatch
) -> None:
    proposals = tmp_path / "vault/04-projects/_pipeline/proposals"
    proposals.mkdir(parents=True)
    (proposals / "meeting-glossary-dev-flake.md").write_text("earlier proposal\n")

    generate(tmp_path, executor, monkeypatch, minutes_with(CORROBORATED))

    assert (
        proposals / "meeting-glossary-dev-flake.md"
    ).read_text() == "earlier proposal\n"
    assert len(glossary_proposals(proposals)) == 1


def test_regenerate_records_candidates_but_writes_no_proposal(
    tmp_path: Path, executor: FakeExecutor
) -> None:
    env, vault, media, fixtures = pipeline_env(tmp_path, executor)
    minutes = minutes_with(CORROBORATED)
    write_fixtures(
        fixtures, speakers=SPEAKERS, minutes=minutes, reviewed=minutes, repair=REPAIR
    )
    note = meeting_note(vault, media)
    out = tmp_path / "eval"

    regenerate(env, note.stem, "--out", str(out))

    result = json.loads((out / f"{note.stem}.minutes.json").read_text())
    assert result["glossary_candidates"][0]["verified"] is True
    assert not (vault / "04-projects/_pipeline/proposals").exists()
