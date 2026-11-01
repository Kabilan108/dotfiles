from __future__ import annotations

import json
import os
import runpy
import shutil
import subprocess
import sys
import threading
from pathlib import Path
from typing import Any

import pytest

ROOT = Path(__file__).parents[1]
MINUTES = ROOT / "bin" / "meeting-minutes"
RECORDER = ROOT / "bin" / "stillsuit-recorder"

SPLIT_LAYOUT = [
    {"index": 0, "role": "mixed", "sources": ["default_output", "default_input"]},
    {"index": 1, "role": "desktop", "sources": ["default_output"]},
    {"index": 2, "role": "microphone", "sources": ["default_input"]},
]

needs_ffmpeg = pytest.mark.skipif(
    shutil.which("ffmpeg") is None or shutil.which("ffprobe") is None,
    reason="ffmpeg is not installed",
)


def minutes_env(tmp_path: Path) -> dict[str, str]:
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    systemctl = bin_dir / "systemctl"
    systemctl.write_text(
        f'#!/usr/bin/env bash\necho "$*" >> {tmp_path}/systemctl.log\n'
    )
    systemctl.chmod(0o755)
    env = os.environ.copy()
    env.update(
        {
            "PATH": f"{bin_dir}:{env['PATH']}",
            "COPPERMIND_VAULT": str(tmp_path / "vault"),
            "MEETING_MINUTES_MEDIA_ROOT": str(tmp_path / "media"),
            "MEETING_MINUTES_MEDIA_REFERENCE_ROOT": str(tmp_path / "reference"),
            "MEETING_MINUTES_STATE_DIR": str(tmp_path / "state"),
        }
    )
    return env


def load(
    script: Path, env: dict[str, str], monkeypatch: pytest.MonkeyPatch
) -> dict[str, Any]:
    for name, value in env.items():
        monkeypatch.setenv(name, value)
    return runpy.run_path(str(script))


