import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class Runs(unittest.TestCase):
    temp: tempfile.TemporaryDirectory[str]
    root: Path
    state: Path

    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.state = self.root / "state"

    def call(self, *args: str, code: int = 0) -> str:
        r = subprocess.run(
            [str(ROOT / "bin/agent-run"), "--state-dir", str(self.state), *args],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(r.returncode, code, r.stdout + r.stderr)
        return r.stdout.strip()

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_success_failure_and_ack(self) -> None:
        for name, exit_code in [("ok", 0), ("bad", 7)]:
            self.call(
                "start",
                "--provider",
                "command",
                "--repo",
                str(self.root),
                "--id",
                name,
                "--",
                "sh",
                "-c",
                f"exit {exit_code}",
            )
            result = json.loads(
                self.call("wait", name, code=0 if exit_code == 0 else 1)
            )
            self.assertEqual(result["exit_code"], exit_code)
            self.assertFalse(result["reviewed"])
            self.call("acknowledge", name)
        self.assertEqual(self.call("reconcile", "--repo", str(self.root)), "")

    def test_reconnect_and_duplicate(self) -> None:
        self.call(
            "start",
            "--provider",
            "command",
            "--repo",
            str(self.root),
            "--id",
            "persist",
            "--",
            "sleep",
            "1",
        )
        self.call("wait", "persist", "--timeout", ".05", code=124)
        self.assertEqual(
            json.loads(self.call("reconcile", "--repo", str(self.root)))["id"],
            "persist",
        )
        self.call(
            "start",
            "--provider",
            "command",
            "--repo",
            str(self.root),
            "--id",
            "persist",
            "--",
            "true",
            code=1,
        )
        self.assertEqual(json.loads(self.call("wait", "persist"))["state"], "completed")

    def test_fake_provider_missing_result_and_resume(self) -> None:
        fake = self.root / "bin"
        fake.mkdir()
        codex = fake / "codex"
        codex.write_text(
            '#!/usr/bin/env python3\nimport sys,json\nfrom pathlib import Path\na=sys.argv\nprint(json.dumps({"type":"thread.started","thread_id":"test-session"}))\nif "resume" in a: Path(a[a.index("-o")+1]).write_text("Reviewed")\n'
        )
        codex.chmod(0o755)
        old = os.environ["PATH"]
        os.environ["PATH"] = str(fake) + ":" + old
        try:
            prompt = self.root / "prompt"
            prompt.write_text("read-only test")
            self.call(
                "start",
                "--provider",
                "codex",
                "--access",
                "read-only",
                "--repo",
                str(self.root),
                "--prompt",
                str(prompt),
                "--id",
                "first",
            )
            r = json.loads(self.call("wait", "first", code=1))
            self.assertEqual(r["state"], "missing-result")
            self.assertEqual(r["exit_code"], 0)
            self.call(
                "start",
                "--resume-from",
                "first",
                "--prompt",
                str(prompt),
                "--id",
                "second",
            )
            r = json.loads(self.call("wait", "second"))
            self.assertEqual(r["resume_session"], "test-session")
            self.assertEqual(r["access"], "read-only")
        finally:
            os.environ["PATH"] = old

    def test_interrupted_recovery(self) -> None:
        import hashlib
        import time

        fake = self.root / "bin"
        fake.mkdir()
        codex = fake / "codex"
        codex.write_text(
            '#!/usr/bin/env python3\nimport sys,json,time\nfrom pathlib import Path\na=sys.argv\nprint(json.dumps({"type":"thread.started","thread_id":"recover-session"}), flush=True)\nPath(a[a.index("-o")+1]).write_text("Partial result")\nif "resume" not in a: time.sleep(60)\n'
        )
        codex.chmod(0o755)
        prompt = self.root / "prompt"
        prompt.write_text("test")
        from unittest.mock import patch

        with patch.dict(os.environ, PATH=str(fake) + ":" + os.environ["PATH"]):
            self.call(
                "start",
                "--provider",
                "codex",
                "--access",
                "read-only",
                "--repo",
                str(self.root),
                "--prompt",
                str(prompt),
                "--id",
                "killed",
            )
            for _ in range(100):
                if (self.state / "killed/result.md").exists():
                    break
                time.sleep(0.02)
            self.assertTrue((self.state / "killed/result.md").exists())
            socket = (
                "agent-run-" + hashlib.sha256(str(self.state).encode()).hexdigest()[:12]
            )
            subprocess.run(["tmux", "-L", socket, "kill-server"], check=True)
            record = json.loads(self.call("wait", "killed", code=1))
            self.assertEqual(record["state"], "interrupted")
            self.assertTrue(record["result_exists"])
            self.assertEqual(record["worker_session"], "recover-session")
            self.call("acknowledge", "killed", code=1)
            self.call(
                "start",
                "--resume-from",
                "killed",
                "--prompt",
                str(prompt),
                "--id",
                "recovered",
            )
            record = json.loads(self.call("wait", "recovered"))
            self.assertEqual(record["access"], "read-only")
            self.call("acknowledge", "killed", "--interrupted")
            self.call("acknowledge", "recovered")
            self.assertEqual(self.call("reconcile", "--repo", str(self.root)), "")

    def test_claude_result_failure_and_resume(self) -> None:
        from unittest.mock import patch

        fake = self.root / "bin"
        fake.mkdir()
        cli = fake / "claude"
        cli.write_text(
            '#!/usr/bin/env python3\nimport json,sys\nprint(json.dumps({"type":"result","session_id":"claude-session","result":"Evidence", "modelUsage":{"claude-fable-5-1":{}},"is_error":False}))\nsys.exit(0 if "--resume" in sys.argv else 7)\n'
        )
        cli.chmod(0o755)
        prompt = self.root / "prompt"
        prompt.write_text("test")
        with patch.dict(os.environ, PATH=str(fake) + ":" + os.environ["PATH"]):
            self.call(
                "start",
                "--provider",
                "claude",
                "--access",
                "plan",
                "--repo",
                str(self.root),
                "--prompt",
                str(prompt),
                "--id",
                "claude",
            )
            record = json.loads(self.call("wait", "claude", code=1))
            self.assertEqual(record["state"], "failed")
            self.assertTrue(record["result_exists"])
            self.assertEqual(record["reported_model"], "claude-fable-5-1")
            self.call(
                "start",
                "--resume-from",
                "claude",
                "--prompt",
                str(prompt),
                "--id",
                "claude-resume",
            )
            record = json.loads(self.call("wait", "claude-resume"))
            self.assertEqual(record["resume_session"], "claude-session")
            self.assertEqual(record["access"], "plan")

    def test_auto_provider_commands(self) -> None:
        import runpy

        api = runpy.run_path(str(ROOT / "bin/agent-run"))
        for provider in ["claude", "codex"]:
            for session in [None, "existing-session"]:
                record = {
                    "provider": provider,
                    "access": "auto",
                    "model": "test-model",
                    "effort": "low",
                    "resume_session": session,
                }
                command = api["provider_command"](record, self.root)
                if provider == "codex":
                    self.assertIn("--approve-for-me", command)
                    self.assertNotIn('approval_policy="never"', command)
                    self.assertNotIn('sandbox_mode="auto"', command)
                else:
                    self.assertEqual(
                        command[command.index("--permission-mode") + 1], "auto"
                    )
                if session:
                    self.assertIn(session, command)

    def test_completion_during_liveness_check(self) -> None:
        import runpy
        from unittest.mock import patch

        api = runpy.run_path(str(ROOT / "bin/agent-run"))
        folder = self.state / "race"
        folder.mkdir(parents=True)
        (folder / "run.json").write_text(
            json.dumps(
                {"state": "running", "tmux_session": "race", "provider": "command"}
            )
        )

        def finish(*args: object) -> subprocess.CompletedProcess[str]:
            api["save"](folder / "exit.json", {"state": "completed", "exit_code": 0})
            return subprocess.CompletedProcess([], 1, "", "")

        with patch.dict(api["read_record"].__globals__, tmux=finish):
            self.assertEqual(
                api["read_record"](self.state, "race")["state"], "completed"
            )

    def test_status_waits_for_launch_lock(self) -> None:
        import fcntl
        import time

        self.state.mkdir()
        folder = self.state / "launching"
        folder.mkdir()
        (folder / "run.json").write_text(
            json.dumps(
                {"state": "running", "tmux_session": "launching", "provider": "command"}
            )
        )
        with (self.state / ".start.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            process = subprocess.Popen(
                [
                    str(ROOT / "bin/agent-run"),
                    "--state-dir",
                    str(self.state),
                    "status",
                    "launching",
                ],
                stdout=subprocess.PIPE,
                text=True,
            )
            time.sleep(0.1)
            self.assertIsNone(process.poll())
            (folder / "exit.json").write_text(
                json.dumps({"state": "failed", "exit_code": None})
            )
        output, _ = process.communicate(timeout=5)
        self.assertEqual(json.loads(output)["state"], "failed")


if __name__ == "__main__":
    unittest.main()
