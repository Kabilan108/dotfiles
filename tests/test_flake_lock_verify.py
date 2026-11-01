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


GRAPH_HELPERS = """\
import json, os, sys, urllib.parse

forge = json.load(open(os.environ["FAKE_FORGE"]))
with open(os.environ["FAKE_LOG"], "a") as log:
    log.write(os.path.basename(sys.argv[0]) + " " + " ".join(sys.argv[1:]) + "\\n")


def ancestors(parents, sha):
    seen, todo = set(), [sha]
    while todo:
        current = todo.pop()
        if current not in seen:
            seen.add(current)
            todo.extend(parents[current])
    return seen


def commit(repo, ref):
    sha = repo["refs"].get(ref, ref)
    if sha not in repo["parents"]:
        print("not found (HTTP 404)", file=sys.stderr)
        sys.exit(22)
    return sha
"""

FAKE_GH = GRAPH_HELPERS + textwrap.dedent(
    """\
    args = sys.argv[1:]
    if args[:2] == ["pr", "view"]:
        print(json.dumps(forge["pr"]))
        sys.exit(0)
    path = args[1].split("?")[0].split("/")
    repo = forge["github"].get(f"{path[1]}/{path[2]}".lower())
    if repo is None:
        print("gh: Not Found (HTTP 404)", file=sys.stderr)
        sys.exit(1)
    if len(path) == 3:
        print(json.dumps({"default_branch": repo["default_branch"]}))
        sys.exit(0)
    base, head = urllib.parse.unquote("/".join(path[4:])).split("...")
    base, head = commit(repo, base), commit(repo, head)
    if base == head:
        status = "identical"
    elif base in ancestors(repo["parents"], head):
        status = "ahead"
    elif head in ancestors(repo["parents"], base):
        status = "behind"
    else:
        status = "diverged"
    print(json.dumps({"status": status}))
    """
)

FAKE_CURL = GRAPH_HELPERS + textwrap.dedent(
    """\
    url = urllib.parse.urlsplit(sys.argv[-1])
    rest = url.path.removeprefix("/api/v4/projects/")
    project, _, tail = rest.partition("/")
    repo = forge["gitlab"].get(f"{url.netloc}/{urllib.parse.unquote(project)}".lower())
    if repo is None:
        print("curl: (22) The requested URL returned error: 404", file=sys.stderr)
        sys.exit(22)
    if not tail:
        print(json.dumps({"default_branch": repo["default_branch"]}))
        sys.exit(0)
    a, b = (commit(repo, ref) for ref in urllib.parse.parse_qs(url.query)["refs[]"])
    common = ancestors(repo["parents"], a) & ancestors(repo["parents"], b)
    base = next(c for c in [a, b, *sorted(common)] if c in common)
    print(json.dumps({"id": base}))
    """
)

FAKE_NIX = GRAPH_HELPERS + textwrap.dedent(
    """\
    rev = sys.argv[-1].split("?")[0].rsplit("/", 1)[1]
    print(json.dumps({"hash": "sha256-" + rev[:12]}))
    """
)

FAKE_NIX_INSTANTIATE = GRAPH_HELPERS + textwrap.dedent(
    """\
    args = sys.argv[1:]
    named = {args[i + 1]: args[i + 2] for i, a in enumerate(args) if a == "--argstr"}
    if "url" in named:
        url = named["url"]
        if url.startswith("https:"):
            print(json.dumps({"type": "tarball", "url": url}))
            sys.exit(0)
        scheme, rest = url.split(":", 1)
        rest, _, query = rest.partition("?")
        parts = rest.split("/")
        ref = {"type": scheme, "owner": parts[0], "repo": parts[1]}
        if len(parts) > 2:
            ref["rev" if len(parts[2]) == 40 else "ref"] = parts[2]
        ref.update(urllib.parse.parse_qsl(query))
        print(json.dumps(ref))
    elif "file" in named:
        print(json.dumps(json.load(open(named["file"]))["inputs"]))
    else:
        locked = json.loads(named["locked"])
        if "dir" in locked:
            print("error: input attribute 'dir' not supported by scheme", file=sys.stderr)
            sys.exit(1)
        print(json.dumps(forge["flakes"].get(locked["rev"], {})))
    """
)


