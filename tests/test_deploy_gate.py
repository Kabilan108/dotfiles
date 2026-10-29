"""Deploy gate scripts in modules/nixos/deploy and bin/rebuild.

OpenSSH's software security key (tests/sk-dummy.nix) stands in for the
YubiKeys and a local bare repo for GitHub. Stubs stand in for nixos-rebuild
(build links a fake system holding its commit; switch makes that commit the
running one), nixos-version (which reports it), systemctl (a small fake
systemd: start --no-block runs the receiver in the background and keeps
ActiveState, InvocationID and Result in files), journalctl (follows that run's
log), socat (runs the broker instead of connecting to the socket), ssh, sudo
and hostname. The receiver's flake.lock check and its lock use the real nix
and flock. Set
DEPLOY_TEST_OPENSSH to a built tests/sk-dummy.nix to skip the nix build.
"""

import fcntl
import os
import pty
import shutil
import subprocess
import tempfile
import termios
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

FLAKE = "{ outputs = _: { }; }\n"
FLAKE_LOCK = '{"nodes":{"root":{}},"root":"root","version":7}\n'

STUBS = {
    "deploy-tag": 'exec bash "{scripts}/deploy-tag.sh" "$@"',
    "nixos-rebuild": (
        'echo "$*" >> "{tmp}/rebuilds"\n'
        '[[ ${{NIXOS_REBUILD_EXIT:-0}} == 0 ]] || exit "$NIXOS_REBUILD_EXIT"\n'
        "case $1 in\n"
        "build)\n"
        '  [[ "$*" =~ rev=([0-9a-f]+) ]] || exit 95\n'
        '  system="{tmp}/systems/${{BASH_REMATCH[1]}}"\n'
        '  mkdir -p "$system" && echo "${{BASH_REMATCH[1]}}" > "$system/rev"\n'
        '  ln -sfn "$system" result\n'
        '  if [[ -n ${{TEST_DURING_BUILD:-}} ]]; then bash -c "$TEST_DURING_BUILD"; fi\n'
        "  ;;\n"
        'switch) [[ $2 == --store-path ]] && cat "$3/rev" > "{tmp}/running" ;;\n'
        "*) exit 94 ;;\n"
        "esac"
    ),
    "nixos-version": (
        '[[ "$*" == --configuration-revision && -s "{tmp}/running" ]] || exit 1\n'
        'cat "{tmp}/running"'
    ),
    "systemctl": (
        'u="{tmp}/unit"; mkdir -p "$u"\n'
        'put() {{ printf "%s\\n" "$2" > "$u/.$1"; mv "$u/.$1" "$u/$1"; }}\n'
        'case "$*" in\n'
        '"start --no-block --job-mode=replace deploy-receiver.service")\n'
        "  id=$(date +%s%N)\n"
        '  put InvocationID "$id"; put ActiveState activating\n'
        '  ( if INVOCATION_ID=$id bash "{scripts}/receiver.sh" > "$u/$id.log" 2>&1\n'
        "    then put Result success; put ActiveState inactive\n"
        "    else put Result exit-code; put ActiveState failed; fi\n"
        # Like systemd unloading the finished unit.
        '    put InvocationID ""\n'
        "  ) </dev/null >/dev/null 2>&1 &\n"
        "  ;;\n"
        '"show --property="*" --value deploy-receiver.service")\n'
        '  cat "$u/${{2#--property=}}" 2>/dev/null || true ;;\n'
        "*) exit 98 ;;\n"
        "esac"
    ),
    "journalctl": (
        '[[ $4 == _SYSTEMD_INVOCATION_ID=* ]] || exit 93\n'
        'exec tail -n +1 -F "{tmp}/unit/${{4#_SYSTEMD_INVOCATION_ID=}}.log" 2>/dev/null'
    ),
    "socat": (
        '[[ "$*" == "-u UNIX-CONNECT:{tmp}/trigger.sock -" ]] || exit 97\n'
        'exec bash "{scripts}/broker.sh"'
    ),
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
            "DEPLOY_LAST_RUN": str(self.state / "last-run"),
            "DEPLOY_NIXOS_VERSION": str(bin_dir / "nixos-version"),
            "DEPLOY_TRIGGER_SOCKET": str(self.tmp / "trigger.sock"),
            "DEPLOY_SWITCH_LOCK": str(self.tmp / "switch.lock"),
            "DOTFILES": str(self.work),
        }
        self.state.mkdir()
        self.git("init", "-q", "--bare", "--initial-branch=nixos", str(self.origin), cwd=self.tmp)
        self.git("clone", "-q", str(self.origin), str(self.work), cwd=self.tmp)
        (self.work / "flake.nix").write_text(FLAKE)
        (self.work / "flake.lock").write_text(FLAKE_LOCK)
        self.git("add", "flake.nix", "flake.lock")
        self.commit("one")
        self.set_running(self.rev("HEAD"))
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

    def push_commit(self, message: str) -> str:
        self.commit(message)
        self.git("push", "-q", "origin", "HEAD:nixos")
        return self.rev("HEAD")

    def set_running(self, rev: str) -> None:
        (self.tmp / "running").write_text(rev + "\n")

    def running(self) -> str:
        return (self.tmp / "running").read_text().strip()

    def sign(
        self, tag: str, key: str, rev: str = "HEAD", push: bool = True, message: str = "test"
    ) -> None:
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
                message,
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

    def deploy_lines(self, commit: str) -> list[str]:
        return [
            f"build --no-update-lock-file --flake git+file://{self.state}/dotfiles.git"
            f"?rev={commit}#sietch",
            f"switch --store-path {self.tmp}/systems/{commit}",
        ]

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
        self.assertEqual(self.rebuilds(), self.deploy_lines(self.tip))
        self.assertEqual((self.state / "deployed").read_text(), f"{T1} {self.tip}\n")
        r = self.receive()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn(f"No deploy tag newer than {T1}; sietch runs {self.tip}", r.stdout)
        self.assertEqual(self.rebuilds(), self.deploy_lines(self.tip))

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
        self.assertIn(f"No deploy tag newer than {T2}", r.stdout)
        # Deleting the newer tag on GitHub doesn't bring the older one back.
        self.git("push", "-q", "origin", f":refs/tags/{T2}")
        r = self.receive()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn(f"No deploy tag newer than {T2}", r.stdout)
        self.assertEqual(self.git("tag", "-l", cwd=self.state / "dotfiles.git"), T1)
        self.assertEqual(self.rebuilds(), self.deploy_lines(self.tip))

    def test_failed_build_is_retried(self) -> None:
        self.sign(T1, "yk")
        self.assertEqual(self.receive(NIXOS_REBUILD_EXIT="1").returncode, 1)
        self.assertFalse((self.state / "deployed").exists())
        self.assertEqual(self.receive().returncode, 0)
        self.assertEqual(len(self.rebuilds()), 3)


