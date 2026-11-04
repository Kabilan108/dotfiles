"""SSH routing in bin/sessionizer.py.

A fake ssh on PATH records each call's arguments. Hosts in the fleet hosts
file marked "gated" refuse the agent key for everything but the inventory, so
sessionizer must preview over an existing login master and create sessions
over the login connection.
"""

import contextlib
import importlib.util
import io
import json
import os
import shutil
import socket
import stat
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Any
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]

FAKE_SSH = """#!{python}
import json, os, sys
args = sys.argv[1:]
with open(os.environ["FAKE_SSH_LOG"], "a") as log:
    log.write(json.dumps(args) + "\\n")
if args[:2] == ["-O", "check"]:
    sys.exit(0 if os.environ.get("FAKE_SSH_MASTER") == "1" else 255)
remote = args[-1]
if "--inventory" in remote:
    print(json.dumps({{"sessions": [], "directories": []}}))
elif "--ensure-directory-session" in remote:
    print("$7")
elif "--preview-directory" in remote:
    print("remote listing")
elif "list-panes" in remote:
    print("\\x1f".join(["0", "main", "1", "0", "1", "42", "bash", "/home/k", "t"]))
"""

HOSTS = (
    "sietch\t#cba6f7\t100.71.183.33\tungated\ntleilax\t#a6e3a1\t100.73.84.103\tgated\n"
)


def load_sessionizer() -> Any:
    spec = importlib.util.spec_from_file_location(
        "sessionizer", ROOT / "bin" / "sessionizer.py"
    )
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


class SessionizerSshRouting(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp(prefix="sessionizer-test-"))
        self.addCleanup(shutil.rmtree, self.tmp)
        bin_dir = self.tmp / "bin"
        bin_dir.mkdir()
        ssh = bin_dir / "ssh"
        ssh.write_text(FAKE_SSH.format(python=sys.executable))
        ssh.chmod(ssh.stat().st_mode | stat.S_IXUSR)
        home = self.tmp / "home"
        (home / ".ssh").mkdir(parents=True)
        (home / ".ssh" / f"agent-{socket.gethostname()}").write_text("")
        self.log = self.tmp / "ssh.log"
        environment = {
            "PATH": f"{bin_dir}:{os.environ['PATH']}",
            "HOME": str(home),
            "FAKE_SSH_LOG": str(self.log),
            "FAKE_SSH_MASTER": "0",
        }
        patcher = mock.patch.dict(os.environ, environment)
        patcher.start()
        self.addCleanup(patcher.stop)

        self.s = load_sessionizer()
        self.s.FLEET_HOSTS_PATH = self.tmp / "hosts"
        self.s.FLEET_HOSTS_PATH.write_text(HOSTS)
        self.s.REMOTE_CACHE_DIR = self.tmp / "cache"

    def calls(self) -> list[list[str]]:
        if not self.log.exists():
            return []
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def destinations(self) -> list[str]:
        return [
            call[-2] if call[:2] != ["-O", "check"] else "check:" + call[-1]
            for call in self.calls()
        ]

    def candidate(self, host: str, kind: str):
        session = kind == "remote"
        return self.s.Candidate(
            identity=f"{kind}:{host}:x",
            kind=kind,
            name="x",
            target="$1" if session else "/home/k/project",
            detail="1 win" if session else "/home/k/project",
            host=host,
            color="#a6e3a1",
            path="/home/k/project",
        )

    def preview(self, candidate) -> str:
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            self.s.preview(candidate)
        return output.getvalue()

    def test_hosts_file_marks_gated_hosts(self) -> None:
        hosts = {host.name: host.gated for host in self.s.fleet_hosts()}
        self.assertEqual(hosts, {"sietch": False, "tleilax": True})

    def test_older_three_field_hosts_file_still_parses(self) -> None:
        self.s.FLEET_HOSTS_PATH.write_text("tleilax\t#a6e3a1\t100.73.84.103\n")
        hosts = self.s.fleet_hosts(("tleilax",))
        self.assertEqual(
            [(host.name, host.gated) for host in hosts], [("tleilax", False)]
        )

    def test_gated_inventory_uses_agent_key(self) -> None:
        host = self.s.fleet_hosts(("tleilax",))[0]
        self.s.refresh_remote_host(host)
        self.assertEqual(self.destinations(), ["tleilax-agent"])
        self.assertEqual(self.calls()[0][-1], '"$HOME/bin/sessionizer" --inventory')

    def test_gated_previews_without_master_show_hint_only(self) -> None:
        for kind in ("remote", "remote-directory"):
            with self.subTest(kind=kind):
                self.log.unlink(missing_ok=True)
                output = self.preview(self.candidate("tleilax", kind))
                self.assertEqual(self.destinations(), ["check:tleilax"])
                self.assertIn("attach to tleilax once to enable previews", output)

    def test_gated_previews_with_master_use_login_connection(self) -> None:
        os.environ["FAKE_SSH_MASTER"] = "1"
        for kind, expected in (
            ("remote", "main"),
            ("remote-directory", "remote listing"),
        ):
            with self.subTest(kind=kind):
                self.log.unlink(missing_ok=True)
                output = self.preview(self.candidate("tleilax", kind))
                self.assertEqual(self.destinations(), ["check:tleilax", "tleilax"])
                preview_call = self.calls()[1]
                self.assertIn("PubkeyAuthentication=no", preview_call)
                self.assertIn("ControlMaster=no", preview_call)
                self.assertIn(expected, output)

    def test_gated_creation_uses_login_connection(self) -> None:
        created = self.s.ensure_remote_directory_session(
            self.candidate("tleilax", "remote-directory")
        )
        self.assertEqual(self.destinations(), ["tleilax"])
        self.assertNotIn("BatchMode=yes", self.calls()[0])
        self.assertEqual(
            self.calls()[0][-1],
            '"$HOME/bin/sessionizer" --ensure-directory-session /home/k/project',
        )
        self.assertEqual(
            (created.kind, created.host, created.target), ("remote", "tleilax", "$7")
        )

    def test_ungated_host_uses_agent_key_for_everything(self) -> None:
        os.environ["FAKE_SSH_MASTER"] = "1"
        self.s.refresh_remote_host(self.s.fleet_hosts(("sietch",))[0])
        self.preview(self.candidate("sietch", "remote"))
        self.preview(self.candidate("sietch", "remote-directory"))
        self.s.ensure_remote_directory_session(
            self.candidate("sietch", "remote-directory")
        )
        self.assertEqual(self.destinations(), ["sietch-agent"] * 4)

    def test_attach_uses_login_connection(self) -> None:
        for host in ("sietch", "tleilax"):
            with self.subTest(host=host):
                self.log.unlink(missing_ok=True)
                self.assertEqual(self.s.attach_remote(host, "$1"), 0)
                self.assertEqual(self.calls()[0][:2], ["-t", host])

    def test_depth_zero_offers_the_search_path_itself(self) -> None:
        root = self.tmp / "home"
        (root / "child").mkdir()
        config = self.s.Config((str(root),), 0, (), ())
        paths = [
            candidate.path for candidate in self.s.directory_candidates(config, [])
        ]
        self.assertEqual(paths, [str(root.resolve())])


if __name__ == "__main__":
    unittest.main()