def gh_node(
    owner: str,
    repo: str,
    locked_rev: str,
    inputs: dict[str, Any] | None = None,
    kind: str = "github",
    flake: bool = True,
    **original: str,
) -> dict[str, Any]:
    node: dict[str, Any] = {
        "locked": {
            "lastModified": 1,
            "narHash": nar(locked_rev),
            "owner": owner,
            "repo": repo,
            "rev": locked_rev,
            "type": kind,
        },
        "original": {"owner": owner, "repo": repo, "type": kind, **original},
    }
    if "dir" in original:
        node["locked"]["dir"] = original["dir"]
    if not flake:
        node["flake"] = False
    if inputs:
        node["inputs"] = inputs
    return node


def lock(nodes: dict[str, Any], root_inputs: dict[str, Any]) -> dict[str, Any]:
    return {"nodes": {"root": {"inputs": root_inputs}, **nodes}, "root": "root", "version": 7}


# NixOS/nixpkgs: n1 <- n2 <- n3 on nixos-unstable; master runs one commit
# ahead (m4), and "fork" only exists in a fork, on top of n3.
N1, N2, N3, M4, FORK = (sha(x) for x in ("n1", "n2", "n3", "m4", "fork"))
H1, H2, H3, H4 = sha("h1"), sha("h2"), sha("h3"), sha("h4")
D1 = sha("d1")
P1 = sha("pinned")
G1, G2, GFORK = sha("g1"), sha("g2"), sha("gfork")
A1 = sha("a1")

HM_INPUTS = {
    "nixpkgs": {"url": "github:NixOS/nixpkgs/nixos-unstable"},
    "old": {"url": "github:NixOS/nixpkgs/nixos-unstable"},
    "data": {"url": "github:o/other", "flake": False},
}
FORGE: dict[str, Any] = {
    "github": {
        "nixos/nixpkgs": {
            "default_branch": "master",
            "refs": {"nixos-unstable": N3, "master": M4},
            "parents": {N1: [], N2: [N1], N3: [N2], M4: [N3], FORK: [N3], P1: [N1]},
        },
        "nix-community/home-manager": {
            "default_branch": "master",
            "refs": {"master": H4},
            "parents": {H1: [], H2: [H1], H3: [H2], H4: [H3]},
        },
        "o/data": {"default_branch": "main", "refs": {"main": D1}, "parents": {D1: []}},
        "attacker/nixpkgs": {
            "default_branch": "master",
            "refs": {"master": FORK},
            "parents": {N3: [], FORK: [N3]},
        },
    },
    "gitlab": {
        "gitlab.com/rycee/nur": {
            "default_branch": "master",
            "refs": {"master": G2},
            "parents": {G1: [], G2: [G1], GFORK: [G1]},
        },
    },
    # Declared inputs per rev. At h3, home-manager moved `old` to master; at
    # h4 it dropped `old`.
    "flakes": {
        H1: HM_INPUTS,
        H2: HM_INPUTS,
        H3: {**HM_INPUTS, "old": {"url": "github:NixOS/nixpkgs/master"}},
        H4: {"nixpkgs": HM_INPUTS["nixpkgs"]},
        G2: {"nixpkgs": {"url": "github:NixOS/nixpkgs/nixos-unstable"}},
    },
}

ROOT_FLAKE = {
    "inputs": {
        "nixpkgs": {"url": "github:NixOS/nixpkgs/nixos-unstable"},
        "home-manager": {
            "url": "github:nix-community/home-manager",
            "inputs": {"nixpkgs": {"follows": "nixpkgs"}, "data": {"url": "github:o/data"}},
        },
        "boot-nixpkgs": {"url": f"github:NixOS/nixpkgs/{P1}"},
        "firefox-addons": {"url": "gitlab:rycee/nur?dir=pkgs/ff"},
        "channel": {"url": "https://channels.nixos.org/x"},
        "blob": {"url": "https://example.org/blob.txt", "flake": False},
        "a": {"url": "github:o/a"},
        "b": {"url": "github:o/a"},
    }
}
RASPI_FLAKE = {"inputs": {"nixpkgs": {"url": "github:NixOS/nixpkgs/nixos-unstable"}}}