class Rollback(DeployGate):
    def test_withheld_tag_cannot_roll_back_a_manual_rebuild(self) -> None:
        # The review's replay: deploy A, sign B but withhold it, rebuild a newer
        # C by hand, then publish B and trigger.
        self.sign(T1, "yk")
        self.assertEqual(self.receive().returncode, 0)
        b = self.push_commit("b")
        self.sign(T2, "yk", push=False)
        c = self.push_commit("c")
        self.set_running(c)
        self.git("push", "-q", "origin", f"refs/tags/{T2}")
        r = self.receive()
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn(f"refusing {T2}: {b} doesn't descend from {c}", r.stderr)
        self.assertEqual(self.running(), c)
        self.assertEqual(self.rebuilds(), self.deploy_lines(self.tip))
        # The manual rebuild is the new floor: a tag on a child of C deploys.
        d = self.push_commit("d")
        self.sign(T3, "yk")
        r = self.receive()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.running(), d)

    def test_signed_override_allows_a_rollback(self) -> None:
        older = self.rev("HEAD^")
        self.set_running(self.tip)
        # Outside the first paragraph the line doesn't count.
        self.sign(T1, "yk", rev=older, message="deploy sietch\n\nAllow-Rollback: yes")
        self.assert_refused(f"{older} doesn't descend from {self.tip}")
        self.sign(T2, "yk", rev=older, message="deploy sietch\nAllow-Rollback: yes\n\nabc1234 one")
        r = self.receive()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.running(), older)

    def test_unsigned_trailer_cannot_allow_a_rollback(self) -> None:
        # The re-review's tag: a valid signed message of one paragraph, with
        # the override appended right after the signature, which nothing covers.
        older = self.rev("HEAD^")
        self.set_running(self.tip)
        self.sign(T1, "yk", rev=older, message="deploy sietch", push=False)
        signed = self.git("cat-file", "tag", T1)
        self.assertTrue(signed.endswith("-----END SSH SIGNATURE-----"), signed)
        forged = self.run_cmd(["git", "mktag"], stdin=signed + "\nAllow-Rollback: yes\n")
        self.assertEqual(forged.returncode, 0, forged.stderr)
        self.git("update-ref", f"refs/tags/{T1}", forged.stdout.strip())
        # git accepts the forged tag: the trailer sits outside what it verifies.
        verify = self.run_cmd(
            ["git", "-c", f"gpg.ssh.allowedSignersFile={KEYS['signers']}", "verify-tag", T1]
        )
        self.assertEqual(verify.returncode, 0, verify.stderr)
        self.git("push", "-q", "origin", f"refs/tags/{T1}")
        self.assert_refused("it has content after its signature")
        self.assertEqual(self.running(), self.tip)
        self.assertEqual(self.run_cmd(["deploy-tag", "allows-rollback", T1]).returncode, 1)

    def test_unknown_running_commit_needs_the_override(self) -> None:
        (self.tmp / "running").unlink()
        self.sign(T1, "yk")
        self.assert_refused("can't read the commit sietch runs")
        self.sign(T2, "yk", message="deploy sietch\nAllow-Rollback: yes")
        self.assertEqual(self.receive().returncode, 0)
        self.assertEqual(self.running(), self.tip)

    def test_a_dirty_manual_rebuild_counts_as_its_base_commit(self) -> None:
        self.set_running(f"{self.tip}-dirty")
        self.sign(T1, "yk", rev="HEAD^")
        self.assert_refused(f"doesn't descend from {self.tip}")
        self.sign(T2, "yk")
        self.assertEqual(self.receive().returncode, 0)


