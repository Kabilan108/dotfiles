from __future__ import annotations

import importlib.machinery
import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader("flake_update_pr", str(ROOT / "bin/flake-update-pr"))
spec = importlib.util.spec_from_loader(loader.name, loader)
assert spec is not None
job = importlib.util.module_from_spec(spec)
sys.modules[loader.name] = job
loader.exec_module(job)

OLD = "3ec636362e1816bc2f0888fa0fa2c69f1bc9e504"
NEW = "1c89083e451e891152365b799595cf7790a43325"
UPDATE_LOG = f"""\
$ nix flake update
warning: updating lock file "/tmp/x/flake.lock":
• Updated input 'nixpkgs':
    'github:NixOS/nixpkgs/{OLD}?narHash=sha256-a%3D' (2026-10-23)
  → 'github:NixOS/nixpkgs/{NEW}?narHash=sha256-b%3D' (2026-10-30)
• Updated input 'firefox-addons':
    'gitlab:rycee/nur-expressions/0c43?dir=pkgs/firefox-addons&narHash=sha256-c%3D' (2026-10-01)
  → 'gitlab:rycee/nur-expressions/8172?dir=pkgs/firefox-addons&narHash=sha256-d%3D' (2026-11-01)
• Added input 'niri-flake/extra':
    'github:o/r/{NEW}?narHash=sha256-e%3D' (2026-10-30)
• Removed input 'stale'

exit 0
"""


class FlakeUpdatePr(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.dir = Path(self.temp.name)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def write(self, name: str, text: str) -> Path:
        path = self.dir / name
        path.write_text(text)
        return path

    def test_parses_updated_and_added_inputs(self) -> None:
        changes = job.input_changes(self.write("update.log", UPDATE_LOG))
        self.assertEqual([c.name for c in changes], ["nixpkgs", "firefox-addons", "niri-flake/extra"])
        table = job.changes_table("flake.lock", changes)
        self.assertIn(f"`NixOS/nixpkgs@{NEW[:9]}` 2026-10-30", table)
        self.assertIn(f"https://github.com/NixOS/nixpkgs/compare/{OLD}...{NEW}", table)
        self.assertIn("`gitlab:rycee/nur-expressions/8172` 2026-11-01", table)
        self.assertIn("| `niri-flake/extra` | (new) |", table)

    def test_build_is_skipped_once_the_budget_is_spent(self) -> None:
        saved = job.deadline
        job.deadline = 0.0
        try:
            step = job.build_step(["false"], self.dir / "build.log")
        finally:
            job.deadline = saved
        self.assertFalse(step.ok)
        self.assertIn("build budget is used up", (self.dir / "build.log").read_text())

    def test_strips_colour_codes(self) -> None:
        self.assertEqual(job.ANSI_RE.sub("", "btop: 1.4.7 \u2192 1.4.8, \x1b[32;1m-52.6 KiB\x1b[0m"), "btop: 1.4.7 \u2192 1.4.8, -52.6 KiB")

    def test_failed_build_is_reported_with_its_error(self) -> None:
        log = self.write(
            "build-sietch.log",
            "building...\nerror: packages/security-overrides.nix: nixpkgs now ships bun 1.4.5; remove the 1.4.4 override\n",
        )
        ok_log = self.write("build-jacurutu.log", "")
        builds = [
            job.Build("sietch", job.Step(False, log, ""), "/run/current-system", None),
            job.Build("jacurutu", job.Step(True, ok_log, "/nix/store/x-new"), "/nix/store/x-old", "", retried=log),
        ]
        body = job.render_body(
            ok=False,
            repo="o/r",
            branch="auto/flake-update-2026-11-01",
            base="nixos",
            base_sha=OLD,
            root_changes=job.input_changes(self.write("update.log", UPDATE_LOG)),
            raspi_changes=[],
            builds=builds,
            old_notes={"sietch": "the running system", "jacurutu": "the base branch build"},
            tleilax=job.Step(True, ok_log, "/nix/store/t.drv"),
            run_dir=self.dir,
        )
        self.assertIn("**Build failing.**", body)
        self.assertIn("| sietch toplevel | **failed** |", body)
        self.assertIn("nixpkgs now ships bun 1.4.5", body)
        self.assertIn("that override can go", body)
        self.assertIn("jacurutu vs the base branch build", body)
        self.assertIn("(first attempt failed, retry passed; first log", body)
        self.assertIn("bin/flake-lock-verify auto/flake-update-2026-11-01", body)


if __name__ == "__main__":
    unittest.main()