def tarball(url: str) -> dict[str, Any]:
    return {
        "locked": {"narHash": f"sha256-{url[-6:]}", "type": "tarball", "url": url},
        "original": {"type": "tarball", "url": "https://channels.nixos.org/x"},
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
            "firefox-addons": gh_node("rycee", "nur", G1, kind="gitlab", dir="pkgs/ff"),
            "channel": tarball("https://releases.nixos.org/x-1"),
        },
        {
            "nixpkgs": "nixpkgs",
            "home-manager": "home-manager",
            "boot-nixpkgs": "boot-nixpkgs",
            "firefox-addons": "firefox-addons",
            "channel": "channel",
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
    updated["nodes"]["firefox-addons"] = gh_node("rycee", "nur", G2, kind="gitlab", dir="pkgs/ff")
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
        fakes = {"gh": FAKE_GH, "nix": FAKE_NIX, "nix-instantiate": FAKE_NIX_INSTANTIATE, "curl": FAKE_CURL}
        for name, body in fakes.items():
            path = self.bin / name
            path.write_text("#!/usr/bin/env python3\n" + body)
            path.chmod(0o755)
        self.log = self.dir / "calls.log"
        self.log.touch()
        self.git("init", "--quiet", "--bare", str(self.dir / "origin.git"), cwd=self.dir)
        self.git("init", "--quiet", "-b", "nixos", str(self.work), cwd=self.dir)
        self.git("remote", "add", "origin", str(self.dir / "origin.git"))
        (self.work / "README.md").write_text("dotfiles\n")
        (self.work / "raspi").mkdir()
        (self.work / "flake.nix").write_text(json.dumps(ROOT_FLAKE))
        (self.work / "raspi/flake.nix").write_text(json.dumps(RASPI_FLAKE))
        self.set_base(base_root_lock(), base_raspi_lock())

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
        (self.work / "flake.lock").write_text(json.dumps(root, indent=2))
        (self.work / "raspi/flake.lock").write_text(json.dumps(raspi, indent=2))

    def commit(self, message: str) -> str:
        self.git("add", "-A")
        self.git("commit", "--quiet", "--allow-empty", "-m", message)
        return self.git("rev-parse", "HEAD")

    def set_base(self, root: dict[str, Any], raspi: dict[str, Any]) -> None:
        self.write_locks(root, raspi)
        self.commit("base")
        self.git("push", "--quiet", "origin", "nixos")

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
        self.assertIn("PASS   firefox-addons: gitlab rycee/nur", out)
        self.assertIn("raspi/flake.lock\n  PASS   nixpkgs:", out)
        self.assertNotIn("home-manager/old", out, "renamed node with the same lock is unchanged")
        self.assertIn(f"gh pr merge 7 --merge --match-head-commit {head}", out)
        self.assertIn("4 pass, 0 fail, 0 manual", out)
        self.assertNotIn("nix-instantiate", self.log.read_text(), "unchanged sources need no declaration lookup")

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

    def test_gitlab_fork_commit_fails(self) -> None:
        root = updated_root_lock()
        root["nodes"]["firefox-addons"] = gh_node("rycee", "nur", GFORK, kind="gitlab", dir="pkgs/ff")
        self.open_pr(root, updated_raspi_lock())
        self.assertIn("rev is not reachable from master (merge base:", self.verify("7", code=1))

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
        self.assertIn("does not match the forge's source", self.verify("7", code=1))

    def test_same_rev_with_new_nar_hash_fails_without_prefetch(self) -> None:
        root = base_root_lock()
        root["nodes"]["nixpkgs"]["locked"]["narHash"] = "sha256-somethingelse"
        self.open_pr(root, base_raspi_lock())
        self.assertIn("narHash changed while the rev stayed the same", self.verify("7", "--no-nar-hash", code=1))

    def test_legacy_info_field_fails(self) -> None:
        root = base_root_lock()
        root["nodes"]["nixpkgs"]["info"] = {"rev": FORK, "narHash": "sha256-evil"}
        self.open_pr(root, base_raspi_lock())
        self.assertIn("node nixpkgs has fields Nix may read as source: info", self.verify("7", code=1))

    def test_rewiring_to_an_older_node_fails(self) -> None:
        root = base_root_lock()
        root["nodes"]["root"]["inputs"]["nixpkgs"] = "nixpkgs_2"
        self.open_pr(root, base_raspi_lock())
        out = self.verify("7", code=1)
        self.assertIn("does not descend from the old rev", out)

    def test_children_of_a_follows_alias_are_compared(self) -> None:
        # a and b lock the same source but a's child is newer. Turning a into
        # an alias of b leaves path a unchanged and downgrades a/child.
        base = base_root_lock()
        base["nodes"].update(
            a=gh_node("o", "a", A1, inputs={"child": "c_new"}),
            b=gh_node("o", "a", A1, inputs={"child": "c_old"}),
            c_new=gh_node("NixOS", "nixpkgs", N2, ref="nixos-unstable"),
            c_old=gh_node("NixOS", "nixpkgs", N1, ref="nixos-unstable"),
        )
        base["nodes"]["root"]["inputs"].update(a="a", b="b")
        self.set_base(base, base_raspi_lock())
        pr = copy.deepcopy(base)
        pr["nodes"]["root"]["inputs"]["a"] = ["b"]
        del pr["nodes"]["a"], pr["nodes"]["c_new"]
        self.open_pr(pr, base_raspi_lock())
        out = self.verify("7", code=1)
        self.assertIn("FAIL   a/child:", out)
        self.assertIn("does not descend from the old rev", out)

    def test_transitive_original_pinned_to_fork_fails(self) -> None:
        root = updated_root_lock()
        root["nodes"]["nixpkgs_3"] = gh_node("NixOS", "nixpkgs", FORK, rev=FORK)
        self.open_pr(root, updated_raspi_lock())
        out = self.verify("7", code=1)
        self.assertIn("FAIL   home-manager/old:", out)
        self.assertIn("original does not match home-manager at", out)

    def test_transitive_original_moved_to_attacker_repo_fails(self) -> None:
        root = updated_root_lock()
        root["nodes"]["nixpkgs_3"] = gh_node("attacker", "nixpkgs", FORK)
        self.open_pr(root, updated_raspi_lock())
        self.assertIn("original does not match home-manager at", self.verify("7", code=1))

    def test_original_swapped_to_registry_reference_fails(self) -> None:
        root = updated_root_lock()
        node = gh_node("attacker", "nixpkgs", FORK)
        node["original"] = {"id": "nixpkgs", "type": "indirect"}
        root["nodes"]["nixpkgs_3"] = node
        self.open_pr(root, updated_raspi_lock())
        out = self.verify("7", code=1)
        self.assertIn("FAIL   home-manager/old:", out)

    def test_upstream_source_change_is_authenticated(self) -> None:
        root = updated_root_lock()
        root["nodes"]["home-manager"] = gh_node(
            "nix-community", "home-manager", H3, inputs={"nixpkgs": ["nixpkgs"], "old": "nixpkgs_3"}
        )
        root["nodes"]["nixpkgs_3"] = gh_node("NixOS", "nixpkgs", M4, ref="master")
        self.open_pr(root, updated_raspi_lock())
        out = self.verify("7", code=0)
        self.assertIn("PASS   home-manager/old:", out)
        self.assertIn("tracked source changed, no ancestry check", out)
        self.assertIn(f"source declared by home-manager at {H3[:9]}", out)

    def test_shared_node_is_checked_against_each_binding(self) -> None:
        # boot-nixpkgs is a valid root input, but home-manager declares `old`
        # as nixos-unstable, so binding it there must fail.
        root = updated_root_lock()
        root["nodes"]["home-manager"]["inputs"]["old"] = "boot-nixpkgs"
        del root["nodes"]["nixpkgs_3"]
        self.open_pr(root, updated_raspi_lock())
        out = self.verify("7", code=1)
        self.assertIn("home-manager/old: original does not match home-manager at", out)

    def test_redirected_follows_fails(self) -> None:
        root = updated_root_lock()
        root["nodes"]["home-manager"]["inputs"]["nixpkgs"] = ["boot-nixpkgs"]
        self.open_pr(root, updated_raspi_lock())
        out = self.verify("7", code=1)
        self.assertIn("home-manager/nixpkgs: the root flake.nix declares follows 'nixpkgs', the lock has ['boot-nixpkgs']", out)

    def test_flake_flag_comes_from_the_own_declaration(self) -> None:
        # The root overrides home-manager's `data` source; home-manager
        # declares it flake = false, and Nix keeps that flag.
        base = base_root_lock()
        base["nodes"]["data"] = gh_node("o", "data", D1, flake=False)
        base["nodes"]["home-manager"]["inputs"]["data"] = "data"
        self.set_base(base, base_raspi_lock())
        pr = copy.deepcopy(base)
        del pr["nodes"]["data"]["flake"]
        self.open_pr(pr, base_raspi_lock())
        out = self.verify("7", code=1)
        self.assertIn("home-manager/data: original does not match the root flake.nix", out)
        self.assertIn("with flake = false", out)

    def test_new_input_with_overridden_source_passes(self) -> None:
        root = updated_root_lock()
        root["nodes"]["data"] = gh_node("o", "data", D1, flake=False)
        root["nodes"]["home-manager"]["inputs"]["data"] = "data"
        self.open_pr(root, updated_raspi_lock())
        out = self.verify("7", code=0)
        self.assertIn("home-manager/data: source declared by the root flake.nix", out)

    def test_removed_input_still_declared_fails(self) -> None:
        root = updated_root_lock()
        del root["nodes"]["home-manager"]["inputs"]["old"], root["nodes"]["nixpkgs_3"]
        self.open_pr(root, updated_raspi_lock())
        out = self.verify("7", code=1)
        self.assertIn("FAIL   home-manager/old: input removed", out)
        self.assertIn("still declares it", out)

    def test_input_dropped_upstream_may_be_removed(self) -> None:
        root = updated_root_lock()
        root["nodes"]["home-manager"] = gh_node("nix-community", "home-manager", H4, inputs={"nixpkgs": ["nixpkgs"]})
        del root["nodes"]["nixpkgs_3"]
        self.open_pr(root, updated_raspi_lock())
        out = self.verify("7", code=0)
        self.assertIn("PASS   home-manager/old: input removed", out)

    def test_new_input_under_an_ancestor_with_dir(self) -> None:
        root = updated_root_lock()
        root["nodes"]["firefox-addons"]["inputs"] = {"nixpkgs": "nixpkgs"}
        self.open_pr(root, updated_raspi_lock())
        out = self.verify("7", code=0)
        self.assertIn(f"firefox-addons/nixpkgs: source declared by firefox-addons at {G2[:9]}", out)

    def test_plain_file_input_is_manual_not_failed(self) -> None:
        root = updated_root_lock()
        root["nodes"]["blob"] = {
            "flake": False,
            "locked": {"narHash": "sha256-blob", "type": "file", "url": "https://example.org/blob.txt"},
            "original": {"type": "file", "url": "https://example.org/blob.txt"},
        }
        root["nodes"]["root"]["inputs"]["blob"] = "blob"
        self.open_pr(root, updated_raspi_lock())
        out = self.verify("7", code=2)
        self.assertIn("blob: source declared by the root flake.nix", out)

    def test_cycle_fails(self) -> None:
        root = base_root_lock()
        root["nodes"]["home-manager"]["inputs"]["self"] = ["home-manager"]
        self.open_pr(root, base_raspi_lock())
        self.assertIn("input graph has a cycle at home-manager/self", self.verify("7", code=1))

    def test_pinned_rev_must_match(self) -> None:
        root = updated_root_lock()
        root["nodes"]["boot-nixpkgs"] = gh_node("NixOS", "nixpkgs", N3, rev=P1)
        self.open_pr(root, updated_raspi_lock())
        self.assertIn("locked rev differs from the pinned rev", self.verify("7", code=1))

    def test_tarball_input_needs_manual_check(self) -> None:
        root = updated_root_lock()
        root["nodes"]["channel"] = tarball("https://releases.nixos.org/x-2")
        head = self.open_pr(root, updated_raspi_lock())
        out = self.verify("7", code=2)
        self.assertIn("MANUAL channel: tarball https://releases.nixos.org/x-1 -> tarball https://releases.nixos.org/x-2", out)
        self.assertIn("1 input(s) need a manual check", out)
        self.assertIn(f"Then merge exactly the checked commit: gh pr merge 7 --merge --match-head-commit {head}", out)

    def test_manual_entry_names_changed_fields(self) -> None:
        root = updated_root_lock()
        root["nodes"]["channel"]["locked"]["narHash"] = "sha256-other"
        self.open_pr(root, updated_raspi_lock())
        out = self.verify("7", code=2)
        self.assertIn("(changed: locked.narHash)", out)

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