class SwitchLock(DeployGate):
    def test_a_manual_rebuild_during_the_build_wins(self) -> None:
        self.sign(T1, "yk")
        c = self.push_commit("c")
        # While the receiver builds the signed commit, a manual rebuild
        # switches the host to the newer C.
        r = self.receive(TEST_DURING_BUILD=f'echo {c} > "{self.tmp}/running"')
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn(f"{self.tip} doesn't descend from {c}", r.stderr)
        self.assertIn("changed while", r.stderr)
        self.assertEqual(self.rebuilds(), self.deploy_lines(self.tip)[:1])
        self.assertEqual(self.running(), c)

    def test_the_receiver_waits_for_a_rebuild_holding_the_lock(self) -> None:
        self.sign(T1, "yk")
        c = self.push_commit("c")
        lock = self.tmp / "switch.lock"
        holder = subprocess.Popen(
            ["flock", str(lock), "bash", "-c", f'sleep 2; echo {c} > "{self.tmp}/running"']
        )
        try:
            while subprocess.run(["flock", "--nonblock", str(lock), "true"]).returncode == 0:
                pass
            r = self.receive()
        finally:
            holder.wait(timeout=30)
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("Waiting for a manual rebuild to finish", r.stdout)
        self.assertIn(f"{self.tip} doesn't descend from {c}", r.stderr)
        self.assertEqual(self.rebuilds(), self.deploy_lines(self.tip)[:1])
        self.assertEqual(self.running(), c)

    def test_the_lock_file_is_root_only_when_the_receiver_creates_it(self) -> None:
        self.sign(T1, "yk")
        self.assertEqual(self.receive().returncode, 0)
        self.assertEqual((self.tmp / "switch.lock").stat().st_mode & 0o777, 0o600)


