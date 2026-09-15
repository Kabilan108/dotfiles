from __future__ import annotations

import json
import runpy
import subprocess
from pathlib import Path
from typing import Any

import pytest


SCRIPT = Path(__file__).parents[1] / "bin" / "meeting-minutes"


def load_notify() -> tuple[Any, dict[str, Any]]:
    namespace = runpy.run_path(str(SCRIPT))
    notify = namespace["notify_job"]
    saved: list[dict[str, Any]] = []
    notify.__globals__["save_job"] = lambda job: saved.append(dict(job))
    notify.__globals__["HARKCTL"] = "/nix/store/harkctl/bin/harkctl"
    return notify, {"saved": saved, "globals": notify.__globals__}


def test_notify_success_uses_json_stdin_and_outcome_key(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    notify, context = load_notify()
    calls: list[tuple[list[str], dict[str, Any]]] = []

    def fake_run(args: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
        calls.append((args, kwargs))
        return subprocess.CompletedProcess(args, 0, "", "")

    monkeypatch.setattr(context["globals"]["subprocess"], "run", fake_run)
    job = {
        "job_id": "a" * 32,
        "title": "Weekly sync",
        "note_path": "/vault/notes/weekly.md",
        "notification_attempted": False,
    }

    notify(job, success=True)

    args, kwargs = calls[0]
    assert args == [
        "/nix/store/harkctl/bin/harkctl",
        "notify",
        "--stdin",
        "--idempotency-key",
        f"meeting-minutes:{'a' * 32}:success",
    ]
    assert json.loads(kwargs["input"]) == {
        "body": "Weekly sync — /vault/notes/weekly.md",
        "title": "Meeting minutes ready",
        "project": "Meeting Minutes",
    }
    assert kwargs["stderr"] is subprocess.PIPE
    assert job["notification_sent"] is True


def test_notify_failure_records_stderr_and_only_attempts_once(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    notify, context = load_notify()
    calls = 0

    def fake_run(args: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
        nonlocal calls
        calls += 1
        assert args[-1] == f"meeting-minutes:{'b' * 32}:failure"
        assert json.loads(kwargs["input"]) == {
            "body": "transcription failed",
            "title": "Meeting minutes failed",
            "project": "Meeting Minutes",
        }
        return subprocess.CompletedProcess(args, 22, "", "webhook rejected")

    monkeypatch.setattr(context["globals"]["subprocess"], "run", fake_run)
    job = {
        "job_id": "b" * 32,
        "error": "transcription failed",
        "notification_attempted": False,
    }

    notify(job, success=False)
    notify(job, success=False)

    assert calls == 1
    assert job["notification_sent"] is False
    assert job["notification_error"] == "webhook rejected"
    assert len(context["saved"]) == 2


def test_notify_records_exec_error(monkeypatch: pytest.MonkeyPatch) -> None:
    notify, context = load_notify()

    def fake_run(args: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
        raise FileNotFoundError("harkctl missing")

    monkeypatch.setattr(context["globals"]["subprocess"], "run", fake_run)
    job = {"job_id": "c" * 32, "notification_attempted": False}

    notify(job, success=False)

    assert job["notification_sent"] is False
    assert job["notification_error"] == "harkctl missing"


def test_notify_records_nonzero_exit_without_stderr(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    notify, context = load_notify()

    def fake_run(args: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
        return subprocess.CompletedProcess(args, 7, '{"error":"unavailable"}', "")

    monkeypatch.setattr(context["globals"]["subprocess"], "run", fake_run)
    job = {"job_id": "d" * 32, "notification_attempted": False}

    notify(job, success=False)

    assert job["notification_sent"] is False
    assert job["notification_error"] == "harkctl exited with status 7"
