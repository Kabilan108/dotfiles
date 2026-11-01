from __future__ import annotations

import copy
import hashlib
import json
import os
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "bin/flake-lock-verify"


def sha(name: str) -> str:
    return hashlib.sha1(name.encode()).hexdigest()


def nar(rev: str) -> str:
    return f"sha256-{rev[:12]}"


FAKE_GH = textwrap.dedent(
    """\
    #!/usr/bin/env python3
    import json, os, sys, urllib.parse

    forge = json.load(open(os.environ["FAKE_FORGE"]))
    with open(os.environ["FAKE_LOG"], "a") as log:
        log.write("gh " + " ".join(sys.argv[1:]) + "\\n")
    args = sys.argv[1:]
    if args[:2] == ["pr", "view"]:
        print(json.dumps(forge["pr"]))
        sys.exit(0)
    path = args[1].split("?")[0].split("/")
    repo = forge["repos"].get(f"{path[1]}/{path[2]}".lower())
    if repo is None:
        print("gh: Not Found (HTTP 404)", file=sys.stderr)
        sys.exit(1)
    if len(path) == 3:
        print(json.dumps({"default_branch": repo["default_branch"]}))
        sys.exit(0)
    base, head = urllib.parse.unquote("/".join(path[4:])).split("...")
    parents = repo["parents"]

    def commit(ref):
        sha = repo["refs"].get(ref, ref)
        if sha not in parents:
            print("gh: No commit found (HTTP 404)", file=sys.stderr)
            sys.exit(1)
        return sha

    def ancestors(sha):
        seen, todo = set(), [sha]
        while todo:
            current = todo.pop()
            if current not in seen:
                seen.add(current)
                todo.extend(parents[current])
        return seen

    base, head = commit(base), commit(head)
    if base == head:
        status = "identical"
    elif base in ancestors(head):
        status = "ahead"
    elif head in ancestors(base):
        status = "behind"
    else:
        status = "diverged"
    print(json.dumps({"status": status}))
    """
)

FAKE_NIX = textwrap.dedent(
    """\
    #!/usr/bin/env python3
    import json, os, sys

    with open(os.environ["FAKE_LOG"], "a") as log:
        log.write("nix " + " ".join(sys.argv[1:]) + "\\n")
    rev = sys.argv[-1].rsplit("/", 1)[1]
    print(json.dumps({"hash": "sha256-" + rev[:12]}))
    """
)


def gh_node(owner: str, repo: str, locked_rev: str, inputs: dict[str, Any] | None = None, **original: str) -> dict[str, Any]:
    node: dict[str, Any] = {
        "locked": {
            "lastModified": 1,
            "narHash": nar(locked_rev),
            "owner": owner,
            "repo": repo,
            "rev": locked_rev,
            "type": "github",
        },
        "original": {"owner": owner, "repo": repo, "type": "github", **original},
    }
    if inputs:
        node["inputs"] = inputs
    return node


def lock(nodes: dict[str, Any], root_inputs: dict[str, Any]) -> dict[str, Any]:
    return {"nodes": {"root": {"inputs": root_inputs}, **nodes}, "root": "root", "version": 7}


# NixOS/nixpkgs: n1 <- n2 <- n3 on nixos-unstable; master runs one commit
# ahead (m4), and "fork" only exists in a fork, on top of n3.
N1, N2, N3, M4, FORK = (sha(x) for x in ("n1", "n2", "n3", "m4", "fork"))
H1, H2 = sha("h1"), sha("h2")
P1 = sha("pinned")
G1, G2 = sha("g1"), sha("g2")

FORGE: dict[str, Any] = {
    "repos": {
        "nixos/nixpkgs": {
            "default_branch": "master",
            "refs": {"nixos-unstable": N3, "master": M4},
            "parents": {N1: [], N2: [N1], N3: [N2], M4: [N3], FORK: [N3], P1: [N1]},
        },
        "nix-community/home-manager": {
            "default_branch": "master",
            "refs": {"master": H2},
            "parents": {H1: [], H2: [H1]},
        },
        "attacker/nixpkgs": {
            "default_branch": "master",
            "refs": {"master": FORK},
            "parents": {N3: [], FORK: [N3]},
        },
    },
}


def base_root_lock() -> dict[str, Any]:
    return lock(
        {
            "nixpkgs": gh_node("NixOS", "nixpkgs", N2, ref="nixos-unstable"),
            "nixpkgs_2": gh_node("NixOS", "nixpkgs", N1, ref="nixos-unstable"),
            "home-manager": gh_node(
                "nix-community", "home-manager", H1, inputs={"nixpkgs": ["nixpkgs"], "old": "nixpkgs_2"}
            ),
            "boot-nixpkgs": gh_node("NixOS", "nixpkgs", P1, rev=P1),
            "firefox-addons": {
                "locked": {"type": "gitlab", "owner": "rycee", "repo": "nur", "rev": G1, "narHash": nar(G1)},
                "original": {"type": "gitlab", "owner": "rycee", "repo": "nur"},
            },
        },
        {
            "nixpkgs": "nixpkgs",
            "home-manager": "home-manager",
            "boot-nixpkgs": "boot-nixpkgs",
            "firefox-addons": "firefox-addons",
        },
    )


