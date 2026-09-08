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


if __name__ == "__main__":
    unittest.main()
