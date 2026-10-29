"""Deploy gate scripts in modules/nixos/deploy and bin/rebuild.

OpenSSH's software security key (tests/sk-dummy.nix) stands in for the
YubiKeys, a local bare repo for GitHub, and stubs for nixos-rebuild,
systemctl, ssh, sudo and hostname. Set DEPLOY_TEST_OPENSSH to a built
tests/sk-dummy.nix to skip the nix build.
"""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "modules/nixos/deploy"
KEYS: dict[str, Path] = {}
OPENSSH = Path()
SHARED: tempfile.TemporaryDirectory[str]

T1 = "deploy/sietch/20261029T100000Z"
T2 = "deploy/sietch/20261029T110000Z"
T3 = "deploy/sietch/20261029T120000Z"

STUBS = {
    "deploy-tag": 'exec bash "{scripts}/deploy-tag.sh" "$@"',
    "nixos-rebuild": 'echo "$*" >> "{tmp}/rebuilds"; exit "${{NIXOS_REBUILD_EXIT:-0}}"',
    "systemctl": '[[ "$*" == "start deploy-receiver.service" ]] || exit 98\nbash "{scripts}/receiver.sh"',
    "journalctl": "exec sleep 60",
    "ssh": '[[ "$*" == "sietch-agent deploy-trigger" ]] || exit 99\nexec bash "{scripts}/trigger.sh"',
    "sudo": 'echo "$*" >> "{tmp}/sudo"',
    "hostname": 'echo "$TEST_HOSTNAME"',
}


def setUpModule() -> None:
    global OPENSSH, SHARED
    if path := os.environ.get("DEPLOY_TEST_OPENSSH"):
        OPENSSH = Path(path)
    else:
        expr = (
            f"(import {ROOT}/tests/sk-dummy.nix {{ pkgs = "
            f'(builtins.getFlake "git+file://{ROOT}")'
            ".inputs.nixpkgs.legacyPackages.${builtins.currentSystem}; }).out"
        )
        out = subprocess.run(
            ["nix", "build", "--no-link", "--print-out-paths", "--impure", "--expr", expr],
            capture_output=True,
            text=True,
            check=True,
        )
        OPENSSH = Path(out.stdout.strip())
    SHARED = tempfile.TemporaryDirectory()
    keys = Path(SHARED.name)
    env = {**os.environ, "SSH_SK_PROVIDER": str(OPENSSH / "lib/sk-dummy.so")}
    kinds = {
        "yk": ["-t", "ed25519-sk"],
        "notouch": ["-t", "ed25519-sk", "-O", "no-touch-required"],
        "pin": ["-t", "ed25519-sk", "-O", "verify-required"],
        "evil": ["-t", "ed25519-sk"],
        "soft": ["-t", "ed25519"],
    }
    for name, args in kinds.items():
        KEYS[name] = keys / name
        subprocess.run(
            [OPENSSH / "bin/ssh-keygen", "-q", *args, "-N", "", "-C", name, "-f", KEYS[name]],
            env=env,
            check=True,
            capture_output=True,
            start_new_session=True,
        )
    # Same line format as modules/nixos/deploy/default.nix; evil isn't listed.
    with (keys / "signers").open("w") as signers:
        for name in ["yk", "notouch", "pin", "soft"]:
            pub = KEYS[name].with_suffix(".pub").read_text().strip()
            signers.write(f'{name} namespaces="git" {pub}\n')
    KEYS["signers"] = keys / "signers"


def tearDownModule() -> None:
    SHARED.cleanup()


