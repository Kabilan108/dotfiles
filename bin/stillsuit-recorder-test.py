#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import shlex
import subprocess
import sys
import tempfile
import time
from pathlib import Path

RECORDER = Path(__file__).resolve().with_name("stillsuit-recorder")

FAKE_GSR = """#!/usr/bin/env bash
set -euo pipefail
printf '%s\\n' "$*" >> "$FAKE_GSR_ARGV"
output_path=""
while (($# > 0)); do
  if [[ $1 == -o ]]; then output_path=$2; shift 2; else shift; fi
done
finish() { : > "$output_path"; exit 0; }
trap finish INT TERM
trap 'printf "pause\\n" >> "$FAKE_GSR_ARGV"' USR2
while true; do sleep 0.1; done
"""

FAKE_OMARECORD = """#!/usr/bin/env bash
set -euo pipefail
printf '%s\\n' "$*" >> "$FAKE_OMARECORD_ARGV"
case "$1" in
  select)
    case "${FAKE_SELECT_MODE:-ok}" in
      cancel) exit 1 ;;
      error) echo "selector exploded" >&2; exit 2 ;;
    esac
    printf '{"output":"DP-4","x":100,"y":-1504,"w":800,"h":400}\\n'
    ;;
  overlay)
    shift
    exec python3 "$FAKE_OVERLAY_SERVER" "$@"
    ;;
esac
"""

FAKE_OVERLAY_SERVER = """
import json, os, socket, sys
args = sys.argv[1:]
path = args[args.index("--socket") + 1]
log = open(os.environ["FAKE_OVERLAY_LOG"], "a", buffering=1)
server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
server.bind(path)
server.listen(1)
elapsed = 0
while True:
    client, _ = server.accept()
    client.sendall(b'{"event":"ready"}\\n')
    buffer = b""
    with client:
        while True:
            chunk = client.recv(4096)
            if not chunk:
                break
            buffer += chunk
            while b"\\n" in buffer:
                line, buffer = buffer.split(b"\\n", 1)
                log.write(line.decode() + "\\n")
                message = json.loads(line)
                if message.get("cmd") == "quit":
                    sys.exit(0)
                if message.get("cmd") == "elapsed":
                    elapsed += 1
                    if elapsed == 2 and os.environ.get("FAKE_OVERLAY_STOP", "1") == "1":
                        client.sendall(b'{"event":"stop"}\\n')
"""

FAKE_FFMPEG = """#!/usr/bin/env bash
set -euo pipefail
printf '%s\\n' "$*" >> "$FAKE_FFMPEG_ARGV"
eval "last=\\${$#}"
: > "$last"
"""


def check(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)
    print(f"ok - {message}")


class Harness:
    def __init__(self, root: Path) -> None:
        self.root = root
        self.bin = root / "bin"
        self.runtime = root / "runtime"
        self.recordings = root / "recordings"
        for path in (self.bin, self.runtime, self.recordings):
            path.mkdir(parents=True)
        self.runtime.chmod(0o700)
        self.gsr_argv = root / "gsr-argv.log"
        self.omarecord_argv = root / "omarecord-argv.log"
        self.overlay_log = root / "overlay.log"
        self.ffmpeg_argv = root / "ffmpeg-argv.log"
        overlay_server = root / "overlay-server.py"
        overlay_server.write_text(FAKE_OVERLAY_SERVER)
        for name, body in (
            ("gpu-screen-recorder", FAKE_GSR),
            ("omarecord", FAKE_OMARECORD),
            ("ffmpeg", FAKE_FFMPEG),
        ):
            script = self.bin / name
            script.write_text(body)
            script.chmod(0o755)
        self.env = {
            **os.environ,
            "PATH": f"{self.bin}:{os.environ['PATH']}",
            "XDG_RUNTIME_DIR": str(self.runtime),
            "FAKE_GSR_ARGV": str(self.gsr_argv),
            "FAKE_OMARECORD_ARGV": str(self.omarecord_argv),
            "FAKE_OVERLAY_LOG": str(self.overlay_log),
            "FAKE_OVERLAY_SERVER": str(overlay_server),
            "FAKE_FFMPEG_ARGV": str(self.ffmpeg_argv),
        }

    def run(self, *args: str, expect: int = 0, **env: str) -> dict:
        result = subprocess.run(
            [sys.executable, str(RECORDER), *args],
            capture_output=True,
            text=True,
            env={**self.env, **env},
            check=False,
        )
        print(f"$ stillsuit-recorder {shlex.join(args)} -> {result.returncode}")
        print(f"  {result.stdout.strip()}")
        if result.stderr.strip():
            print(f"  stderr: {result.stderr.strip()}")
        check(result.returncode == expect, f"exit code {expect}")
        return json.loads(result.stdout)

    def state(self) -> dict:
        return json.loads((self.runtime / "stillsuit/recording.json").read_text())

    def overlay_lines(self) -> list[dict]:
        if not self.overlay_log.exists():
            return []
        return [json.loads(line) for line in self.overlay_log.read_text().splitlines()]

    def reset_logs(self) -> None:
        for path in (
            self.gsr_argv,
            self.omarecord_argv,
            self.overlay_log,
            self.ffmpeg_argv,
        ):
            path.unlink(missing_ok=True)


def alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except (ProcessLookupError, PermissionError):
        return False
    return True


def wait_for(predicate, timeout: float, message: str) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            check(True, message)
            return
        time.sleep(0.1)
    raise AssertionError(f"timed out: {message}")


def test_monitor_argv_unchanged(h: Harness) -> None:
    h.reset_logs()
    started = h.run(
        "start",
        "--directory",
        str(h.recordings),
        "--monitor",
        "DP-1",
        "--title",
        "monitor test",
        "--desktop-audio",
        "--no-microphone",
    )
    argv = h.gsr_argv.read_text().strip()
    expected = (
        f"-w DP-1 -f 30 -k h264 -q high -fm vfr -cursor yes -a default_output "
        f"-o {h.recordings}/monitor test.mp4"
    )
    check(argv == expected, "monitor gsr argv identical to previous behaviour")
    check(
        started["target"] == "monitor" and started["annotate"] is False,
        "monitor state defaults",
    )
    check(
        started["overlay_pid"] == 0 and started["relay_pid"] == 0,
        "no overlay for monitor",
    )
    check(not h.omarecord_argv.exists(), "omarecord not invoked for monitor")
    stopped = h.run("stop")
    check(stopped["phase"] == "completed", "monitor stop completed")
    h.run("dismiss")

    h.reset_logs()
    h.run(
        "start",
        "--directory",
        str(h.recordings),
        "--monitor",
        "DP-1",
        "--title",
        "monitor defaults",
    )
    argv = h.gsr_argv.read_text().strip()
    check("-a default_output|default_input" in argv, "monitor audio defaults both on")
    h.run("cancel")


def test_region_annotate(h: Harness) -> None:
    h.reset_logs()
    started = h.run(
        "start",
        "--target",
        "region",
        "--annotate",
        "--directory",
        str(h.recordings),
        "--monitor",
        "DP-4",
        "--title",
        "region test",
    )
    check(started["target"] == "region", "target recorded")
    check(
        started["rect"] == {"output": "DP-4", "x": 100, "y": -1504, "w": 800, "h": 400},
        "rect recorded",
    )
    check(started["annotate"] is True, "annotate recorded")
    check(
        started["overlay_pid"] > 0 and alive(started["overlay_pid"]), "overlay_pid live"
    )
    check(started["relay_pid"] > 0 and alive(started["relay_pid"]), "relay_pid live")
    check(
        started["overlay_socket"] == f"{h.runtime}/stillsuit/overlay.sock",
        "overlay_socket recorded",
    )
    check(
        started["desktop_audio"] is False and started["microphone"] is False,
        "region audio defaults off",
    )
    argv = h.gsr_argv.read_text().strip()
    check(argv.startswith("-w 800x400+100+-1504 "), f"gsr got -w geometry: {argv}")
    check(" -a " not in argv, "no audio flag for region")
    omarecord = h.omarecord_argv.read_text().splitlines()
    check(omarecord[0] == "select --mode region --output DP-4", "select invoked")
    check(
        omarecord[1]
        == f"overlay --output DP-4 --rect 800x400+100+-1504 --socket {h.runtime}/stillsuit/overlay.sock",
        "overlay invoked",
    )

    wait_for(
        lambda: h.state().get("phase") == "completed",
        6,
        "overlay stop event completed recording",
    )
    lines = h.overlay_lines()
    elapsed = [m for m in lines if m.get("cmd") == "elapsed"]
    check(len(elapsed) >= 2, f"relay forwarded elapsed ({len(elapsed)})")
    check(
        any(m == {"cmd": "paused", "value": False} for m in lines),
        "relay forwarded initial paused=false",
    )
    check(lines[-1] == {"cmd": "quit"}, "overlay received quit last")
    wait_for(lambda: not alive(started["overlay_pid"]), 3, "overlay exited")
    wait_for(lambda: not alive(started["relay_pid"]), 3, "relay exited")
    final = h.state()
    check(
        "overlay_pid" not in final and "relay_pid" not in final,
        "pids cleared from state",
    )
    check(Path(final["output"]).is_file(), "recording file exists")
    relay_log = (h.runtime / "stillsuit/relay.log").read_text()
    check('"phase":"completed"' in relay_log, "relay logged in-process stop result")


