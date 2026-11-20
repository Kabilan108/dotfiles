import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class LeakGuards(unittest.TestCase):
    temp: tempfile.TemporaryDirectory[str]
    root: Path
    home: Path
    op_called: Path
    env: dict[str, str]

    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.op_called = self.root / "op-called"
        fake_bin = self.root / "bin"
        fake_bin.mkdir()
        op = fake_bin / "op"
        op.write_text('#!/bin/sh\nprintf called > "$OP_STUB_CALLED"\nexit 99\n')
        op.chmod(0o755)
        self.env = {
            "HOME": str(self.home),
            "PATH": str(fake_bin) + ":" + os.environ["PATH"],
            "OP_STUB_CALLED": str(self.op_called),
        }

    def tearDown(self) -> None:
        self.temp.cleanup()

    def refuse(self, *args: str, message: str) -> None:
        result = subprocess.run(
            [str(ROOT / "bin/agent-op"), *args],
            cwd=self.root,
            env=self.env,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn(message, result.stderr)
        self.assertFalse(self.op_called.exists())
        self.assertEqual(list(self.home.iterdir()), [])

    def test_env_file_cannot_expand_service_account_token(self) -> None:
        env_file = self.root / "command.env"
        env_file.write_text("X=${OP_SERVICE_ACCOUNT_TOKEN}\n")
        self.refuse(
            "run",
            f"--env-file={env_file}",
            "--",
            "true",
            message="variable expansion is not allowed",
        )

    def test_bare_command_before_separator_is_refused(self) -> None:
        self.refuse(
            "run",
            "printenv",
            "--",
            "true",
            message="is not allowed before run's '--'",
        )

    def test_env_file_flag_consumes_separator_as_value(self) -> None:
        self.refuse(
            "run",
            "--env-file",
            "--",
            "printenv",
            message="cannot read env file '--'",
        )

    def test_debug_is_refused_after_separator_consumed_as_config_value(self) -> None:
        self.refuse(
            "whoami",
            "--config",
            "--",
            "--debug",
            message="--debug is not allowed",
        )


if __name__ == "__main__":
    unittest.main()