class DeployGate(unittest.TestCase):
    temp: tempfile.TemporaryDirectory[str]
    tmp: Path
    origin: Path
    work: Path
    state: Path
    env: dict[str, str]

    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.tmp = Path(self.temp.name)
        self.origin = self.tmp / "origin.git"
        self.work = self.tmp / "home/dotfiles"
        self.state = self.tmp / "state"
        bin_dir = self.tmp / "bin"
        bin_dir.mkdir()
        for name, body in STUBS.items():
            stub = bin_dir / name
            stub.write_text(
                "#!/usr/bin/env bash\n" + body.format(scripts=SCRIPTS, tmp=self.tmp) + "\n"
            )
            stub.chmod(0o755)
        self.env = {
            "PATH": f"{bin_dir}:{OPENSSH}/bin:{os.environ['PATH']}",
            "HOME": str(self.tmp / "home"),
            "SSH_SK_PROVIDER": str(OPENSSH / "lib/sk-dummy.so"),
            "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_AUTHOR_NAME": "Test",
            "GIT_AUTHOR_EMAIL": "test@example.com",
            "GIT_COMMITTER_NAME": "Test",
            "GIT_COMMITTER_EMAIL": "test@example.com",
            "DEPLOY_SIGNERS": str(KEYS["signers"]),
            "DEPLOY_REQUIRE_TOUCH": "1",
            "DEPLOY_REQUIRE_PIN": "0",
            "DEPLOY_HOST": "sietch",
            "DEPLOY_HOSTS": "sietch",
            "DEPLOY_REPO_URL": f"file://{self.origin}",
            "DEPLOY_BRANCH": "nixos",
            "DEPLOY_STATE_DIR": str(self.state),
            "DEPLOY_STATE_FILE": str(self.state / "deployed"),
            "DOTFILES": str(self.work),
        }
        self.state.mkdir()
        self.git("init", "-q", "--bare", "--initial-branch=nixos", str(self.origin), cwd=self.tmp)
        self.git("clone", "-q", str(self.origin), str(self.work), cwd=self.tmp)
        self.commit("one")
        self.commit("two")
        self.git("push", "-q", "origin", "HEAD:nixos")
        self.git("switch", "-q", "-c", "side")
        self.commit("three")
        self.git("push", "-q", "origin", "side")
        self.side = self.rev("HEAD")
        self.git("switch", "-q", "nixos")
        self.tip = self.rev("HEAD")

    def tearDown(self) -> None:
        self.temp.cleanup()

    def run_cmd(
        self,
        cmd: list[str],
        cwd: Path | None = None,
        stdin: str = "",
        extra_env: dict[str, str] | None = None,
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            cmd,
            cwd=cwd or self.work,
            env={**self.env, **(extra_env or {})},
            input=stdin,
            capture_output=True,
            text=True,
            check=False,
            start_new_session=True,
        )

    def git(self, *args: str, cwd: Path | None = None) -> str:
        r = self.run_cmd(["git", *args], cwd=cwd)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        return r.stdout.strip()

    def rev(self, name: str) -> str:
        return self.git("rev-parse", name)

    def commit(self, message: str) -> None:
        (self.work / "file").write_text(message)
        self.git("add", "file")
        self.git("commit", "-q", "-m", message)

    def sign(self, tag: str, key: str, rev: str = "HEAD", push: bool = True) -> None:
        r = self.run_cmd(
            [
                "git",
                "-c",
                "gpg.format=ssh",
                "-c",
                f"gpg.ssh.program={OPENSSH}/bin/ssh-keygen",
                "-c",
                f"user.signingKey={KEYS[key]}",
                "tag",
                "-s",
                "-m",
                "test",
                tag,
                rev,
            ],
            stdin="1234\n",
        )
        self.assertEqual(r.returncode, 0, r.stderr)
        if push:
            self.git("push", "-q", "origin", f"refs/tags/{tag}")

    def receive(self, **extra: str) -> subprocess.CompletedProcess[str]:
        return self.run_cmd(["bash", str(SCRIPTS / "receiver.sh")], cwd=self.tmp, extra_env=extra)

    def deploy(self, *args: str, **extra: str) -> subprocess.CompletedProcess[str]:
        return self.run_cmd(["bash", str(SCRIPTS / "deploy.sh"), *args], extra_env=extra)

    def rebuilds(self) -> list[str]:
        path = self.tmp / "rebuilds"
        return path.read_text().splitlines() if path.exists() else []

    def switch_line(self, commit: str) -> str:
        return f"switch --flake git+file://{self.state}/dotfiles.git?rev={commit}#sietch"

    def assert_refused(self, reason: str, **extra: str) -> None:
        r = self.receive(**extra)
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn(reason, r.stderr)
        self.assertEqual(self.rebuilds(), [])
        self.assertFalse((self.state / "deployed").exists())