class FlakeLock(DeployGate):
    def test_missing_flake_lock(self) -> None:
        self.git("rm", "-q", "flake.lock")
        self.git("commit", "-q", "-m", "drop the lock")
        self.git("push", "-q", "origin", "HEAD:nixos")
        self.sign(T1, "yk")
        self.assert_refused(f"{self.rev('HEAD')} has no flake.lock")

    def test_stale_flake_lock(self) -> None:
        dep = self.tmp / "dep"
        self.git("init", "-q", str(dep), cwd=self.tmp)
        (dep / "flake.nix").write_text(FLAKE)
        self.git("add", "flake.nix", cwd=dep)
        self.git("commit", "-q", "-m", "dep", cwd=dep)
        (self.work / "flake.nix").write_text(
            f'{{ inputs.dep.url = "git+file://{dep}"; outputs = _: {{ }}; }}\n'
        )
        self.git("commit", "-q", "-am", "add an input without locking it")
        self.git("push", "-q", "origin", "HEAD:nixos")
        self.sign(T1, "yk")
        self.assert_refused(f"the flake.lock at {self.rev('HEAD')} is out of date")


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
        self.assertEqual(self.rebuilds(), self.deploy_lines(self.tip))

        r = self.deploy("--yes", "--key", str(KEYS["yk"]), "sietch")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("nothing to sign", r.stdout)
        self.assertEqual(self.deployed_tags(), [tag])
        self.assertEqual(len(self.rebuilds()), 2)

        self.commit("four")
        self.git("push", "-q", "origin", "HEAD:nixos")
        r = self.deploy("--yes", "--key", str(KEYS["yk"]), "sietch")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("four", r.stdout)
        self.assertNotIn(" two\n", r.stdout)
        self.assertEqual(len(self.deployed_tags()), 2)
        self.assertEqual(self.rebuilds()[-2:], self.deploy_lines(self.rev("HEAD")))

    def at_terminal(self, cmd: list[str], typed: str) -> tuple[int, str]:
        """Run cmd with a pseudo-terminal as its controlling terminal."""
        primary, secondary = pty.openpty()
        proc = subprocess.Popen(
            cmd,
            cwd=self.work,
            env=self.env,
            stdin=secondary,
            stdout=secondary,
            stderr=secondary,
            start_new_session=True,
            preexec_fn=lambda: fcntl.ioctl(0, termios.TIOCSCTTY, 0),
        )
        os.close(secondary)
        os.write(primary, typed.encode())
        output = b""
        while True:
            try:
                chunk = os.read(primary, 4096)
            except OSError:
                break
            if not chunk:
                break
            output += chunk
        os.close(primary)
        return proc.wait(timeout=60), output.decode(errors="replace")

    def test_allow_rollback_needs_a_terminal_even_with_yes(self) -> None:
        r = self.deploy("--yes", "--allow-rollback", "--key", str(KEYS["yk"]), "sietch")
        self.assertEqual(r.returncode, 1)
        self.assertIn("needs a terminal to confirm", r.stderr)
        self.assertEqual(self.deployed_tags(), [])

    def test_allow_rollback_at_a_terminal(self) -> None:
        self.assertEqual(self.deploy("--yes", "--key", str(KEYS["yk"]), "sietch").returncode, 0)
        self.git("reset", "-q", "--hard", "HEAD^")
        self.git("push", "-q", "--force", "origin", "HEAD:nixos")
        older = self.rev("HEAD")
        code, out = self.at_terminal(
            ["bash", str(SCRIPTS / "deploy.sh"), "--key", str(KEYS["yk"]), "sietch"], "y\n"
        )
        self.assertNotEqual(code, 0, out)
        self.assertIn(f"doesn't descend from {self.tip}", out)
        code, out = self.at_terminal(
            [
                "bash",
                str(SCRIPTS / "deploy.sh"),
                "--allow-rollback",
                "--key",
                str(KEYS["yk"]),
                "sietch",
            ],
            "y\n",
        )
        self.assertEqual(code, 0, out)
        self.assertEqual(self.running(), older)
        self.assertIn(f"sietch runs {older}", out)

    def test_reports_a_host_running_another_commit(self) -> None:
        self.assertEqual(self.deploy("--yes", "--key", str(KEYS["yk"]), "sietch").returncode, 0)
        # A manual rebuild moved the host on; nothing new is signed.
        self.set_running(self.side)
        r = self.deploy("--yes", "--key", str(KEYS["yk"]), "sietch")
        self.assertEqual(r.returncode, 1)
        self.assertIn(f"doesn't report running {self.tip}", r.stderr)

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