def test_region_pause_and_cancel(h: Harness) -> None:
    h.reset_logs()
    started = h.run(
        "start",
        "--target",
        "window",
        "--directory",
        str(h.recordings),
        "--monitor",
        "DP-4",
        "--title",
        "window test",
        "--microphone",
        FAKE_OVERLAY_STOP="0",
    )
    check(started["annotate"] is True, "window implies annotate")
    check(
        started["microphone"] is True and started["desktop_audio"] is False,
        "explicit mic honoured",
    )
    paused = h.run("toggle-pause", FAKE_OVERLAY_STOP="0")
    check(paused["phase"] == "paused", "toggle-pause paused")
    wait_for(
        lambda: {"cmd": "paused", "value": True} in h.overlay_lines(),
        2,
        "relay forwarded paused=true after external toggle",
    )
    check("pause" in h.gsr_argv.read_text(), "gsr got SIGUSR2")
    h.run("cancel", FAKE_OVERLAY_STOP="0")
    wait_for(lambda: h.overlay_lines()[-1] == {"cmd": "quit"}, 2, "cancel sent quit")
    wait_for(
        lambda: not alive(started["overlay_pid"]) and not alive(started["relay_pid"]),
        3,
        "cancel cleaned up overlay and relay",
    )
    check(not (h.runtime / "stillsuit/recording.json").exists(), "cancel removed state")

    state_path = h.runtime / "stillsuit/recording.json"
    output = h.recordings / "cancelled.mp4"
    output.write_bytes(b"x")
    state_path.write_text(
        json.dumps(
            {
                "schemaVersion": 1,
                "phase": "recording",
                "pid": 999999,
                "output": str(output),
                "started_at": time.time(),
                "cancelling": True,
            }
        )
    )
    check(
        h.run("status")["phase"] == "idle",
        "dead gsr under a pending cancel reads as idle, not completed",
    )
    check(not output.exists() and not state_path.exists(), "pending cancel discards file and state")


def test_select_cancel_and_error(h: Harness) -> None:
    h.reset_logs()
    idle = h.run(
        "start",
        "--target",
        "region",
        "--directory",
        str(h.recordings),
        "--monitor",
        "DP-4",
        "--title",
        "cancelled",
        FAKE_SELECT_MODE="cancel",
    )
    check(idle["phase"] == "idle", "selector cancel yields idle")
    check(not h.gsr_argv.exists(), "gsr not started on cancel")
    errored = h.run(
        "start",
        "--target",
        "region",
        "--directory",
        str(h.recordings),
        "--monitor",
        "DP-4",
        "--title",
        "errored",
        FAKE_SELECT_MODE="error",
        expect=1,
    )
    check(
        errored["phase"] == "error" and errored["error"] == "selector exploded",
        "selector error surfaces stderr",
    )
    h.run("dismiss")


def test_export(h: Harness) -> None:
    h.reset_logs()
    h.run(
        "start",
        "--directory",
        str(h.recordings),
        "--monitor",
        "DP-1",
        "--title",
        "export test",
    )
    stopped = h.run("stop")
    check(stopped["phase"] == "completed", "completed before export")
    exported = h.run("export", "--format", "gif")
    check(
        exported["export"]["phase"] == "running"
        and exported["export"]["format"] == "gif",
        "export running",
    )
    check(
        exported["export"]["output"] == f"{h.recordings}/export test.gif",
        "export output path",
    )
    wait_for(
        lambda: h.run("status")["export"]["phase"] == "completed",
        5,
        "export completed via status",
    )
    ffmpeg_calls = h.ffmpeg_argv.read_text().splitlines()
    check(
        len(ffmpeg_calls) == 2
        and "palettegen" in ffmpeg_calls[0]
        and "paletteuse" in ffmpeg_calls[1],
        "gif two-pass ffmpeg",
    )
    check(not (h.recordings / "export test.palette.png").exists(), "palette cleaned up")
    webm = h.run("export", "--format", "webm")
    wait_for(
        lambda: h.run("status")["export"]["phase"] == "completed",
        5,
        "webm export completed",
    )
    check(
        "-c:v libvpx-vp9 -b:v 0 -crf 32 -row-mt 1"
        in h.ffmpeg_argv.read_text().splitlines()[-1],
        "webm flags",
    )
    check(webm["export"]["output"].endswith("export test.webm"), "webm output path")
    h.run("dismiss")
    h.run("export", "--format", "gif", expect=1)


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="stillsuit-recorder-test.") as tmp:
        h = Harness(Path(tmp))
        for test in (
            test_monitor_argv_unchanged,
            test_region_annotate,
            test_region_pause_and_cancel,
            test_select_cancel_and_error,
            test_export,
        ):
            print(f"--- {test.__name__}")
            test(h)
    print("stillsuit-recorder-test: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