class Receiver(DeployGate):
    def test_valid_tag_switches_to_its_exact_commit_once(self) -> None:
        self.sign(T1, "yk")
        r = self.receive()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.rebuilds(), [self.switch_line(self.tip)])
        self.assertEqual((self.state / "deployed").read_text(), f"{T1} {self.tip}\n")
        r = self.receive()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn(f"sietch already runs {T1}", r.stdout)
        self.assertEqual(len(self.rebuilds()), 1)

    def test_unsigned_tag(self) -> None:
        self.git("tag", "-a", "-m", "unsigned", T1)
        self.git("push", "-q", "origin", f"refs/tags/{T1}")
        self.assert_refused("it needs exactly one SSH signature")

    def test_lightweight_tag(self) -> None:
        self.git("tag", T1)
        self.git("push", "-q", "origin", f"refs/tags/{T1}")
        self.assert_refused("not an annotated tag")

    def test_tag_signed_by_another_key(self) -> None:
        self.sign(T1, "evil")
        self.assert_refused("not signed by an allowed key")

    def test_signature_without_touch(self) -> None:
        self.sign(T1, "notouch")
        self.assert_refused("signed without a touch")

    def test_software_key_signature(self) -> None:
        self.sign(T1, "soft")
        self.assert_refused("not signed by a security key")

    def test_commit_not_on_nixos(self) -> None:
        self.sign(T1, "yk", rev=self.side)
        self.assert_refused(f"{self.side} is not on nixos")

    def test_tag_object_named_for_another_host(self) -> None:
        self.sign("deploy/tleilax/20261029T100000Z", "yk", push=False)
        obj = self.rev("refs/tags/deploy/tleilax/20261029T100000Z")
        self.git("push", "-q", "origin", f"{obj}:refs/tags/{T1}")
        self.assert_refused("the signed tag object is named 'deploy/tleilax/20261029T100000Z'")

    def test_tag_on_a_tree(self) -> None:
        self.sign(T1, "yk", rev="HEAD^{tree}")
        self.assert_refused("it points at a tree, not a commit")

    def test_bad_tag_name(self) -> None:
        self.sign("deploy/sietch/latest", "yk")
        self.assert_refused("not a deploy/<host>/<YYYYMMDDTHHMMSSZ> name")

    def test_second_signature_block(self) -> None:
        payload = (
            f"object {self.tip}\ntype commit\ntag {T1}\n"
            "tagger Test <test@example.com> 1761732000 +0000\n\n"
            "test\n-----BEGIN SSH SIGNATURE-----\nAAAA\n-----END SSH SIGNATURE-----\n"
        )
        (self.tmp / "payload").write_text(payload)
        r = self.run_cmd(
            ["ssh-keygen", "-Y", "sign", "-n", "git", "-f", str(KEYS["yk"]), "payload"],
            cwd=self.tmp,
        )
        self.assertEqual(r.returncode, 0, r.stderr)
        tag_object = payload + (self.tmp / "payload.sig").read_text()
        r = self.run_cmd(["git", "mktag"], stdin=tag_object)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.git("update-ref", f"refs/tags/{T1}", r.stdout.strip())
        # git itself accepts this tag: it only checks the last block.
        verify = self.run_cmd(
            ["git", "-c", f"gpg.ssh.allowedSignersFile={KEYS['signers']}", "verify-tag", T1]
        )
        self.assertEqual(verify.returncode, 0, verify.stderr)
        self.git("push", "-q", "origin", f"refs/tags/{T1}")
        self.assert_refused("it needs exactly one SSH signature")

    def test_pin_required(self) -> None:
        self.sign(T1, "yk")
        self.assert_refused("signed without the PIN", DEPLOY_REQUIRE_PIN="1")
        self.sign(T2, "pin")
        r = self.receive(DEPLOY_REQUIRE_PIN="1")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual((self.state / "deployed").read_text(), f"{T2} {self.tip}\n")

    def test_skips_a_bad_newest_tag_for_an_older_good_one(self) -> None:
        self.sign(T1, "yk")
        self.sign(T2, "evil")
        r = self.receive()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn(f"refusing {T2}", r.stderr)
        self.assertEqual((self.state / "deployed").read_text(), f"{T1} {self.tip}\n")

    def test_never_goes_back_to_an_older_tag(self) -> None:
        self.sign(T2, "yk")
        self.assertEqual(self.receive().returncode, 0)
        self.sign(T1, "yk", rev="HEAD^")
        r = self.receive()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn(f"already runs {T2}", r.stdout)
        # Deleting the newer tag on GitHub doesn't bring the older one back.
        self.git("push", "-q", "origin", f":refs/tags/{T2}")
        r = self.receive()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn(f"already runs {T2}", r.stdout)
        self.assertEqual(self.git("tag", "-l", cwd=self.state / "dotfiles.git"), T1)
        self.assertEqual(self.rebuilds(), [self.switch_line(self.tip)])

    def test_failed_switch_is_retried(self) -> None:
        self.sign(T1, "yk")
        self.assertEqual(self.receive(NIXOS_REBUILD_EXIT="1").returncode, 1)
        self.assertFalse((self.state / "deployed").exists())
        self.assertEqual(self.receive().returncode, 0)
        self.assertEqual(len(self.rebuilds()), 2)