def recorder(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> dict[str, Any]:
    monkeypatch.setenv("XDG_RUNTIME_DIR", str(tmp_path / "runtime"))
    return runpy.run_path(str(RECORDER))


@pytest.mark.parametrize(
    ("desktop", "microphone", "arguments", "roles"),
    [
        (
            True,
            True,
            [
                "-a",
                "default_output|default_input",
                "-a",
                "default_output",
                "-a",
                "default_input",
            ],
            ["mixed", "desktop", "microphone"],
        ),
        (True, False, ["-a", "default_output"], ["desktop"]),
        (False, True, ["-a", "default_input"], ["microphone"]),
        (False, False, [], []),
    ],
)
def test_recorder_writes_one_track_per_source_plus_the_mix(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    desktop: bool,
    microphone: bool,
    arguments: list[str],
    roles: list[str],
) -> None:
    namespace = recorder(tmp_path, monkeypatch)
    tracks = namespace["audio_tracks"](desktop_audio=desktop, microphone=microphone)
    command = namespace["capture_command"]("DP-1", tracks, tmp_path / "out.mp4")

    assert [track["role"] for track in tracks] == roles
    assert [track["index"] for track in tracks] == list(range(len(roles)))
    audio = [
        value
        for position, value in enumerate(command)
        if value == "-a" or (position and command[position - 1] == "-a")
    ]
    assert audio == arguments
    assert command[:3] == ["gpu-screen-recorder", "-w", "DP-1"]
    assert command[-2:] == ["-o", str(tmp_path / "out.mp4")]
    if desktop and microphone:
        assert tracks == SPLIT_LAYOUT


def test_recorder_passes_the_track_layout_to_the_meeting_queue(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    namespace = recorder(tmp_path, monkeypatch)
    output = tmp_path / "meeting.mp4"
    output.write_bytes(b"video")
    helper = tmp_path / "meeting-minutes"
    helper.write_text(
        "#!/usr/bin/env python3\n"
        "import json, sys\n"
        f"open({str(tmp_path / 'enqueue.json')!r}, 'w').write(json.dumps(sys.argv[1:]))\n"
        'print(json.dumps({"job_id": "job", "recording": sys.argv[3]}))\n'
    )
    helper.chmod(0o755)
    capture = subprocess.Popen(["sleep", "30"])
    reaper = threading.Thread(target=capture.wait, daemon=True)
    reaper.start()
    try:
        namespace["write_state"](
            {
                "phase": "recording",
                "pid": capture.pid,
                "output": str(output),
                "started_at": 1_791_911_433.0,
                "paused": False,
                "paused_total": 0,
                "audio_tracks": SPLIT_LAYOUT,
            }
        )
        monkeypatch.setitem(
            namespace["stop_recording"].__globals__, "MEETING_HELPER", helper
        )
        namespace["stop_recording"](meeting=True)
    finally:
        capture.kill()
        capture.wait()

    arguments = json.loads((tmp_path / "enqueue.json").read_text())
    assert arguments[:3] == ["enqueue", "--recording", str(output)]
    assert json.loads(arguments[arguments.index("--audio-tracks") + 1]) == SPLIT_LAYOUT
    assert namespace["read_state"]()["phase"] == "meeting_queued"


def test_enqueue_records_a_valid_layout_and_ignores_a_broken_one(
    tmp_path: Path,
) -> None:
    env = minutes_env(tmp_path)
    jobs = tmp_path / "state/jobs"

    def enqueue(name: str, *layout: str) -> dict[str, Any]:
        recording = tmp_path / name
        recording.write_bytes(b"video")
        queued = subprocess.run(
            [
                sys.executable,
                str(MINUTES),
                "enqueue",
                "--recording",
                str(recording),
                *layout,
            ],
            check=True,
            capture_output=True,
            text=True,
            env=env,
        )
        job_id = json.loads(queued.stdout)["job_id"]
        return json.loads((jobs / f"{job_id}.json").read_text())

    assert (
        enqueue("split.mp4", "--audio-tracks", json.dumps(SPLIT_LAYOUT))["audio_tracks"]
        == SPLIT_LAYOUT
    )
    legacy = enqueue("legacy.mp4")
    assert "audio_tracks" not in legacy
    broken = enqueue(
        "broken.mp4", "--audio-tracks", json.dumps([SPLIT_LAYOUT[1], SPLIT_LAYOUT[1]])
    )
    assert broken["audio_tracks"] == []
    assert "repeats an index or role" in broken["audio_tracks_error"]
    assert "meeting-minutes-worker.service" in (tmp_path / "systemctl.log").read_text()


def test_layout_validation_and_track_command(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    namespace = load(MINUTES, minutes_env(tmp_path), monkeypatch)
    parse = namespace["parse_audio_tracks"]
    error = namespace["MeetingMinutesError"]

    assert parse(json.dumps(list(reversed(SPLIT_LAYOUT)))) == SPLIT_LAYOUT
    for broken in (
        "not json",
        "{}",
        json.dumps([{"index": "1", "role": "desktop", "sources": []}]),
        json.dumps([{"index": True, "role": "desktop", "sources": []}]),
        json.dumps([{"index": 0, "role": "speakers", "sources": []}]),
        json.dumps([{"index": 0, "role": "desktop", "sources": "default_output"}]),
    ):
        with pytest.raises(error):
            parse(broken)

    assert namespace["source_track_command"](
        Path("/r.mp4"), 2, Path("/w/microphone.mka")
    ) == [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-i",
        "/r.mp4",
        "-map",
        "0:a:2",
        "-c:a",
        "copy",
        "-vn",
        "/w/microphone.mka",
    ]


def synthetic_recording(path: Path, durations: list[float]) -> Path:
    """A short H.264 + Opus MP4 with one audio stream per duration, so each
    extracted track can be told apart by its length."""
    command = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y"]
    command += ["-f", "lavfi", "-i", "testsrc=duration=3:size=64x64:rate=10"]
    for index, duration in enumerate(durations):
        command += [
            "-f",
            "lavfi",
            "-i",
            f"sine=frequency={300 * (index + 1)}:duration={duration}",
        ]
    for index in range(len(durations) + 1):
        command += ["-map", str(index)]
    command += ["-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "libopus", str(path)]
    subprocess.run(command, check=True)
    return path


def stream_summary(path: Path) -> list[tuple[str, float]]:
    probed = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "stream=codec_type:format=duration",
            "-of",
            "json",
            str(path),
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    data = json.loads(probed.stdout)
    duration = float(data["format"]["duration"])
    return [(stream["codec_type"], duration) for stream in data["streams"]]


@needs_ffmpeg
def test_split_recordings_extract_desktop_and_microphone_tracks(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    env = minutes_env(tmp_path)
    namespace = load(MINUTES, env, monkeypatch)
    monkeypatch.setitem(
        namespace["extract_source_tracks"].__globals__, "save_job", lambda job: None
    )
    recording = synthetic_recording(tmp_path / "split.mp4", [3, 2, 1])
    job: dict[str, Any] = {
        "job_id": "a" * 32,
        "recording_path": str(recording),
        "audio_tracks": SPLIT_LAYOUT,
    }

    tracks = namespace["extract_source_tracks"](job)

    work = tmp_path / "media/.work" / ("a" * 32)
    assert tracks == {
        "desktop": str(work / "desktop.mka"),
        "microphone": str(work / "microphone.mka"),
    }
    assert job["source_tracks"] == tracks
    desktop = stream_summary(work / "desktop.mka")
    microphone = stream_summary(work / "microphone.mka")
    assert [kind for kind, _ in desktop] == ["audio"]
    assert desktop[0][1] == pytest.approx(2, abs=0.1)
    assert microphone[0][1] == pytest.approx(1, abs=0.1)

    upload = namespace["prepare_upload_audio"](job)
    assert namespace["probe_duration"](upload) == pytest.approx(3, abs=0.1)


@needs_ffmpeg
def test_legacy_and_mismatched_recordings_are_not_split(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    namespace = load(MINUTES, minutes_env(tmp_path), monkeypatch)
    monkeypatch.setitem(
        namespace["extract_source_tracks"].__globals__, "save_job", lambda job: None
    )
    recording = synthetic_recording(tmp_path / "legacy.mp4", [3])

    for layout in (
        None,
        [],
        [{"index": 0, "role": "desktop", "sources": ["default_output"]}],
    ):
        job: dict[str, Any] = {"job_id": "b" * 32, "recording_path": str(recording)}
        if layout is not None:
            job["audio_tracks"] = layout
        assert namespace["extract_source_tracks"](job) == {}
        assert "source_tracks" not in job

    upload = namespace["prepare_upload_audio"](
        {"job_id": "b" * 32, "recording_path": str(recording)}
    )
    assert namespace["probe_duration"](upload) == pytest.approx(3, abs=0.1)

    mismatched = {
        "job_id": "c" * 32,
        "recording_path": str(recording),
        "audio_tracks": SPLIT_LAYOUT,
    }
    with pytest.raises(
        namespace["MeetingMinutesError"], match="1 audio streams; its layout declares 3"
    ):
        namespace["extract_source_tracks"](mismatched)


def test_published_tracks_sit_next_to_the_transcript_and_sync_with_the_recording(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    env = minutes_env(tmp_path)
    destination = tmp_path / "sietch"
    destination.mkdir()
    env["MEETING_MINUTES_SYNC_DESTINATION"] = str(destination)
    namespace = load(MINUTES, env, monkeypatch)
    monkeypatch.setitem(
        namespace["publish_source_tracks"].__globals__, "save_job", lambda job: None
    )
    media = tmp_path / "media"
    work = media / ".work/job"
    work.mkdir(parents=True)
    (work / "desktop.mka").write_bytes(b"desktop")
    (work / "microphone.mka").write_bytes(b"microphone")
    job: dict[str, Any] = {
        "source_tracks": {
            "desktop": str(work / "desktop.mka"),
            "microphone": str(work / "microphone.mka"),
        }
    }

    published = namespace["publish_source_tracks"](job, "2026-10-13-moberg-review")

    assert published == {
        "desktop": str(media / "2026-10-13-moberg-review.desktop.mka"),
        "microphone": str(media / "2026-10-13-moberg-review.microphone.mka"),
    }
    assert job["source_tracks"] == published
    assert namespace["publish_source_tracks"]({}, "legacy") == {}

    jobs = tmp_path / "state/jobs"
    jobs.mkdir(parents=True)
    (media / "pending.desktop.mka").write_bytes(b"pending")
    (jobs / "pending.json").write_text(
        json.dumps({"phase": "writing", "canonical_stem": "pending"})
    )
    subprocess.run(
        [sys.executable, str(MINUTES), "sync-artifacts"], check=True, env=env
    )

    assert (
        destination / "2026-10-13-moberg-review.desktop.mka"
    ).read_bytes() == b"desktop"
    assert not (media / "2026-10-13-moberg-review.desktop.mka").exists()
    assert (media / "pending.desktop.mka").is_file()
    assert not (destination / "pending.desktop.mka").exists()