def base_raspi_lock() -> dict[str, Any]:
    return lock({"nixpkgs": gh_node("NixOS", "nixpkgs", N2, ref="nixos-unstable")}, {"nixpkgs": "nixpkgs"})


def updated_root_lock() -> dict[str, Any]:
    updated = base_root_lock()
    updated["nodes"]["nixpkgs"] = gh_node("NixOS", "nixpkgs", N3, ref="nixos-unstable")
    updated["nodes"]["home-manager"] = gh_node(
        "nix-community", "home-manager", H2, inputs={"nixpkgs": ["nixpkgs"], "old": "nixpkgs_3"}
    )
    updated["nodes"]["nixpkgs_3"] = updated["nodes"].pop("nixpkgs_2")
    return updated


def updated_raspi_lock() -> dict[str, Any]:
    return lock({"nixpkgs": gh_node("NixOS", "nixpkgs", N3, ref="nixos-unstable")}, {"nixpkgs": "nixpkgs"})


class FlakeLockVerify(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.dir = Path(self.temp.name)
        self.work = self.dir / "work"
        self.bin = self.dir / "bin"
        self.bin.mkdir()
        for name, body in (("gh", FAKE_GH), ("nix", FAKE_NIX)):
            path = self.bin / name
            path.write_text(body)
            path.chmod(0o755)
        self.log = self.dir / "calls.log"
        self.log.touch()
        self.git("init", "--quiet", "--bare", str(self.dir / "origin.git"), cwd=self.dir)
        self.git("init", "--quiet", "-b", "nixos", str(self.work), cwd=self.dir)
        self.git("remote", "add", "origin", str(self.dir / "origin.git"))
        (self.work / "README.md").write_text("dotfiles\n")
        self.write_locks(base_root_lock(), base_raspi_lock())
        self.commit("base")
        self.git("push", "--quiet", "origin", "nixos")

    def tearDown(self) -> None:
        self.temp.cleanup()

    def git(self, *args: str, cwd: Path | None = None) -> str:
        proc = subprocess.run(
            ["git", "-c", "user.name=t", "-c", "user.email=t@t", *args],
            cwd=cwd or self.work,
            capture_output=True,
            text=True,
            check=True,
        )
        return proc.stdout.strip()

    def write_locks(self, root: dict[str, Any], raspi: dict[str, Any]) -> None:
        (self.work / "raspi").mkdir(exist_ok=True)
        (self.work / "flake.lock").write_text(json.dumps(root, indent=2))
        (self.work / "raspi/flake.lock").write_text(json.dumps(raspi, indent=2))

    def commit(self, message: str) -> str:
        self.git("add", "-A")
        self.git("commit", "--quiet", "-m", message)
        return self.git("rev-parse", "HEAD")

    def open_pr(self, root: dict[str, Any], raspi: dict[str, Any], extra: dict[str, str] | None = None) -> str:
        self.git("switch", "--quiet", "-c", "auto/flake-update")
        self.write_locks(root, raspi)
        for name, text in (extra or {}).items():
            (self.work / name).write_text(text)
        head = self.commit("update")
        self.git("push", "--quiet", "origin", "HEAD:refs/pull/7/head")
        self.git("switch", "--quiet", "nixos")
        self.git("branch", "--quiet", "-D", "auto/flake-update")
        self.set_pr_head(head)
        return head

    def set_pr_head(self, head: str) -> None:
        forge = copy.deepcopy(FORGE)
        forge["pr"] = {
            "number": 7,
            "url": "https://github.com/o/r/pull/7",
            "state": "OPEN",
            "headRefName": "auto/flake-update",
            "headRefOid": head,
            "baseRefName": "nixos",
        }
        (self.dir / "forge.json").write_text(json.dumps(forge))

    def verify(self, *args: str, code: int) -> str:
        env = {
            **os.environ,
            "PATH": f"{self.bin}:{os.environ['PATH']}",
            "FAKE_FORGE": str(self.dir / "forge.json"),
            "FAKE_LOG": str(self.log),
        }
        proc = subprocess.run(
            [str(SCRIPT), *args], cwd=self.work, env=env, capture_output=True, text=True, check=False
        )
        output = proc.stdout + proc.stderr
        self.assertEqual(proc.returncode, code, output)
        return output

    def test_forward_update_passes(self) -> None:
        head = self.open_pr(updated_root_lock(), updated_raspi_lock())
        out = self.verify("7", code=0)
        self.assertIn("PASS   home-manager/nixpkgs, nixpkgs:", out)
        self.assertIn("on nixos-unstable; descends from", out)
        self.assertIn("PASS   home-manager:", out)
        self.assertIn("on default branch master", out)
        self.assertIn("raspi/flake.lock\n  PASS   nixpkgs:", out)
        self.assertNotIn("home-manager/old", out, "renamed node with the same lock is unchanged")
        self.assertIn(f"gh pr merge 7 --merge --match-head-commit {head}", out)
        self.assertIn("3 pass, 0 fail, 0 manual", out)

    def test_fork_only_commit_fails(self) -> None:
        root = updated_root_lock()
        root["nodes"]["nixpkgs"] = gh_node("NixOS", "nixpkgs", FORK, ref="nixos-unstable")
        self.open_pr(root, updated_raspi_lock())
        out = self.verify("7", code=1)
        self.assertIn("rev is not reachable from nixos-unstable (compare status: behind)", out)
        self.assertNotIn(f"github:NixOS/nixpkgs/{FORK}", self.log.read_text(), "no prefetch after a failure")
        self.assertIn("Do not merge", out)
        self.assertNotIn("gh pr merge", out)

    def test_commit_from_another_branch_fails(self) -> None:
        root = updated_root_lock()
        root["nodes"]["nixpkgs"] = gh_node("NixOS", "nixpkgs", M4, ref="nixos-unstable")
        self.open_pr(root, updated_raspi_lock())
        self.assertIn("not reachable from nixos-unstable", self.verify("7", code=1))

    def test_raspi_lock_is_checked(self) -> None:
        raspi = lock({"nixpkgs": gh_node("NixOS", "nixpkgs", FORK, ref="nixos-unstable")}, {"nixpkgs": "nixpkgs"})
        self.open_pr(updated_root_lock(), raspi)
        out = self.verify("7", code=1)
        self.assertIn("raspi/flake.lock\n  FAIL   nixpkgs:", out)

    def test_locked_repo_must_match_original(self) -> None:
        root = updated_root_lock()
        node = gh_node("NixOS", "nixpkgs", FORK, ref="nixos-unstable")
        node["locked"]["owner"] = "attacker"
        root["nodes"]["nixpkgs"] = node
        self.open_pr(root, updated_raspi_lock())
        self.assertIn("locked repo attacker/nixpkgs is not the tracked repo NixOS/nixpkgs", self.verify("7", code=1))

    def test_nar_hash_must_match_served_source(self) -> None:
        root = updated_root_lock()
        root["nodes"]["nixpkgs"]["locked"]["narHash"] = "sha256-somethingelse"
        self.open_pr(root, updated_raspi_lock())
        self.assertIn("does not match GitHub's source", self.verify("7", code=1))

    def test_same_rev_with_new_nar_hash_fails_without_prefetch(self) -> None:
        root = base_root_lock()
        root["nodes"]["nixpkgs"]["locked"]["narHash"] = "sha256-somethingelse"
        self.open_pr(root, base_raspi_lock())
        self.assertIn("narHash changed while the rev stayed the same", self.verify("7", "--no-nar-hash", code=1))

    def test_rewiring_to_an_older_node_fails(self) -> None:
        root = base_root_lock()
        root["nodes"]["root"]["inputs"]["nixpkgs"] = "nixpkgs_2"
        self.open_pr(root, base_raspi_lock())
        out = self.verify("7", code=1)
        self.assertIn("nixpkgs:", out)
        self.assertIn("does not descend from the old rev", out)

    def test_pinned_rev_must_match(self) -> None:
        root = updated_root_lock()
        node = gh_node("NixOS", "nixpkgs", N3, rev=P1)
        root["nodes"]["boot-nixpkgs"] = node
        self.open_pr(root, updated_raspi_lock())
        self.assertIn("locked rev differs from the pinned rev", self.verify("7", code=1))

    def test_non_github_input_needs_manual_check(self) -> None:
        root = updated_root_lock()
        root["nodes"]["firefox-addons"]["locked"].update(rev=G2, narHash=nar(G2))
        head = self.open_pr(root, updated_raspi_lock())
        out = self.verify("7", code=2)
        self.assertIn("MANUAL firefox-addons: gitlab rycee/nur", out)
        self.assertIn(f"Then merge exactly the checked commit: gh pr merge 7 --merge --match-head-commit {head}", out)

    def test_other_changed_files_fail(self) -> None:
        self.open_pr(updated_root_lock(), updated_raspi_lock(), extra={"README.md": "changed\n"})
        self.assertIn("PR changes files other than lock files: README.md", self.verify("7", code=1))

    def test_pr_head_moved_after_view(self) -> None:
        self.open_pr(updated_root_lock(), updated_raspi_lock())
        self.set_pr_head(sha("other"))
        self.assertIn("PR head moved while fetching", self.verify("7", code=1))

    def test_local_head_mode(self) -> None:
        self.git("switch", "--quiet", "-c", "local")
        self.write_locks(updated_root_lock(), updated_raspi_lock())
        self.commit("update")
        self.set_pr_head(sha("unused"))
        out = self.verify("--head", "local", code=0)
        self.assertNotIn("gh pr merge", out)
        self.assertNotIn("gh pr view", self.log.read_text())


if __name__ == "__main__":
    unittest.main()