class DeployTag(DeployGate):
    def test_latest_skips_invalid_tags(self) -> None:
        self.sign(T1, "yk", push=False)
        self.sign(T2, "yk", rev="HEAD^", push=False)
        self.sign(T3, "notouch", push=False)
        r = self.run_cmd(["deploy-tag", "latest", "sietch"])
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout, f"{T2} {self.rev('HEAD^')}\n")
        self.assertIn(f"refusing {T3}: signed without a touch", r.stderr)

    def test_sign_refuses_a_key_outside_the_signers(self) -> None:
        r = self.run_cmd(
            ["deploy-tag", "sign", "--key", str(KEYS["evil"]), "sietch", "HEAD"]
        )
        self.assertEqual(r.returncode, 1)
        self.assertIn("failed its own check and was deleted", r.stderr)
        self.assertEqual(self.git("tag", "-l"), "")


class Deploy(DeployGate):
    def deployed_tags(self) -> list[str]:
        return self.git("tag", "-l", "deploy/*", cwd=self.origin).splitlines()

    def test_signs_pushes_and_deploys(self) -> None:
        r = self.deploy("--yes", "--key", str(KEYS["yk"]), "sietch")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        [tag] = self.deployed_tags()
        self.assertIn("one", r.stdout)
        self.assertIn("two", r.stdout)
        self.assertTrue(r.stdout.endswith(f"sietch runs {tag}.\n"), r.stdout)
        self.assertEqual(self.rebuilds(), [self.switch_line(self.tip)])

        r = self.deploy("--yes", "--key", str(KEYS["yk"]), "sietch")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("nothing to sign", r.stdout)
        self.assertEqual(self.deployed_tags(), [tag])
        self.assertEqual(len(self.rebuilds()), 1)

        self.commit("four")
        self.git("push", "-q", "origin", "HEAD:nixos")
        r = self.deploy("--yes", "--key", str(KEYS["yk"]), "sietch")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("four", r.stdout)
        self.assertNotIn(" two\n", r.stdout)
        self.assertEqual(len(self.deployed_tags()), 2)
        self.assertEqual(self.rebuilds()[-1], self.switch_line(self.rev("HEAD")))

    def test_reports_a_failed_deploy(self) -> None:
        r = self.deploy("--yes", "--key", str(KEYS["yk"]), "sietch", NIXOS_REBUILD_EXIT="1")
        self.assertEqual(r.returncode, 1)
        self.assertIn("the deploy on sietch failed", r.stderr)

    def test_unknown_host(self) -> None:
        r = self.deploy("--yes", "tleilax")
        self.assertEqual(r.returncode, 1)
        self.assertIn("tleilax doesn't take deploys", r.stderr)

    def test_needs_a_terminal_without_yes(self) -> None:
        r = self.deploy("--key", str(KEYS["yk"]), "sietch")
        self.assertEqual(r.returncode, 1)
        self.assertIn("needs a terminal to confirm", r.stderr)
        self.assertEqual(self.deployed_tags(), [])

    def test_rewritten_history_needs_a_terminal_even_with_yes(self) -> None:
        self.assertEqual(self.deploy("--yes", "--key", str(KEYS["yk"]), "sietch").returncode, 0)
        self.git("reset", "-q", "--hard", "HEAD^")
        self.commit("rewritten")
        self.git("push", "-q", "--force", "origin", "HEAD:nixos")
        r = self.deploy("--yes", "--key", str(KEYS["yk"]), "sietch")
        self.assertEqual(r.returncode, 1)
        self.assertIn("It was rewound or force-pushed", r.stdout)
        self.assertIn("needs a terminal to confirm", r.stderr)
        self.assertEqual(len(self.deployed_tags()), 1)