class Trigger(DeployGate):
    def test_broker_returns_at_once_for_a_client_that_never_reads(self) -> None:
        self.sign(T1, "yk")
        # The receiver stays busy for a while; the broker must not wait for it,
        # and its output pipe is never read.
        broker = subprocess.Popen(
            ["bash", str(SCRIPTS / "broker.sh")],
            cwd=self.tmp,
            env={**self.env, "TEST_DURING_BUILD": "sleep 3"},
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
        self.assertEqual(broker.wait(timeout=2), 0)
        self.assertEqual((self.tmp / "unit/ActiveState").read_text(), "activating\n")
        assert broker.stdout is not None
        self.assertEqual(broker.stdout.read(), b"deploy-trigger: started\n")
        broker.stdout.close()
        deadline = 30
        while (self.tmp / "unit/ActiveState").read_text() == "activating\n" and deadline:
            subprocess.run(["sleep", "1"])
            deadline -= 1
        self.assertEqual((self.tmp / "unit/Result").read_text(), "success\n")
        self.assertRegex((self.state / "last-run").read_text(), r"^[0-9]+ 0\n$")

    def trigger(self, socat: str, **extra: str) -> subprocess.CompletedProcess[str]:
        bin_dir = self.tmp / "trigger-bin"
        bin_dir.mkdir(exist_ok=True)
        stub = bin_dir / "socat"
        stub.write_text(f"#!/usr/bin/env bash\n{socat}\n")
        stub.chmod(0o755)
        return self.run_cmd(
            ["bash", str(SCRIPTS / "trigger.sh")],
            extra_env={"PATH": f"{bin_dir}:{self.env['PATH']}", **extra},
        )

    def test_a_killed_run_does_not_report_the_last_success(self) -> None:
        self.sign(T1, "yk")
        self.assertEqual(self.trigger(f'exec bash "{SCRIPTS}/broker.sh"').returncode, 0)
        self.commit("next")
        self.git("push", "-q", "origin", "HEAD:nixos")
        self.sign(T2, "yk")
        # SIGKILL the receiver mid-build, so it can't record this run.
        r = self.trigger(
            f'exec bash "{SCRIPTS}/broker.sh"',
            TEST_DURING_BUILD='kill -9 "$(ps -o ppid= -p "$PPID")"',
        )
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("the receiver run failed (exit unknown)", r.stderr)

    def test_without_a_started_reply_nothing_is_followed(self) -> None:
        for socat in ["exit 1", "echo 'deploy-trigger: couldn'\\''t queue it'"]:
            with self.subTest(socat=socat):
                r = self.trigger(socat)
                self.assertEqual(r.returncode, 1)
                self.assertIn("deploy-trigger:", r.stderr)
                self.assertFalse((self.tmp / "unit/InvocationID").exists())

    def test_follows_the_run_and_reports_its_result(self) -> None:
        self.sign(T1, "yk")
        r = self.trigger(f'exec bash "{SCRIPTS}/broker.sh"')
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn(f"Building {T1}", r.stdout)
        self.assertIn(f"sietch deployed {T1} {self.tip}", r.stdout)
        self.assertIn(f"sietch runs {self.tip}", r.stdout)
        self.commit("not signed")
        self.git("push", "-q", "origin", "HEAD:nixos")
        self.git("tag", "-a", "-m", "unsigned", T2)
        self.git("push", "-q", "origin", f"refs/tags/{T2}")
        r = self.trigger(f'exec bash "{SCRIPTS}/broker.sh"')
        self.assertEqual(r.returncode, 1)
        self.assertIn(f"refusing {T2}", r.stdout)
        self.assertIn("the receiver run failed (exit 1)", r.stderr)


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
        self.assertEqual(self.git("tag", "-l", cwd=self.origin), tag)
        self.assertEqual(
            self.sudo_calls(),
            [f"flock /run/fleet-switch.lock nixos-rebuild switch --flake {self.work}#jacurutu"],
        )

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

    def test_a_failed_push_still_builds(self) -> None:
        self.give_key()
        self.origin.rename(self.tmp / "offline.git")
        r = self.rebuild("y\n")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("Couldn't push deploy/jacurutu/", r.stdout)
        self.assertEqual(len(self.git("tag", "-l", "deploy/jacurutu/*").splitlines()), 1)
        self.assertEqual(len(self.sudo_calls()), 1)

    def test_without_a_yubikey_it_asks_to_build_unsigned(self) -> None:
        r = self.rebuild("", host="sietch")
        self.assertEqual(r.returncode, 1)
        self.assertIn("Not building.", r.stdout)
        self.assertEqual(self.sudo_calls(), [])
        r = self.rebuild("y\n", host="sietch")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(self.git("tag", "-l"), "")
        self.assertEqual(
            self.sudo_calls(),
            [f"flock /run/fleet-switch.lock nixos-rebuild switch --flake {self.work}#sietch"],
        )

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
        self.assertEqual(self.sudo_calls(), [f"nixos-rebuild switch --flake {self.work}#jacurutu"])


if __name__ == "__main__":
    unittest.main()