class Gate(DeployGate):
    def gate(self, command: str | None) -> subprocess.CompletedProcess[str]:
        bin_dir = self.tmp / "gate-bin"
        bin_dir.mkdir(exist_ok=True)
        for name in ["deploy-trigger", "sessionizer"]:
            stub = bin_dir / name
            stub.write_text(f'#!/usr/bin/env bash\necho "{name} $*"\n')
            stub.chmod(0o755)
        extra = {"PATH": f"{bin_dir}:/usr/bin:/bin:{os.environ['PATH']}"}
        extra["DEPLOY_GATE_SESSIONIZER"] = str(bin_dir / "sessionizer")
        if command is not None:
            extra["SSH_ORIGINAL_COMMAND"] = command
        return self.run_cmd(["bash", str(SCRIPTS / "gate.sh")], extra_env=extra)

    def test_allows_only_the_trigger_and_inventory(self) -> None:
        r = self.gate("deploy-trigger")
        self.assertEqual((r.returncode, r.stdout), (0, "deploy-trigger \n"))
        r = self.gate('"$HOME/bin/sessionizer" --inventory')
        self.assertEqual((r.returncode, r.stdout), (0, "sessionizer --inventory\n"))
        for command in [None, "bash", "deploy-trigger; id", "deploy-trigger x", "sessionizer"]:
            with self.subTest(command=command):
                r = self.gate(command)
                self.assertEqual(r.returncode, 1)
                self.assertEqual(r.stdout, "")
                self.assertIn("deploy-gate: not allowed", r.stderr)


class Rebuild(DeployGate):
    def rebuild(
        self, stdin: str = "", host: str = "jacurutu", **extra: str
    ) -> subprocess.CompletedProcess[str]:
        return self.run_cmd(
            [str(ROOT / "bin/rebuild")], stdin=stdin, extra_env={"TEST_HOSTNAME": host, **extra}
        )

    def sudo_calls(self) -> list[str]:
        path = self.tmp / "sudo"
        return path.read_text().splitlines() if path.exists() else []

    def give_key(self, key: str = "yk") -> None:
        ssh_dir = self.tmp / "home/.ssh"
        ssh_dir.mkdir(exist_ok=True)
        shutil.copy(KEYS[key], ssh_dir / "yk-nfc")

    def test_a_failed_signature_stops_the_build(self) -> None:
        self.give_key("evil")
        r = self.rebuild("y\n")
        self.assertEqual(r.returncode, 1)
        self.assertIn("failed its own check", r.stderr)
        self.assertEqual(self.sudo_calls(), [])

    def test_approving_signs_head_then_builds(self) -> None:
        self.give_key()
        r = self.rebuild("y\n")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("No signed deploy tag for jacurutu yet", r.stdout)
        [tag] = self.git("tag", "-l", "deploy/jacurutu/*").splitlines()
        self.assertEqual(self.rev(f"{tag}^{{commit}}"), self.tip)
        self.assertEqual(self.sudo_calls(), [f"nixos-rebuild switch --flake {self.work}#jacurutu"])

        r = self.rebuild()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn(f"HEAD is {tag}.", r.stdout)
        self.assertEqual(len(self.sudo_calls()), 2)

        self.commit("four")
        r = self.rebuild("n\n")
        self.assertEqual(r.returncode, 1)
        self.assertIn(f"Commits since {tag}:", r.stdout)
        self.assertIn("four", r.stdout)
        self.assertEqual(len(self.sudo_calls()), 2)

        r = self.rebuild("u\n")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(len(self.git("tag", "-l", "deploy/jacurutu/*").splitlines()), 1)
        self.assertEqual(len(self.sudo_calls()), 3)

    def test_without_a_yubikey_it_asks_to_build_unsigned(self) -> None:
        r = self.rebuild("", host="sietch")
        self.assertEqual(r.returncode, 1)
        self.assertIn("Not building.", r.stdout)
        self.assertEqual(self.sudo_calls(), [])
        r = self.rebuild("y\n", host="sietch")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(self.git("tag", "-l"), "")
        self.assertEqual(self.sudo_calls(), [f"nixos-rebuild switch --flake {self.work}#sietch"])

    def test_uncommitted_changes_are_shown_and_asked_about(self) -> None:
        self.give_key()
        self.assertEqual(self.rebuild("y\n").returncode, 0)
        (self.work / "file").write_text("dirty")
        r = self.rebuild("")
        self.assertEqual(r.returncode, 1)
        self.assertIn("Uncommitted changes", r.stdout)
        self.assertIn(" M file", r.stdout)
        self.assertEqual(len(self.sudo_calls()), 1)

    def test_before_deploy_tag_is_installed(self) -> None:
        (self.tmp / "bin/deploy-tag").unlink()
        r = self.rebuild()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("deploy-tag isn't installed yet", r.stdout)
        self.assertEqual(len(self.sudo_calls()), 1)


if __name__ == "__main__":
    unittest.main()
