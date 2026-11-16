"""Deploy gate scripts in modules/nixos/deploy, bin/rebuild and the heavy mode
of ci/cache-targets.py.

OpenSSH's software security key (tests/sk-dummy.nix) stands in for the
YubiKeys and a local bare repo for GitHub. Stubs stand in for nixos-rebuild
(build links a fake system holding its commit; switch makes that commit the
running one), nixos-version (which reports it), busctl and systemctl (a small
fake systemd: StartUnit hands out a job ID, joins a pending job, and runs
run-record.sh with the receiver in the background, or before replying with
TEST_SYNC_START; the job disappears when the run ends), journalctl (follows a
run's log), socat (runs the broker instead of connecting to the socket), ssh
(sietch-agent and tleilax-agent reach two fake receivers, each with its own
files under TEST_ROOT; `deploy` and `rebuild` act on a third, "local"),
deploy-wait, sudo (runs what takes the test's switch lock, and only records
the rest), runuser, hostname and ykman (lists TEST_YKMAN_LIST, by default the
nfc YubiKey). deploy-wait's own tests stub gh and the planner instead. The
receiver's flake.lock check and its lock use the real nix and flock. Set
DEPLOY_TEST_OPENSSH to a built tests/sk-dummy.nix to skip the nix build.
"""

import base64
import fcntl
import importlib.util
import io
import json
import os
import pty
import shutil
import signal
import socketserver
import struct
import subprocess
import sys
import tempfile
import termios
import threading
import time
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from typing import Any
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "modules/nixos/deploy"
KEYS: dict[str, Path] = {}
OPENSSH = Path()
SHARED: tempfile.TemporaryDirectory[str]

T1 = "deploy/fleet/20261029T100000Z"
T2 = "deploy/fleet/20261029T110000Z"
T3 = "deploy/fleet/20261029T120000Z"
# Tags from before fleet tags, which a host's state file may still name.
OLD1 = "deploy/sietch/20261029T100000Z"
OLD2 = "deploy/sietch/20261029T110000Z"
FOR_SIETCH = "deploy sietch\nHosts: sietch"

# `ykman list` lines, for the serials in DEPLOY_KEY_SERIALS below.
NFC = "YubiKey 5 NFC (5.7.1) [OTP+FIDO+CCID] Serial: 10000001"
NANO = "YubiKey 5C Nano (5.7.1) [OTP+FIDO+CCID] Serial: 10000002"
OTHER = "YubiKey 5C (5.4.3) [OTP+FIDO+CCID] Serial: 20000001"

FLAKE = "{ outputs = _: { }; }\n"
FLAKE_LOCK = '{"nodes":{"root":{}},"root":"root","version":7}\n'

STUBS = {
    "deploy-tag": 'exec bash "{scripts}/deploy-tag.sh" "$@"',
    "deploy-key": 'exec bash "{scripts}/deploy-key.sh" "$@"',
    "ykman": (
        'echo "$*" >> "{tmp}/ykman-calls"\n'
        '[[ "$*" == list ]] || exit 96\n'
        'echo "ERROR: Unable to list devices for connection" >&2\n'
        '[[ ${{TEST_YKMAN_EXIT:-0}} == 0 ]] || exit "$TEST_YKMAN_EXIT"\n'
        f'printf "%s\\n" "${{{{TEST_YKMAN_LIST-{NFC}}}}}"'
    ),
    "nixos-rebuild": (
        'root=${{TEST_ROOT:-{tmp}}}\n'
        'echo "$*" >> "$root/rebuilds"\n'
        '[[ ${{NIXOS_REBUILD_EXIT:-0}} == 0 ]] || exit "$NIXOS_REBUILD_EXIT"\n'
        "case $1 in\n"
        "build)\n"
        '  [[ "$*" =~ rev=([0-9a-f]+) ]] || exit 95\n'
        '  system="$root/systems/${{BASH_REMATCH[1]}}"\n'
        '  mkdir -p "$system" && echo "${{BASH_REMATCH[1]}}" > "$system/rev"\n'
        '  ln -sfn "$system" result\n'
        '  if [[ -n ${{TEST_DURING_BUILD:-}} ]]; then bash -c "$TEST_DURING_BUILD"; fi\n'
        "  ;;\n"
        "switch | test | boot)\n"
        '  if [[ $2 == --store-path ]]; then rev=$(cat "$3/rev")\n'
        '  elif [[ "$*" =~ rev=([0-9a-f]+) ]]; then rev=${{BASH_REMATCH[1]}}\n'
        "  else exit 93; fi\n"
        '  [[ $1 == boot ]] || echo "$rev" > "$root/running" ;;\n'
        "*) exit 94 ;;\n"
        "esac"
    ),
    "nixos-version": (
        'root=${{TEST_ROOT:-{tmp}}}\n'
        '[[ "$*" == --configuration-revision && -s "$root/running" ]] || exit 1\n'
        'cat "$root/running"'
    ),
    "busctl": (
        '[[ "$*" == "call org.freedesktop.systemd1 /org/freedesktop/systemd1 '
        'org.freedesktop.systemd1.Manager StartUnit ss deploy-receiver.service replace" ]]'
        " || exit 92\n"
        'u="${{TEST_ROOT:-{tmp}}}/unit"; mkdir -p "$u"\n'
        'put() {{ printf "%s\\n" "$2" > "$u/.$1"; mv "$u/.$1" "$u/$1"; }}\n'
        "run() {{\n"
        "  invocation=$(date +%s%N)\n"
        '  INVOCATION_ID=$invocation bash "{scripts}/run-record.sh" bash "{scripts}/receiver.sh"'
        ' > "$u/$invocation.log" 2>&1\n'
        '  put Job ""\n'
        "}}\n"
        'job=$(cat "$u/Job" 2>/dev/null || true)\n'
        'if [[ -z $job ]]; then\n'
        '  job=$(( $(cat "$u/last-job" 2>/dev/null || echo 0) + 1 ))\n'
        '  put last-job "$job"; put Job "$job"\n'
        '  if [[ -n ${{TEST_SYNC_START:-}} ]]; then run; else run </dev/null >/dev/null 2>&1 & fi\n'
        "fi\n"
        'echo "o \\"/org/freedesktop/systemd1/job/$job\\""'
    ),
    "systemctl": (
        'job=$(cat "${{TEST_ROOT:-{tmp}}}/unit/Job" 2>/dev/null || true)\n'
        'case "$*" in\n'
        '"show --property=Job --value deploy-receiver.service") echo "$job" ;;\n'
        '"list-jobs --no-legend")\n'
        '  if [[ -n ${{TEST_LIST_JOBS_DISCONNECT:-}} && ! -e "{tmp}/disconnected" ]]; then\n'
        '    touch "{tmp}/disconnected"\n'
        '    echo "Failed to list jobs: Remote peer disconnected" >&2\n'
        '    exit 1\n'
        '  fi\n'
        '  [[ -z $job ]] || echo "$job deploy-receiver.service start running" ;;\n'
        "*) exit 98 ;;\n"
        "esac"
    ),
    "journalctl": (
        '[[ $4 == _SYSTEMD_INVOCATION_ID=* ]] || exit 93\n'
        'exec tail -n +1 -F "${{TEST_ROOT:-{tmp}}}/unit/${{4#_SYSTEMD_INVOCATION_ID=}}.log" 2>/dev/null'
    ),
    "socat": (
        '[[ "$*" == "-u UNIX-CONNECT:$DEPLOY_TRIGGER_SOCKET -" ]] || exit 97\n'
        'exec bash "{scripts}/broker.sh"'
    ),
    "ssh": (
        'if [[ "$*" == *git-receive-pack* ]]; then printf "%s\\n" "$@" > "{tmp}/push-ssh"; exit 1; fi\n'
        'case "$*" in\n'
        '"sietch-agent deploy-trigger") export TEST_ROOT="{tmp}" ;;\n'
        '"tleilax-agent deploy-trigger")\n'
        '  t="{tmp}/tleilax"\n'
        '  export TEST_ROOT=$t DEPLOY_HOST=tleilax DEPLOY_STATE_DIR=$t/state'
        ' DEPLOY_STATE_FILE=$t/state/deployed DEPLOY_RUNS=$t/runs'
        ' DEPLOY_TRIGGER_SOCKET=$t/trigger.sock ;;\n'
        "*) exit 99 ;;\n"
        "esac\n"
        'exec bash "{scripts}/trigger.sh"'
    ),
    "deploy-switch": 'exec bash "{scripts}/deploy-switch.sh" "$@"',
    "deploy-wait": (
        'echo "$*" >> "{tmp}/waits"\n'
        'if [[ -n ${{TEST_DURING_WAIT:-}} ]]; then bash -c "$TEST_DURING_WAIT"; fi\n'
        'exit "${{TEST_WAIT_EXIT:-0}}"'
    ),
    "sudo": (
        'echo "$*" >> "{tmp}/sudo"\n'
        '[[ $1 == flock && $2 == "{tmp}/switch.lock" ]] || exit 0\n'
        'exec "$@"'
    ),
    "runuser": '[[ $1 == -u && -n $2 && $3 == -- ]] || exit 90\nshift 3\nexec "$@"',
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


class RefusingAgent(socketserver.ThreadingUnixStreamServer):
    """An ssh-agent that lists one key and refuses every request to sign.

    GNOME Keyring's agent does this with a PIN key: it lists every ~/.ssh key
    with a .pub file but can't ask for the PIN.
    """

    daemon_threads = True

    def __init__(self, path: Path, key: Path) -> None:
        blob = base64.b64decode(key.with_suffix(".pub").read_text().split()[1])
        self.identities = bytes([12]) + struct.pack(">I", 1) + _string(blob) + _string(b"agent")
        self.sign_requests = 0
        super().__init__(str(path), _AgentHandler)
        threading.Thread(target=self.serve_forever, daemon=True).start()

    def close(self) -> None:
        self.shutdown()
        self.server_close()


def _string(data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + data


class _AgentHandler(socketserver.StreamRequestHandler):
    server: RefusingAgent

    def handle(self) -> None:
        while len(header := self.rfile.read(4)) == 4:
            message = self.rfile.read(struct.unpack(">I", header)[0])
            if message[:1] == bytes([11]):
                reply = self.server.identities
            else:
                if message[:1] == bytes([13]):
                    self.server.sign_requests += 1
                reply = bytes([5])
            self.wfile.write(_string(reply))


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
            "DEPLOY_PUSH_URL": f"file://{self.origin}",
            "DEPLOY_PUSH_KNOWN_HOSTS": "/dev/null",
            "DEPLOY_REQUIRE_TOUCH": "1",
            "DEPLOY_REQUIRE_PIN": "0",
            "DEPLOY_HOST": "sietch",
            "DEPLOY_CONTROLLER": "jacurutu",
            "DEPLOY_RECEIVERS": "sietch",
            "DEPLOY_GITHUB_REPO": "owner/dotfiles",
            "DEPLOY_REPO_URL": f"file://{self.origin}",
            "DEPLOY_BRANCH": "nixos",
            "DEPLOY_STATE_DIR": str(self.state),
            "DEPLOY_STATE_FILE": str(self.state / "deployed"),
            "DEPLOY_RUNS": str(self.tmp / "runs"),
            "DEPLOY_NIXOS_VERSION": str(bin_dir / "nixos-version"),
            "DEPLOY_TRIGGER_SOCKET": str(self.tmp / "trigger.sock"),
            "DEPLOY_SWITCH_LOCK": str(self.tmp / "switch.lock"),
            "DEPLOY_KEY_SERIALS": "10000002=yk-nano-deploy 10000001=yk-nfc-deploy",
            "DEPLOY_DEFAULT_KEY": "yk-nfc-deploy",
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
        self.local = self.tmp / "local"
        self.local.mkdir()
        (self.local / "running").write_text(self.rev("HEAD") + "\n")
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
        self,
        tag: str,
        key: str,
        rev: str = "HEAD",
        push: bool = True,
        message: str = FOR_SIETCH,
        verbatim: bool = False,
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
                *(["--cleanup=verbatim"] if verbatim else []),
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
        return self.run_cmd(
            ["bash", str(SCRIPTS / "deploy.sh"), *args],
            extra_env={"TEST_ROOT": str(self.local), **extra},
        )

    def retag(self, how: str, rev: str = "HEAD^") -> str:
        """A script that points the newest fleet tag in ~/dotfiles at rev:
        "unsigned" as a plain ref, or "for sietch" as a valid signed tag
        whose Hosts: line names only sietch."""
        newest = f'cd "{self.work}" && tag=$(git tag -l "deploy/fleet/*" | tail -n 1) && '
        if how == "unsigned":
            return newest + f'git tag --no-sign -f "$tag" {rev}'
        signer = (
            f"git -c gpg.format=ssh -c gpg.ssh.program={OPENSSH}/bin/ssh-keygen "
            f"-c user.signingKey={KEYS['yk']}"
        )
        return newest + f'{signer} tag -s -f -m "deploy sietch\nHosts: sietch" "$tag" {rev}'

    def local_running(self) -> str:
        return (self.local / "running").read_text().strip()

    def tagged_build(self, commit: str, host: str = "jacurutu", action: str = "switch") -> str:
        """What deploy-switch hands nixos-rebuild."""
        return (
            f"{action} --no-update-lock-file --flake git+file://{self.work.resolve()}"
            f"?rev={commit}#{host}"
        )

    def ykman_calls(self) -> list[str]:
        path = self.tmp / "ykman-calls"
        return path.read_text().splitlines() if path.exists() else []

    def install_key(self, key: str, name: str) -> None:
        ssh_dir = self.tmp / "home/.ssh"
        ssh_dir.mkdir(exist_ok=True)
        shutil.copy(KEYS[key], ssh_dir / name)

    def rebuilds(self, root: Path | None = None) -> list[str]:
        path = (root or self.tmp) / "rebuilds"
        return path.read_text().splitlines() if path.exists() else []

    def lines(self, name: str) -> list[str]:
        path = self.tmp / name
        return path.read_text().splitlines() if path.exists() else []

    def add_tleilax(self, running: str) -> Path:
        """A second fake receiver, reached as tleilax-agent."""
        root = self.tmp / "tleilax"
        (root / "state").mkdir(parents=True)
        (root / "running").write_text(running + "\n")
        self.env["DEPLOY_RECEIVERS"] = "sietch tleilax"
        return root

    def at_terminal(
        self, cmd: list[str], typed: str, extra_env: dict[str, str] | None = None
    ) -> tuple[int, str]:
        """Run cmd with a pseudo-terminal as its controlling terminal."""
        primary, secondary = pty.openpty()
        proc = subprocess.Popen(
            cmd,
            cwd=self.work,
            env={**self.env, **(extra_env or {})},
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
        self.assertIn(f"No deploy tag for sietch newer than {T1}; it runs {self.tip}", r.stdout)
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

    def test_old_tag_object_under_a_fleet_name(self) -> None:
        self.sign(OLD1, "yk", push=False)
        obj = self.rev(f"refs/tags/{OLD1}")
        self.git("push", "-q", "origin", f"{obj}:refs/tags/{T1}")
        self.assert_refused(f"the signed tag object is named '{OLD1}'")

    def test_tag_on_a_tree(self) -> None:
        self.sign(T1, "yk", rev="HEAD^{tree}")
        self.assert_refused("it points at a tree, not a commit")

    def test_bad_tag_name(self) -> None:
        self.sign("deploy/fleet/latest", "yk")
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
        self.assertIn(f"No deploy tag for sietch newer than {T2}", r.stdout)
        # Deleting the newer tag on GitHub doesn't bring the older one back.
        self.git("push", "-q", "origin", f":refs/tags/{T2}")
        r = self.receive()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn(f"No deploy tag for sietch newer than {T2}", r.stdout)
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
        self.sign(T1, "yk", rev=older, message=f"{FOR_SIETCH}\n\nAllow-Rollback: yes")
        self.assert_refused(f"{older} doesn't descend from {self.tip}")
        self.sign(
            T2, "yk", rev=older,
            message="deploy sietch\nAllow-Rollback: yes\nHosts: sietch\n\nabc1234 one",
        )
        r = self.receive()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.running(), older)

    def test_unsigned_trailer_cannot_allow_a_rollback(self) -> None:
        # The re-review's tag: a valid signed message of one paragraph, with
        # the override appended right after the signature, which nothing covers.
        older = self.rev("HEAD^")
        self.set_running(self.tip)
        self.sign(T1, "yk", rev=older, push=False)
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

    def test_only_an_empty_line_ends_the_first_paragraph(self) -> None:
        # The third review's variants: a blank-looking line that isn't empty
        # would leave the marker in the first paragraph. Tags carrying one are
        # refused outright.
        older = self.rev("HEAD^")
        self.set_running(self.tip)
        variants = {
            "spaces": f"{FOR_SIETCH}\n   \nAllow-Rollback: yes\n",
            "crlf blank line": f"{FOR_SIETCH}\n\r\nAllow-Rollback: yes\n",
            "crlf subject line": f"{FOR_SIETCH}\r\nAllow-Rollback: yes\n",
            "ideographic space": f"{FOR_SIETCH}\n\u3000\nAllow-Rollback: yes\n",
            "no-break space": f"{FOR_SIETCH}\n\u00a0\nAllow-Rollback: yes\n",
            "tab": f"{FOR_SIETCH}\n\t\nAllow-Rollback: yes\n",
        }
        for i, (name, message) in enumerate(variants.items()):
            with self.subTest(name):
                tag = f"deploy/fleet/20261029T1{i}0000Z"
                self.sign(tag, "yk", rev=older, message=message, verbatim=True)
                raw = subprocess.run(
                    ["git", "cat-file", "tag", tag], cwd=self.work, env=self.env,
                    capture_output=True, check=True,
                ).stdout
                self.assertIn(message.encode(), raw)
                verify = self.run_cmd(
                    ["git", "-c", f"gpg.ssh.allowedSignersFile={KEYS['signers']}", "verify-tag", tag]
                )
                self.assertEqual(verify.returncode, 0, verify.stderr)
                r = self.receive()
                self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
                self.assertIn(
                    f"refusing {tag}: its message has a carriage return or a line of only whitespace",
                    r.stderr,
                )
                self.assertEqual(self.running(), self.tip)
                self.assertEqual(self.rebuilds(), [])
                self.assertEqual(self.run_cmd(["deploy-tag", "allows-rollback", tag]).returncode, 1)
                self.git("tag", "-d", tag)
                self.git("push", "-q", "origin", f":refs/tags/{tag}")

    def test_unknown_running_commit_needs_the_override(self) -> None:
        (self.tmp / "running").unlink()
        self.sign(T1, "yk")
        self.assert_refused("can't read the commit sietch runs")
        self.sign(T2, "yk", message=f"{FOR_SIETCH}\nAllow-Rollback: yes")
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

    def test_sign_refuses_a_key_without_the_pin_when_it_is_required(self) -> None:
        r = self.run_cmd(
            ["deploy-tag", "sign", "--key", str(KEYS["yk"]), "sietch", "HEAD"],
            extra_env={"DEPLOY_REQUIRE_PIN": "1"},
        )
        self.assertEqual(r.returncode, 1)
        self.assertIn("signed without the PIN", r.stderr)
        self.assertIn("failed its own check and was deleted", r.stderr)
        self.assertEqual(self.git("tag", "-l"), "")

    def test_sign_bypasses_an_agent_that_lists_the_key(self) -> None:
        agent = RefusingAgent(self.tmp / "agent.sock", KEYS["pin"])
        self.addCleanup(agent.close)
        with_agent = {"SSH_AUTH_SOCK": str(self.tmp / "agent.sock"), "DEPLOY_REQUIRE_PIN": "1"}
        (self.tmp / "payload").write_text("payload\n")
        direct = self.run_cmd(
            ["ssh-keygen", "-Y", "sign", "-n", "git", "-f", str(KEYS["pin"]), "payload"],
            cwd=self.tmp,
            stdin="1234\n",
            extra_env=with_agent,
        )
        self.assertNotEqual(direct.returncode, 0, "ssh-keygen should sign through the agent")
        self.assertIn("agent refused operation", direct.stderr)
        self.assertEqual(agent.sign_requests, 1)

        r = self.run_cmd(
            ["deploy-tag", "sign", "--key", str(KEYS["pin"]), "sietch", "HEAD"],
            stdin="1234\n",
            extra_env=with_agent,
        )
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("Enter the YubiKey PIN when asked, then touch the key", r.stderr)
        tag = r.stdout.strip()
        self.assertEqual(self.git("tag", "-l"), tag)
        self.assertEqual(self.rev(f"{tag}^{{commit}}"), self.tip)
        verify = self.run_cmd(["deploy-tag", "verify", tag], extra_env=with_agent)
        self.assertEqual(verify.returncode, 0, verify.stderr)
        self.assertEqual(agent.sign_requests, 1)


    def test_push_sends_a_valid_tag(self) -> None:
        self.sign(T1, "yk", push=False)
        r = self.run_cmd(["deploy-tag", "push", "--key", str(KEYS["yk"]), T1])
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.git("tag", "-l", cwd=self.origin), T1)

    def test_push_over_ssh_offers_only_the_signer_key(self) -> None:
        self.sign(T1, "yk", push=False)
        r = self.run_cmd(
            ["deploy-tag", "push", "--key", str(KEYS["yk"]), T1],
            extra_env={"DEPLOY_PUSH_URL": "git@github.com:owner/repo.git"},
        )
        self.assertNotEqual(r.returncode, 0)
        args = (self.tmp / "push-ssh").read_text().splitlines()
        for want in [
            ["-F", "/dev/null"],
            ["-i", str(KEYS["yk"])],
            ["-o", "IdentitiesOnly=yes"],
            ["-o", "IdentityAgent=none"],
            ["-o", "StrictHostKeyChecking=yes"],
        ]:
            self.assertTrue(
                any(args[i : i + 2] == want for i in range(len(args))), (want, args)
            )

    def test_push_refuses_an_invalid_tag(self) -> None:
        self.sign(T1, "notouch", push=False)
        r = self.run_cmd(["deploy-tag", "push", "--key", str(KEYS["notouch"]), T1])
        self.assertEqual(r.returncode, 1)
        self.assertIn("won't push", r.stderr)
        self.assertEqual(self.git("tag", "-l", cwd=self.origin), "")


class DeployKey(DeployGate):
    def pick(self, listing: str | None = None, **extra: str) -> subprocess.CompletedProcess[str]:
        if listing is not None:
            extra["TEST_YKMAN_LIST"] = listing
        return self.run_cmd(["bash", str(SCRIPTS / "deploy-key.sh")], extra_env=extra)

    def assert_picks(self, r: subprocess.CompletedProcess[str], key: str, says: str) -> None:
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout, key + "\n")
        self.assertIn(says, r.stderr)
        self.assertEqual(len(r.stderr.splitlines()), 1, r.stderr)

    def assert_none(self, r: subprocess.CompletedProcess[str]) -> None:
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertEqual(r.stdout, "")
        self.assertIn("no deploy YubiKey is plugged in", r.stderr)
        self.assertIn("serial 10000001 for yk-nfc-deploy", r.stderr)
        self.assertIn("serial 10000002 for yk-nano-deploy", r.stderr)

    def test_one_known_yubikey(self) -> None:
        for listing, key in [(NFC, "yk-nfc-deploy"), (NANO, "yk-nano-deploy")]:
            with self.subTest(key=key):
                self.assert_picks(self.pick(listing), key, f"signing with {key}, the deploy key")

    def test_one_known_yubikey_beside_another(self) -> None:
        self.assert_picks(self.pick(f"{OTHER}\n{NANO}"), "yk-nano-deploy", "yk-nano-deploy")

    def test_both_known_yubikeys_use_the_default(self) -> None:
        r = self.pick(f"{NANO}\n{NFC}")
        self.assert_picks(r, "yk-nfc-deploy", "more than one deploy YubiKey is plugged in")
        self.assertIn("signing with the default, yk-nfc-deploy", r.stderr)

    def test_no_yubikey(self) -> None:
        self.assert_none(self.pick(""))

    def test_only_an_unknown_yubikey(self) -> None:
        r = self.pick(OTHER)
        self.assert_none(r)
        self.assertIn(f"These YubiKeys hold no deploy key:\n  {OTHER}", r.stderr)

    def test_a_yubikey_that_hides_its_serial_is_unknown(self) -> None:
        r = self.pick("YubiKey 5 NFC (5.7.1) [FIDO]")
        self.assert_none(r)
        self.assertIn("  YubiKey 5 NFC (5.7.1) [FIDO]", r.stderr)

    def test_a_failing_ykman_falls_back_to_the_default(self) -> None:
        r = self.pick(NANO, TEST_YKMAN_EXIT="2")
        self.assert_picks(r, "yk-nfc-deploy", "ykman list failed (exit 2); signing with yk-nfc-deploy")

    def test_an_unreadable_yubikey_falls_back_to_the_default(self) -> None:
        r = self.pick(f"{NANO}\nYubiKey 5 NFC [OTP+FIDO+CCID] <access denied>")
        self.assert_picks(r, "yk-nfc-deploy", "can't open a plugged-in YubiKey")

    def test_without_ykman_falls_back_to_the_default(self) -> None:
        empty = self.tmp / "empty-path"
        empty.mkdir()
        bash = shutil.which("bash")
        assert bash
        r = self.run_cmd([bash, str(SCRIPTS / "deploy-key.sh")], extra_env={"PATH": str(empty)})
        self.assert_picks(r, "yk-nfc-deploy", "ykman isn't installed")


class Deploy(DeployGate):
    def deployed_tags(self) -> list[str]:
        return self.git("tag", "-l", "deploy/*", cwd=self.origin).splitlines()

    def test_signs_pushes_and_deploys(self) -> None:
        r = self.deploy("--yes", "--key", str(KEYS["yk"]), "sietch")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        [tag] = self.deployed_tags()
        self.assertTrue(tag.startswith("deploy/fleet/"), tag)
        self.assertIn("one", r.stdout)
        self.assertIn("two", r.stdout)
        self.assertIn(f"sietch: sietch deployed {tag} {self.tip}\n", r.stdout)
        self.assertTrue(r.stdout.endswith(f"  sietch runs {tag}\n"), r.stdout)
        self.assertEqual(self.rebuilds(), self.deploy_lines(self.tip))
        self.assertEqual(self.lines("sudo"), [])
        self.assertEqual(self.lines("waits"), [])

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

    def test_signs_with_yk_nfc_deploy_by_default(self) -> None:
        ssh_dir = self.tmp / "home/.ssh"
        ssh_dir.mkdir()
        shutil.copy(KEYS["pin"], ssh_dir / "yk-nfc-deploy")
        r = self.run_cmd(
            ["bash", str(SCRIPTS / "deploy.sh"), "--yes", "sietch"],
            stdin="1234\n",
            extra_env={"DEPLOY_REQUIRE_PIN": "1"},
        )
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        [tag] = self.deployed_tags()
        self.assertTrue(r.stdout.endswith(f"  sietch runs {tag}\n"), r.stdout)

    def test_signs_with_the_plugged_in_yubikey(self) -> None:
        self.install_key("pin", "yk-nano-deploy")
        r = self.run_cmd(
            ["bash", str(SCRIPTS / "deploy.sh"), "--yes", "sietch"],
            stdin="1234\n",
            extra_env={"DEPLOY_REQUIRE_PIN": "1", "TEST_YKMAN_LIST": NANO},
        )
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("signing with yk-nano-deploy", r.stderr)
        [tag] = self.deployed_tags()
        self.assertTrue(r.stdout.endswith(f"  sietch runs {tag}\n"), r.stdout)

    def test_without_a_deploy_yubikey_it_stops_before_asking(self) -> None:
        self.install_key("pin", "yk-nfc-deploy")
        self.install_key("pin", "yk-nano-deploy")
        for listing in ["", OTHER]:
            with self.subTest(listing=listing):
                r = self.deploy("sietch", TEST_YKMAN_LIST=listing)
                self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
                self.assertIn("no deploy YubiKey is plugged in", r.stderr)
                self.assertIn("deploy: nothing was signed", r.stderr)
                self.assertNotIn("needs a terminal", r.stderr)
                self.assertEqual(self.deployed_tags(), [])
                self.assertEqual(self.rebuilds(), [])

    def test_key_flag_skips_detection(self) -> None:
        r = self.deploy("--yes", "--key", str(KEYS["yk"]), "sietch", TEST_YKMAN_LIST="")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(len(self.deployed_tags()), 1)
        self.assertEqual(self.ykman_calls(), [])

    def test_nothing_to_sign_needs_no_yubikey(self) -> None:
        self.assertEqual(self.deploy("--yes", "--key", str(KEYS["yk"]), "sietch").returncode, 0)
        r = self.deploy("--yes", "sietch", TEST_YKMAN_LIST="")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("nothing to sign", r.stdout)
        self.assertEqual(self.ykman_calls(), [])

    def test_lists_ci_changes(self) -> None:
        r = self.deploy("--yes", "--key", str(KEYS["yk"]), "sietch")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertNotIn("change CI", r.stdout)

        workflow = self.work / ".github/workflows/cache.yml"
        workflow.parent.mkdir(parents=True)
        workflow.write_text("on: push\n")
        self.git("add", ".github")
        self.git("commit", "-q", "-m", "ci")
        self.git("push", "-q", "origin", "HEAD:nixos")
        r = self.deploy("--yes", "--key", str(KEYS["yk"]), "sietch")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("change CI", r.stdout)
        self.assertIn("  .github/workflows/cache.yml\n", r.stdout)

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
        self.assertIn("  sietch failed: it deployed deploy/fleet/", r.stdout)
        self.assertIn(f"doesn't report running {self.tip}", r.stdout)
        self.assertIn("deploy: failed on sietch", r.stderr)

    def test_a_carriage_return_in_a_commit_subject_still_deploys(self) -> None:
        (self.work / "file").write_text("cr")
        self.git("add", "file")
        self.git("commit", "-q", "--cleanup=verbatim", "-m", "fix\rthing")
        self.git("push", "-q", "origin", "HEAD:nixos")
        r = self.deploy("--yes", "--key", str(KEYS["yk"]), "sietch")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        [tag] = self.deployed_tags()
        message = self.git("cat-file", "tag", tag, cwd=self.origin)
        self.assertIn(" fixthing", message)
        self.assertNotIn("\r", message)

    def test_reports_a_failed_deploy(self) -> None:
        r = self.deploy("--yes", "--key", str(KEYS["yk"]), "sietch", NIXOS_REBUILD_EXIT="1")
        self.assertEqual(r.returncode, 1)
        self.assertIn("  sietch failed: the deploy exited 1; see its log above\n", r.stdout)
        self.assertIn("deploy: failed on sietch", r.stderr)

    def test_unknown_host(self) -> None:
        r = self.deploy("--yes", "arrakis")
        self.assertEqual(r.returncode, 1)
        self.assertIn("arrakis doesn't take deploys", r.stderr)

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
    def runs(self) -> list[str]:
        path = self.tmp / "runs"
        return path.read_text().splitlines() if path.exists() else []

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
        self.assertEqual((self.tmp / "unit/Job").read_text(), "1\n")
        assert broker.stdout is not None
        self.assertEqual(broker.stdout.read(), b"deploy-trigger: queued job 1\n")
        broker.stdout.close()
        deadline = 30
        while (self.tmp / "unit/Job").read_text() != "\n" and deadline:
            subprocess.run(["sleep", "1"])
            deadline -= 1
        self.assertRegex(self.runs()[-1], r"^1 [0-9]+ exit:0$")

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

    def broker(self, **extra: str) -> subprocess.CompletedProcess[str]:
        return self.trigger(f'exec bash "{SCRIPTS}/broker.sh"', **extra)

    def test_a_run_that_ends_before_the_first_poll(self) -> None:
        # The re-review's case: the run finishes, and its job and unit are gone,
        # before the client first looks.
        self.sign(T1, "yk")
        r = self.broker(TEST_SYNC_START="1")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn(f"Building {T1}", r.stdout)
        self.assertIn(f"sietch deployed {T1} {self.tip}", r.stdout)
        self.assertIn(f"sietch runs {self.tip}", r.stdout)
        self.git("tag", "-a", "-m", "unsigned", T2)
        self.git("push", "-q", "origin", f"refs/tags/{T2}")
        r = self.broker(TEST_SYNC_START="1")
        self.assertEqual(r.returncode, 1)
        self.assertIn("the receiver run for job 2 failed (exit 1)", r.stderr)

    def test_follows_the_run_and_reports_its_result(self) -> None:
        self.sign(T1, "yk")
        r = self.broker()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn(f"Building {T1}", r.stdout)
        self.assertIn(f"sietch deployed {T1} {self.tip}", r.stdout)
        self.assertIn(f"sietch runs {self.tip}", r.stdout)
        self.commit("not signed")
        self.git("push", "-q", "origin", "HEAD:nixos")
        self.git("tag", "-a", "-m", "unsigned", T2)
        self.git("push", "-q", "origin", f"refs/tags/{T2}")
        r = self.broker()
        self.assertEqual(r.returncode, 1)
        self.assertIn(f"refusing {T2}", r.stdout)
        self.assertIn("the receiver run for job 2 failed (exit 1)", r.stderr)

    def test_retries_a_status_query_disconnected_during_activation(self) -> None:
        self.sign(T1, "yk")
        r = self.broker(TEST_DURING_BUILD="sleep 3", TEST_LIST_JOBS_DISCONNECT="1")
        self.assertIn("Failed to list jobs: Remote peer disconnected", r.stderr)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn(f"sietch deployed {T1} {self.tip}", r.stdout)
        self.assertRegex(self.runs()[-1], r"^1 [0-9]+ exit:0$")

    def test_a_killed_receiver_is_a_failure(self) -> None:
        self.sign(T1, "yk")
        self.assertEqual(self.broker().returncode, 0)
        self.commit("next")
        self.git("push", "-q", "origin", "HEAD:nixos")
        self.sign(T2, "yk")
        # SIGKILL the receiver mid-build; run-record.sh notes the signal.
        r = self.broker(TEST_DURING_BUILD='kill -9 "$(ps -o ppid= -p "$PPID")"')
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("the receiver run for job 2 failed (exit 137)", r.stderr)

    def test_a_run_that_leaves_no_result_is_a_failure(self) -> None:
        self.sign(T1, "yk")
        self.assertEqual(self.broker().returncode, 0)
        self.commit("next")
        self.git("push", "-q", "origin", "HEAD:nixos")
        self.sign(T2, "yk")
        # SIGKILL the receiver and run-record.sh too: job 2 records only its
        # start, while job 1's success stays in the record. ps pads PIDs under
        # seven digits with a space, which `ps -p` rejects.
        r = self.broker(
            TEST_DURING_BUILD=(
                'receiver=$(ps -o ppid= -p "$PPID" | tr -d " "); '
                'kill -9 "$(ps -o ppid= -p "$receiver" | tr -d " ")" "$receiver"'
            )
        )
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("job 2 ended without the receiver recording a result", r.stderr)
        self.assertRegex(self.runs()[-1], r"^2 [0-9]+ started$")

    def test_without_a_job_reply_nothing_is_followed(self) -> None:
        for socat in ["exit 1", "echo 'deploy-trigger: couldn'\\''t queue it'"]:
            with self.subTest(socat=socat):
                r = self.trigger(socat)
                self.assertEqual(r.returncode, 1)
                self.assertIn("deploy-trigger:", r.stderr)
                self.assertEqual(self.runs(), [])


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
        self, stdin: str = "", host: str = "jacurutu", args: tuple[str, ...] = (), **extra: str
    ) -> subprocess.CompletedProcess[str]:
        return self.run_cmd(
            [str(ROOT / "bin/rebuild"), *args],
            stdin=stdin,
            extra_env={"TEST_HOSTNAME": host, "TEST_ROOT": str(self.local), **extra},
        )

    def sudo_calls(self) -> list[str]:
        path = self.tmp / "sudo"
        return path.read_text().splitlines() if path.exists() else []

    def give_key(self, key: str = "yk") -> None:
        self.install_key(key, "yk-nfc-deploy")

    def test_signs_with_the_plugged_in_yubikey(self) -> None:
        self.install_key("yk", "yk-nano-deploy")
        r = self.rebuild("y\n", TEST_YKMAN_LIST=NANO)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("signing with yk-nano-deploy", r.stderr)
        [tag] = self.git("tag", "-l", "deploy/fleet/*").splitlines()
        self.assertIn("\nHosts: jacurutu\n", self.git("cat-file", "tag", tag))
        self.assertEqual(len(self.sudo_calls()), 1)

    def test_without_a_deploy_yubikey_it_stops_before_asking(self) -> None:
        self.give_key()
        r = self.rebuild("y\n", TEST_YKMAN_LIST="")
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("no deploy YubiKey is plugged in", r.stderr)
        self.assertIn("Plug in a deploy YubiKey, or build with --unsigned.", r.stdout)
        self.assertNotIn("Sign a deploy tag", r.stdout)
        self.assertNotIn("Build this unsigned?", r.stdout)
        self.assertEqual(self.git("tag", "-l"), "")
        self.assertEqual(self.sudo_calls(), [])

        r = self.rebuild("", args=("--unsigned",), TEST_YKMAN_LIST="")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(len(self.sudo_calls()), 1)
        self.assertEqual(self.ykman_calls(), ["list"])

    def test_key_flag_skips_detection(self) -> None:
        self.install_key("yk", "yk-nano-deploy")
        r = self.rebuild("y\n", args=("--key", "yk-nano-deploy"), TEST_YKMAN_LIST="")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(len(self.git("tag", "-l", "deploy/fleet/*").splitlines()), 1)
        self.assertEqual(self.ykman_calls(), [])

    def test_before_deploy_key_is_installed_it_signs_with_yk_nfc_deploy(self) -> None:
        self.give_key()
        (self.tmp / "bin/deploy-key").unlink()
        path = ":".join(
            d for d in self.env["PATH"].split(":") if not (Path(d) / "deploy-key").exists()
        )
        r = self.rebuild("y\n", PATH=path, TEST_YKMAN_LIST="")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(len(self.git("tag", "-l", "deploy/fleet/*").splitlines()), 1)
        self.assertEqual(self.ykman_calls(), [])

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
        [tag] = self.git("tag", "-l", "deploy/*").splitlines()
        self.assertTrue(tag.startswith("deploy/fleet/"), tag)
        self.assertIn("\nHosts: jacurutu\n", self.git("cat-file", "tag", tag))
        self.assertEqual(self.rev(f"{tag}^{{commit}}"), self.tip)
        self.assertEqual(self.git("tag", "-l", cwd=self.origin), tag)
        signed_with = (
            f"-C {self.work} --key {self.tmp}/home/.ssh/yk-nfc-deploy --commit {self.tip} {tag}"
        )
        self.assertEqual(self.lines("waits"), [signed_with])
        [call] = self.sudo_calls()
        self.assertTrue(call.startswith(f"flock {self.tmp}/switch.lock "), call)
        self.assertEqual(self.rebuilds(self.local), [self.tagged_build(self.tip)])

        # HEAD is signed already; CI may still be building for it.
        r = self.rebuild()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn(f"HEAD is {tag}.", r.stdout)
        self.assertEqual(
            self.lines("waits"), [signed_with, f"-C {self.work} --commit {self.tip} {tag}"]
        )
        self.assertEqual(self.rebuilds(self.local), [self.tagged_build(self.tip)] * 2)

        self.commit("four")
        r = self.rebuild("n\n")
        self.assertEqual(r.returncode, 1)
        self.assertIn(f"Commits since {tag}:", r.stdout)
        self.assertIn("four", r.stdout)
        self.assertEqual(len(self.sudo_calls()), 2)

        r = self.rebuild("u\n")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(len(self.git("tag", "-l", "deploy/*").splitlines()), 1)
        self.assertEqual(len(self.lines("waits")), 2)
        self.assertEqual(
            self.sudo_calls()[2:],
            [f"flock /run/fleet-switch.lock nixos-rebuild switch --flake {self.work}#jacurutu"],
        )

    def test_a_failed_push_still_builds(self) -> None:
        self.give_key()
        self.origin.rename(self.tmp / "offline.git")
        r = self.rebuild("y\n")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("Couldn't push deploy/fleet/", r.stdout)
        self.assertEqual(len(self.git("tag", "-l", "deploy/*").splitlines()), 1)
        self.assertEqual(self.lines("waits"), [])
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
        # A host that already has deploy-tag installed mustn't lend it here.
        path = ":".join(
            d for d in self.env["PATH"].split(":") if not (Path(d) / "deploy-tag").exists()
        )
        r = self.rebuild(PATH=path)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("deploy-tag isn't installed yet", r.stdout)
        self.assertEqual(self.sudo_calls(), [f"nixos-rebuild switch --flake {self.work}#jacurutu"])
        r = self.rebuild(args=("boot",), PATH=path)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(
            self.sudo_calls()[1:], [f"nixos-rebuild boot --flake {self.work}#jacurutu"]
        )

    def test_unsigned_builds_without_asking_or_signing(self) -> None:
        self.give_key()
        self.commit("four")
        r = self.rebuild("", args=("switch", "--unsigned"))
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("No signed deploy tag for jacurutu yet", r.stdout)
        self.assertIn("four", r.stdout)
        self.assertNotIn("Sign a deploy tag", r.stdout)
        self.assertEqual(self.lines("waits"), [])
        self.assertEqual(self.git("tag", "-l"), "")
        self.assertEqual(self.git("tag", "-l", cwd=self.origin), "")
        self.assertEqual(
            self.sudo_calls(),
            [f"flock /run/fleet-switch.lock nixos-rebuild switch --flake {self.work}#jacurutu"],
        )

    def test_unsigned_builds_uncommitted_changes(self) -> None:
        self.give_key()
        self.assertEqual(self.rebuild("y\n").returncode, 0)
        (self.work / "file").write_text("dirty")
        r = self.rebuild("", args=("--unsigned",))
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn(" M file", r.stdout)
        self.assertEqual(len(self.sudo_calls()), 2)

    def test_test_and_boot_run_under_the_lock(self) -> None:
        for action in ["test", "boot"]:
            with self.subTest(action=action):
                (self.tmp / "sudo").unlink(missing_ok=True)
                r = self.rebuild("y\n", host="sietch", args=(action,))
                self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
                self.assertEqual(
                    self.sudo_calls(),
                    [
                        f"flock /run/fleet-switch.lock nixos-rebuild {action} "
                        f"--flake {self.work}#sietch"
                    ],
                )

    def test_no_wait_and_unsigned_skip_the_wait(self) -> None:
        self.give_key()
        self.assertEqual(self.rebuild("y\n", args=("--no-wait",)).returncode, 0)
        self.assertEqual(self.lines("waits"), [])
        for args in [("--no-wait",), ("--unsigned",)]:
            with self.subTest(args=args):
                r = self.rebuild(args=args)
                self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
                self.assertIn("HEAD is deploy/fleet/", r.stdout)
                self.assertEqual(self.lines("waits"), [])
        # --unsigned builds the checkout even though HEAD is signed.
        self.assertEqual(self.rebuilds(self.local), [self.tagged_build(self.tip)] * 2)
        self.assertEqual(
            self.sudo_calls()[2:],
            [f"flock /run/fleet-switch.lock nixos-rebuild switch --flake {self.work}#jacurutu"],
        )

    def test_a_declined_wait_stops_the_build(self) -> None:
        self.give_key()
        r = self.rebuild("y\n", TEST_WAIT_EXIT="1")
        self.assertEqual(r.returncode, 1)
        self.assertIn("Not building.", r.stdout)
        self.assertEqual(len(self.lines("waits")), 1)
        self.assertEqual(self.sudo_calls(), [])

    def test_a_dirty_build_never_waits(self) -> None:
        self.give_key()
        self.commit("four")
        (self.work / "file").write_text("dirty")
        r = self.rebuild("y\n")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(len(self.git("tag", "-l", "deploy/*").splitlines()), 1)
        self.assertEqual(self.lines("waits"), [])
        self.assertEqual(len(self.sudo_calls()), 1)
        # A signed HEAD with uncommitted changes builds unsigned, unwaited.
        r = self.rebuild("y\n")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(len(self.git("tag", "-l", "deploy/*").splitlines()), 1)
        self.assertEqual(self.lines("waits"), [])
        self.assertEqual(len(self.sudo_calls()), 2)

    def without_deploy_wait(self) -> str:
        """A PATH without deploy-wait, which only the controller has."""
        (self.tmp / "bin/deploy-wait").unlink()
        return ":".join(
            d for d in self.env["PATH"].split(":") if not (Path(d) / "deploy-wait").exists()
        )

    def test_away_from_the_controller_it_never_waits(self) -> None:
        self.sign(T1, "yk", message="rebuild sietch\nHosts: sietch", push=False)
        r = self.rebuild(host="sietch", PATH=self.without_deploy_wait())
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn(f"HEAD is {T1}.", r.stdout)
        self.assertNotIn("deploy-wait", r.stdout + r.stderr)
        self.assertEqual(self.rebuilds(self.local), [self.tagged_build(self.tip, "sietch")])

    def test_before_deploy_wait_is_installed(self) -> None:
        self.give_key()
        r = self.rebuild("y\n", PATH=self.without_deploy_wait())
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(len(self.git("tag", "-l", "deploy/fleet/*").splitlines()), 1)
        self.assertEqual(len(self.sudo_calls()), 1)

    def test_a_signed_build_builds_the_tagged_commit(self) -> None:
        # A pull lands in ~/dotfiles while the build waits for CI.
        self.give_key()
        pull = f'cd "{self.work}" && echo pulled > file && git commit -qam pulled'
        r = self.rebuild("y\n", TEST_DURING_WAIT=pull)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertNotEqual(self.rev("HEAD"), self.tip)
        self.assertEqual(self.rebuilds(self.local), [self.tagged_build(self.tip)])
        self.assertEqual(self.local_running(), self.tip)

    def test_a_tag_moved_during_the_wait_is_refused(self) -> None:
        # The review's repro: another process running as Tony re-points the
        # tag while rebuild waits for CI.
        self.give_key()
        for how in ["unsigned", "for sietch"]:
            with self.subTest(how):
                r = self.rebuild("y\n", TEST_DURING_WAIT=self.retag(how))
                self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
                self.assertIn("it now resolves to", r.stderr)
                self.assertEqual(self.rebuilds(self.local), [])
                self.assertEqual(self.sudo_calls(), [])
                self.assertEqual(self.local_running(), self.rev("HEAD^"))
                # Next round signs a fresh tag at HEAD.
                for tag in self.git("tag", "-l", "deploy/*").splitlines():
                    self.git("tag", "-d", tag)
                    self.git("push", "-q", "origin", f":refs/tags/{tag}")

    def test_a_tag_moved_while_waiting_for_the_lock_is_refused(self) -> None:
        self.give_key()
        lock = self.tmp / "switch.lock"
        holder = subprocess.Popen(
            [
                "flock", str(lock), "bash", "-c",
                f'for _ in $(seq 300); do [[ -s "{self.tmp}/sudo" ]] && break; sleep 0.1; done; '
                f'sleep 0.5; {self.retag("unsigned")}',
            ],
            env=self.env,
        )
        try:
            while subprocess.run(["flock", "--nonblock", str(lock), "true"]).returncode == 0:
                pass
            r = self.rebuild("y\n")
        finally:
            holder.wait(timeout=30)
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("it now resolves to", r.stderr)
        self.assertIn("changed while this switch waited for the lock", r.stderr)
        self.assertEqual(self.rebuilds(self.local), [])

    def test_an_old_per_host_tag_at_head_builds_the_checkout(self) -> None:
        self.give_key()
        self.sign("deploy/jacurutu/20261029T100000Z", "yk", message="rebuild", push=False)
        r = self.rebuild()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("HEAD is deploy/jacurutu/20261029T100000Z.", r.stdout)
        self.assertEqual(self.lines("waits"), [])
        self.assertEqual(
            self.sudo_calls(),
            [f"flock /run/fleet-switch.lock nixos-rebuild switch --flake {self.work}#jacurutu"],
        )

    def test_a_signed_test_or_boot_builds_the_tagged_commit(self) -> None:
        self.give_key()
        self.assertEqual(self.rebuild("y\n", args=("--no-wait", "boot")).returncode, 0)
        self.assertEqual(self.rebuild(args=("test",)).returncode, 0)
        self.assertEqual(
            self.rebuilds(self.local),
            [self.tagged_build(self.tip, action="boot"), self.tagged_build(self.tip, action="test")],
        )

    def test_a_signed_rebuild_may_move_back(self) -> None:
        # Moving forward is checked by deploy only; rebuild leaves it to Tony.
        self.give_key()
        (self.local / "running").write_text(self.tip + "\n")
        self.git("reset", "-q", "--hard", "HEAD^")
        r = self.rebuild("y\n")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(self.local_running(), self.rev("HEAD"))

    def test_before_deploy_switch_is_installed(self) -> None:
        self.give_key()
        (self.tmp / "bin/deploy-switch").unlink()
        path = ":".join(
            d for d in self.env["PATH"].split(":") if not (Path(d) / "deploy-switch").exists()
        )
        r = self.rebuild("y\n", PATH=path)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("deploy-switch isn't installed yet", r.stdout)
        self.assertEqual(
            self.sudo_calls(),
            [f"flock /run/fleet-switch.lock nixos-rebuild switch --flake {self.work}#jacurutu"],
        )

    def test_retrying_after_a_failed_push_does_not_wait_for_ci(self) -> None:
        self.give_key()
        self.origin.rename(self.tmp / "offline.git")
        self.assertEqual(self.rebuild("y\n").returncode, 0)
        (self.tmp / "offline.git").rename(self.origin)
        [tag] = self.git("tag", "-l", "deploy/*").splitlines()
        # The real deploy-wait; gh fails loudly if it gets that far.
        (self.tmp / "bin/deploy-wait").write_text(
            f'#!/usr/bin/env bash\nexec bash "{SCRIPTS}/deploy-wait.sh" "$@"\n'
        )
        (self.tmp / "bin/gh").write_text(f'#!/usr/bin/env bash\necho "$*" >> "{self.tmp}/gh-calls"\nexit 1\n')
        (self.tmp / "bin/gh").chmod(0o755)
        r = self.rebuild()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn(f"HEAD is {tag}.", r.stdout)
        self.assertIn(f"{tag} isn't on GitHub, so no CI run builds for it.", r.stdout)
        self.assertIn(f"push --key <its key file> {tag}", r.stdout)
        self.assertEqual(self.lines("gh-calls"), [])
        self.assertEqual(self.rebuilds(self.local), [self.tagged_build(self.tip)])
        r = self.rebuild(args=("--key", "yk-nfc-deploy"))
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn(f"push --key {self.tmp}/home/.ssh/yk-nfc-deploy {tag}", r.stdout)
        self.assertEqual(self.ykman_calls(), ["list"])

    def test_an_old_per_host_tag_still_lists_what_changed(self) -> None:
        self.give_key()
        self.sign("deploy/jacurutu/20261029T100000Z", "yk", rev="HEAD^", message="rebuild", push=False)
        r = self.rebuild("n\n")
        self.assertEqual(r.returncode, 1)
        self.assertIn("Commits since deploy/jacurutu/20261029T100000Z:", r.stdout)
        self.assertIn(" two\n", r.stdout)
        self.assertNotIn(" one\n", r.stdout)

    def test_unknown_argument(self) -> None:
        for args in [("--bogus",), ("build",), ("--key",), ("--unsigned", "dry-run")]:
            with self.subTest(args=args):
                r = self.rebuild("y\n", args=args)
                self.assertEqual(r.returncode, 2)
                self.assertIn("usage: rebuild", r.stderr)
                self.assertEqual(self.sudo_calls(), [])


class FleetTags(DeployGate):
    def verify(self, tag: str) -> subprocess.CompletedProcess[str]:
        return self.run_cmd(["deploy-tag", "verify", tag])

    def test_a_fleet_tag_verifies(self) -> None:
        self.sign(T1, "yk", message="deploy jacurutu sietch\nHosts: jacurutu sietch\n\nabc1234 two")
        r = self.verify(T1)
        self.assertEqual(r.returncode, 0, r.stderr)
        for host, code in [("sietch", 0), ("jacurutu", 0), ("tleilax", 1), ("sie", 1)]:
            with self.subTest(host=host):
                r = self.run_cmd(["deploy-tag", "names-host", T1, host])
                self.assertEqual(r.returncode, code, r.stderr)

    def test_the_hosts_line_rules(self) -> None:
        bad = {
            "no hosts line": "deploy sietch",
            "hosts after the first paragraph": "deploy sietch\n\nHosts: sietch",
            "two hosts lines": "deploy sietch\nHosts: sietch\nHosts: tleilax",
            "an empty list": "deploy sietch\nHosts:",
            "a double space": "deploy sietch\nHosts:  sietch",
            "a capital": "deploy sietch\nHosts: Sietch",
            "the fleet name": "deploy sietch\nHosts: sietch fleet",
        }
        for i, (name, message) in enumerate(bad.items()):
            with self.subTest(name):
                tag = f"deploy/fleet/20261029T1{i}0000Z"
                self.sign(tag, "yk", message=message, push=False)
                r = self.verify(tag)
                self.assertEqual(r.returncode, 1)
                self.assertIn("needs one 'Hosts: <host>...' line", r.stderr)
                self.assertEqual(
                    self.run_cmd(["deploy-tag", "names-host", tag, "sietch"]).returncode, 1
                )

    def test_an_old_tag_still_verifies_but_names_no_host(self) -> None:
        self.sign(OLD1, "yk", message="deploy sietch", push=False)
        self.assertEqual(self.verify(OLD1).returncode, 0)
        self.assertEqual(self.run_cmd(["deploy-tag", "names-host", OLD1, "sietch"]).returncode, 1)

    def test_a_host_not_listed_is_refused(self) -> None:
        self.sign(T1, "yk", message="deploy jacurutu tleilax\nHosts: jacurutu tleilax")
        r = self.receive()
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("no deploy tag names sietch yet", r.stderr)
        self.assertNotIn("refusing", r.stderr)
        self.assertEqual(self.rebuilds(), [])
        self.sign(T2, "yk", message="deploy jacurutu sietch\nHosts: jacurutu sietch")
        self.assertEqual(self.receive().returncode, 0)
        self.assertEqual((self.state / "deployed").read_text(), f"{T2} {self.tip}\n")
        # A newer tag for other hosts is skipped, not counted as refused.
        self.push_commit("c")
        self.sign(T3, "yk", message="rebuild jacurutu\nHosts: jacurutu")
        r = self.receive()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn(f"No deploy tag for sietch newer than {T2}", r.stdout)
        self.assertEqual(self.running(), self.tip)

    def test_per_host_tags_are_ignored(self) -> None:
        self.sign(OLD1, "yk", message="deploy sietch")
        r = self.receive()
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("no deploy tag names sietch yet", r.stderr)
        self.assertEqual(self.rebuilds(), [])
        self.assertEqual(self.git("tag", "-l", cwd=self.state / "dotfiles.git"), "")

    def test_an_old_state_entry_is_compared_by_time(self) -> None:
        # The old receiver deployed OLD2 (11:00). A comparison of whole names
        # would put every deploy/fleet tag before deploy/sietch.
        (self.state / "deployed").write_text(f"{OLD2} {self.rev('HEAD^')}\n")
        self.sign(T1, "yk")
        self.sign(T2, "yk", rev="HEAD^")
        for _ in range(2):
            r = self.receive()
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            self.assertIn(f"No deploy tag for sietch newer than {OLD2}", r.stdout)
            self.assertEqual(self.rebuilds(), [])
        self.sign(T3, "yk")
        r = self.receive()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(self.rebuilds(), self.deploy_lines(self.tip))
        self.assertEqual((self.state / "deployed").read_text(), f"{T3} {self.tip}\n")

    def test_a_replayed_fleet_tag_of_an_older_or_equal_time_is_refused(self) -> None:
        self.sign(T2, "yk", rev="HEAD^")
        self.assertEqual(self.receive().returncode, 0)
        # T1 is older; an old per-host tag of T2's time names nobody here.
        self.sign(T1, "yk")
        self.sign(OLD2, "yk", message="deploy sietch")
        r = self.receive()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn(f"No deploy tag for sietch newer than {T2}", r.stdout)
        self.assertEqual(self.running(), self.rev("HEAD^"))
        self.assertEqual(len(self.rebuilds()), 2)

    def test_an_unreadable_state_file_stops_the_receiver(self) -> None:
        (self.state / "deployed").write_text("whatever 0123\n")
        self.sign(T1, "yk")
        r = self.receive()
        self.assertEqual(r.returncode, 1)
        self.assertIn("can't read the last deployed tag", r.stderr)
        self.assertEqual(self.rebuilds(), [])

    def test_the_override_is_still_needed_for_a_rollback(self) -> None:
        older = self.rev("HEAD^")
        self.set_running(self.tip)
        self.sign(T1, "yk", rev=older, message="deploy jacurutu sietch\nHosts: jacurutu sietch")
        self.assert_refused(f"{older} doesn't descend from {self.tip}")
        self.sign(
            T2, "yk", rev=older,
            message="deploy sietch\nAllow-Rollback: yes\nHosts: jacurutu sietch",
        )
        self.assertEqual(self.receive().returncode, 0)
        self.assertEqual(self.running(), older)


class FleetDeployTag(DeployGate):
    def sign_with(self, *args: str, message: str | None = None) -> subprocess.CompletedProcess[str]:
        extra = ["--message", message] if message is not None else []
        return self.run_cmd(["deploy-tag", "sign", "--key", str(KEYS["yk"]), *extra, *args])

    def test_sign_makes_one_fleet_tag_for_its_hosts(self) -> None:
        r = self.sign_with(
            "jacurutu", "sietch", "HEAD",
            message="deploy jacurutu sietch\nAllow-Rollback: yes\n\nabc1234 two\n\nmore",
        )
        self.assertEqual(r.returncode, 0, r.stderr)
        tag = r.stdout.strip()
        self.assertRegex(tag, r"^deploy/fleet/[0-9]{8}T[0-9]{6}Z$")
        self.assertIn(
            "\n\ndeploy jacurutu sietch\nAllow-Rollback: yes\nHosts: jacurutu sietch\n\n"
            "abc1234 two\n\nmore\n-----BEGIN SSH SIGNATURE-----\n",
            self.git("cat-file", "tag", tag),
        )
        for host in ["jacurutu", "sietch"]:
            self.assertEqual(self.run_cmd(["deploy-tag", "names-host", tag, host]).returncode, 0)
        self.assertEqual(self.run_cmd(["deploy-tag", "allows-rollback", tag]).returncode, 0)

    def test_sign_without_a_message(self) -> None:
        r = self.sign_with("sietch", "HEAD")
        self.assertEqual(r.returncode, 0, r.stderr)
        tag = r.stdout.strip()
        self.assertIn("\ndeploy sietch\nHosts: sietch\n", self.git("cat-file", "tag", tag))

    def test_sign_refuses_a_bad_host_list(self) -> None:
        cases = {
            "fleet": (["fleet", "HEAD"], None, "bad host name: fleet"),
            "capital": (["Sietch", "HEAD"], None, "bad host name: Sietch"),
            "twice": (["sietch", "jacurutu", "sietch", "HEAD"], None, "a host is named twice"),
            "hosts in the message": (["sietch", "HEAD"], "deploy\nHosts: tleilax", "already has a Hosts: line"),
        }
        for name, (args, message, error) in cases.items():
            with self.subTest(name):
                r = self.sign_with(*args, message=message)
                self.assertEqual(r.returncode, 1)
                self.assertIn(error, r.stderr)
                self.assertNotIn("touch the key", r.stderr)
                self.assertEqual(self.git("tag", "-l"), "")

    def approves(self, tag: str, host: str, obj: str, commit: str) -> subprocess.CompletedProcess[str]:
        return self.run_cmd(["deploy-tag", "approves", tag, host, obj, commit])

    def assert_refuses(self, r: subprocess.CompletedProcess[str], reason: str) -> None:
        self.assertEqual(r.returncode, 1, r.stderr)
        self.assertIn(reason, r.stderr)

    def test_approves_holds_a_tag_to_what_was_checked(self) -> None:
        self.sign(T1, "yk", message="deploy jacurutu\nHosts: jacurutu", push=False)
        obj = self.rev(f"refs/tags/{T1}")
        older = self.rev("HEAD^")
        self.assertEqual(self.approves(T1, "jacurutu", obj, self.tip).returncode, 0)
        self.assert_refuses(self.approves(T1, "sietch", obj, self.tip), "Hosts: line doesn't name sietch")
        self.assert_refuses(self.approves(T1, "jacurutu", obj, older), f"points at {self.tip}, not {older}")
        self.assert_refuses(self.approves(T1, "jacurutu", "HEAD", self.tip), "expected a tag object")
        self.sign(OLD1, "yk", message="deploy sietch", push=False)
        self.assert_refuses(
            self.approves(OLD1, "sietch", self.rev(f"refs/tags/{OLD1}"), self.tip),
            "only a fleet tag can approve a build",
        )

    def test_approves_refuses_a_tag_moved_or_replaced(self) -> None:
        self.sign(T1, "yk", message="deploy jacurutu\nHosts: jacurutu", push=False)
        obj = self.rev(f"refs/tags/{T1}")
        for how in ["unsigned", "for sietch"]:
            with self.subTest(how):
                r = self.run_cmd(["bash", "-c", self.retag(how)])
                self.assertEqual(r.returncode, 0, r.stderr)
                now = self.rev(f"refs/tags/{T1}")
                self.assert_refuses(
                    self.approves(T1, "jacurutu", obj, self.tip),
                    f"it now resolves to {now}, not {obj}",
                )
                # Checking the replacement itself fails too.
                if how == "unsigned":
                    self.assertEqual(self.approves(T1, "jacurutu", now, self.rev("HEAD^")).returncode, 1)
                else:
                    self.assert_refuses(
                        self.approves(T1, "jacurutu", now, self.rev("HEAD^")),
                        "Hosts: line doesn't name jacurutu",
                    )

    def test_latest_takes_fleet_and_old_tags_by_time(self) -> None:
        self.sign(OLD1, "yk", rev="HEAD^", message="deploy sietch", push=False)
        self.sign(T2, "yk", message="rebuild jacurutu\nHosts: jacurutu", push=False)
        r = self.run_cmd(["deploy-tag", "latest", "sietch"])
        self.assertEqual((r.returncode, r.stdout), (0, f"{OLD1} {self.rev('HEAD^')}\n"), r.stderr)
        r = self.run_cmd(["deploy-tag", "latest", "jacurutu"])
        self.assertEqual(r.stdout, f"{T2} {self.tip}\n")
        self.sign(T3, "yk", push=False)
        r = self.run_cmd(["deploy-tag", "latest", "sietch"])
        self.assertEqual(r.stdout, f"{T3} {self.tip}\n")
        self.sign("deploy/sietch/20261029T130000Z", "yk", rev="HEAD^", message="deploy", push=False)
        r = self.run_cmd(["deploy-tag", "latest", "sietch"])
        self.assertEqual(r.stdout, f"deploy/sietch/20261029T130000Z {self.rev('HEAD^')}\n")
        self.assertEqual(self.run_cmd(["deploy-tag", "latest", "tleilax"]).returncode, 1)
        r = self.run_cmd(["deploy-tag", "latest", "fleet"])
        self.assertEqual(r.returncode, 1)
        self.assertIn("bad host name: fleet", r.stderr)


class FleetDeploy(DeployGate):
    def setUp(self) -> None:
        super().setUp()
        self.tleilax = self.add_tleilax(self.rev("HEAD^"))

    def deployed_tags(self) -> list[str]:
        return self.git("tag", "-l", "deploy/*", cwd=self.origin).splitlines()

    def test_one_tag_deploys_the_whole_fleet(self) -> None:
        # Uncommitted changes in ~/dotfiles stay out of jacurutu's build.
        (self.work / "file").write_text("dirty")
        r = self.deploy("--yes", "--key", str(KEYS["yk"]))
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        [tag] = self.deployed_tags()
        self.assertEqual(r.stderr.count("touch the key to sign"), 1)
        self.assertEqual(r.stderr.count("to push"), 1)
        self.assertIn("\nHosts: jacurutu sietch tleilax\n", self.git("cat-file", "tag", tag))
        for host in ["sietch", "tleilax"]:
            self.assertIn(f"{host}: Building {tag}", r.stdout)
            self.assertIn(f"{host}: {host} deployed {tag} {self.tip}\n", r.stdout)
        self.assertEqual(self.running(), self.tip)
        self.assertEqual((self.tleilax / "running").read_text().strip(), self.tip)
        self.assertEqual(
            self.rebuilds(self.tleilax)[0],
            f"build --no-update-lock-file --flake git+file://{self.tleilax}/state/dotfiles.git"
            f"?rev={self.tip}#tleilax",
        )
        self.assertEqual(
            self.lines("waits"), [f"-C {self.work} --key {KEYS['yk']} --commit {self.tip} {tag}"]
        )
        self.assertEqual(self.rebuilds(self.local), [self.tagged_build(self.tip)])
        self.assertEqual(self.local_running(), self.tip)
        self.assertTrue(
            r.stdout.endswith(
                f"Deploy of {self.tip[:12]}:\n  jacurutu runs {tag}\n"
                f"  sietch runs {tag}\n  tleilax runs {tag}\n"
            ),
            r.stdout,
        )

        r = self.deploy("--yes", "--key", str(KEYS["yk"]))
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("nothing to sign", r.stdout)
        self.assertEqual(self.deployed_tags(), [tag])
        self.assertEqual(
            self.lines("waits"),
            [f"-C {self.work} --key {KEYS['yk']} --commit {self.tip} {tag}"] * 2,
        )
        self.assertEqual(self.rebuilds(self.local), [self.tagged_build(self.tip)] * 2)

    def test_receivers_deploy_in_parallel(self) -> None:
        # Each build waits until both have started; one at a time would fail.
        both = (
            f'for _ in $(seq 100); do [[ -e "{self.tmp}/rebuilds" && -e "{self.tleilax}/rebuilds" ]]'
            " && exit 0; sleep 0.1; done; exit 1"
        )
        r = self.deploy("--yes", "--key", str(KEYS["yk"]), "sietch", "tleilax", TEST_DURING_BUILD=both)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(self.running(), self.tip)
        self.assertEqual((self.tleilax / "running").read_text().strip(), self.tip)

    def test_hosts_are_named_once_in_fleet_order(self) -> None:
        r = self.deploy("--yes", "--key", str(KEYS["yk"]), "sietch", "jacurutu", "sietch")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        [tag] = self.deployed_tags()
        self.assertIn("\nHosts: jacurutu sietch\n", self.git("cat-file", "tag", tag))
        self.assertEqual(self.rebuilds(self.tleilax), [])

    def test_a_failed_host_fails_the_deploy_and_not_the_others(self) -> None:
        (self.tleilax / "running").unlink()
        r = self.deploy("--yes", "--key", str(KEYS["yk"]))
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        [tag] = self.deployed_tags()
        self.assertIn("tleilax: deploy-tag: refusing", r.stdout)
        self.assertIn("can't read the commit tleilax runs", r.stdout)
        self.assertIn(f"  jacurutu runs {tag}\n", r.stdout)
        self.assertIn(f"  sietch runs {tag}\n", r.stdout)
        self.assertIn("  tleilax failed: the deploy exited 1; see its log above\n", r.stdout)
        self.assertIn("deploy: failed on tleilax", r.stderr)
        self.assertEqual(self.running(), self.tip)

    def test_no_wait(self) -> None:
        r = self.deploy("--yes", "--no-wait", "--key", str(KEYS["yk"]), "jacurutu")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(self.lines("waits"), [])
        self.assertEqual(self.rebuilds(self.local), [self.tagged_build(self.tip)])
        self.assertEqual(self.rebuilds(), [])

    def test_a_declined_wait_leaves_jacurutu_alone(self) -> None:
        r = self.deploy("--yes", "--key", str(KEYS["yk"]), "jacurutu", "sietch", TEST_WAIT_EXIT="1")
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        [tag] = self.deployed_tags()
        self.assertEqual(self.lines("sudo"), [])
        self.assertIn("  jacurutu not rebuilt: CI hadn't published what it needs\n", r.stdout)
        self.assertIn(f"  sietch runs {tag}\n", r.stdout)
        self.assertEqual(self.running(), self.tip)

    def test_a_failed_switch_is_reported(self) -> None:
        r = self.deploy("--yes", "--key", str(KEYS["yk"]), "jacurutu", NIXOS_REBUILD_EXIT="3")
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("  jacurutu failed: the switch exited 3; see above\n", r.stdout)

    def test_lists_commits_since_the_oldest_last_tag(self) -> None:
        self.sign(OLD1, "yk", rev="HEAD^", message="deploy sietch")
        self.sign(T2, "yk", message="rebuild jacurutu\nHosts: jacurutu")
        four = self.push_commit("four")
        r = self.deploy("--yes", "--key", str(KEYS["yk"]), "jacurutu", "sietch")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn(f"Commits on nixos since {OLD1}:", r.stdout)
        self.assertIn(" two\n", r.stdout)
        self.assertIn(" four\n", r.stdout)
        self.assertEqual(self.rebuilds(self.local), [self.tagged_build(four)])

    def ahead_of_nixos(self) -> str:
        """Run jacurutu on a commit after nixos's tip, as a rebuild would."""
        self.commit("ahead")
        ahead = self.rev("HEAD")
        (self.local / "running").write_text(ahead + "\n")
        return ahead

    def test_jacurutu_is_not_moved_back(self) -> None:
        # The review's repro: nixos's tip already has a fleet tag, and
        # jacurutu runs a later commit.
        self.sign(T1, "yk", message="deploy jacurutu sietch\nHosts: jacurutu sietch")
        ahead = self.ahead_of_nixos()
        r = self.deploy("--yes", "--no-wait", "--key", str(KEYS["yk"]), "jacurutu", "sietch")
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("nothing to sign", r.stdout)
        self.assertIn(f"refusing {T1}: {self.tip} doesn't descend from {ahead}, which jacurutu runs", r.stderr)
        self.assertIn(f"  jacurutu failed: {T1} would move it off the commit it runs; see above\n", r.stdout)
        self.assertIn(f"  sietch runs {T1}\n", r.stdout)
        self.assertIn("deploy: failed on jacurutu", r.stderr)
        self.assertEqual(self.local_running(), ahead)
        self.assertEqual(self.lines("sudo"), [])
        self.assertEqual(self.running(), self.tip)

    def test_a_tag_moved_during_the_wait_is_refused_on_jacurutu(self) -> None:
        for how in ["unsigned", "for sietch"]:
            with self.subTest(how):
                r = self.deploy(
                    "--yes", "--key", str(KEYS["yk"]), "jacurutu", TEST_DURING_WAIT=self.retag(how)
                )
                self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
                self.assertIn("it now resolves to", r.stderr)
                self.assertIn("  jacurutu failed: the switch exited 1; see above\n", r.stdout)
                self.assertEqual(self.rebuilds(self.local), [])
                self.assertEqual(self.local_running(), self.rev("HEAD^"))

    def test_the_first_fleet_deploy_after_the_switch_signs_a_fleet_tag(self) -> None:
        # The switch-over left old per-host tags at the tip, which approve
        # nothing on their own.
        self.sign("deploy/jacurutu/20261029T100000Z", "yk", message="rebuild")
        self.sign(OLD2, "yk", message="deploy sietch")
        r = self.deploy("--yes", "--key", str(KEYS["yk"]), "jacurutu", "sietch")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertNotIn("nothing to sign", r.stdout)
        [tag] = [t for t in self.deployed_tags() if t.startswith("deploy/fleet/")]
        self.assertIn(f"  jacurutu runs {tag}\n", r.stdout)
        self.assertEqual(self.rebuilds(self.local), [self.tagged_build(self.tip)])

    def test_jacurutu_needs_to_know_what_it_runs(self) -> None:
        (self.local / "running").unlink()
        r = self.deploy("--yes", "--key", str(KEYS["yk"]), "jacurutu")
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("can't read the commit jacurutu runs", r.stderr)
        self.assertEqual(self.lines("waits"), [])
        self.assertEqual(self.lines("sudo"), [])

    def test_a_switch_that_lands_while_this_one_waits_for_the_lock_wins(self) -> None:
        # Tony's rebuild of a later commit holds the lock and finishes first.
        ahead = self.ahead_of_nixos()
        (self.local / "running").write_text(self.rev("HEAD^^") + "\n")
        lock = self.tmp / "switch.lock"
        # It switches once deploy-switch, past its first check, asks sudo.
        holder = subprocess.Popen(
            [
                "flock", str(lock), "bash", "-c",
                f'for _ in $(seq 300); do [[ -s "{self.tmp}/sudo" ]] && break; sleep 0.1; done; '
                f'sleep 0.5; echo {ahead} > "{self.local}/running"',
            ]
        )
        try:
            while subprocess.run(["flock", "--nonblock", str(lock), "true"]).returncode == 0:
                pass
            r = self.deploy("--yes", "--no-wait", "--key", str(KEYS["yk"]), "jacurutu")
        finally:
            holder.wait(timeout=30)
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn(f"{self.tip} doesn't descend from {ahead}, which jacurutu runs", r.stderr)
        self.assertIn("jacurutu changed while this switch waited for the lock", r.stderr)
        self.assertIn("  jacurutu failed: the switch exited 1; see above\n", r.stdout)
        self.assertEqual(self.rebuilds(self.local), [])
        self.assertEqual(self.local_running(), ahead)

    def test_a_signed_rollback_moves_jacurutu_back(self) -> None:
        self.ahead_of_nixos()
        code, out = self.at_terminal(
            ["bash", str(SCRIPTS / "deploy.sh"), "--allow-rollback", "--key", str(KEYS["yk"]), "jacurutu"],
            "y\n",
            extra_env={"TEST_ROOT": str(self.local)},
        )
        self.assertEqual(code, 0, out)
        [tag] = self.deployed_tags()
        self.assertIn("\nAllow-Rollback: yes\nHosts: jacurutu\n", self.git("cat-file", "tag", tag))
        self.assertEqual(self.local_running(), self.tip)

    def test_one_fleet_deploy_picks_the_key_once(self) -> None:
        self.install_key("yk", "yk-nano-deploy")
        code, out = self.at_terminal(
            ["bash", str(SCRIPTS / "deploy.sh")],
            "y\n",
            extra_env={"TEST_ROOT": str(self.local), "TEST_YKMAN_LIST": NANO},
        )
        self.assertEqual(code, 0, out)
        [tag] = self.deployed_tags()
        self.assertEqual(self.ykman_calls(), ["list"])
        self.assertIn("signing with yk-nano-deploy, the deploy key", out)
        self.assertIn(
            f"Sign deploy/fleet for jacurutu sietch tleilax at {self.tip[:12]} "
            "with yk-nano-deploy and deploy it?",
            out,
        )
        self.assertEqual(out.count("touch the key to sign"), 1)
        self.assertIn(f"touch yk-nano-deploy again to push {tag}", out)
        self.assertIn(f"  tleilax runs {tag}", out)

    def test_without_a_deploy_yubikey_the_fleet_deploy_stops_before_asking(self) -> None:
        self.install_key("yk", "yk-nfc-deploy")
        r = self.deploy("--yes", TEST_YKMAN_LIST=OTHER)
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("no deploy YubiKey is plugged in", r.stderr)
        self.assertIn("deploy: nothing was signed", r.stderr)
        self.assertEqual(self.deployed_tags(), [])
        self.assertNotIn("Starting the deploy", r.stdout)
        self.assertEqual(self.rebuilds(), [])
        self.assertEqual(self.rebuilds(self.tleilax), [])
        self.assertEqual(self.lines("waits"), [])
        self.assertEqual(self.lines("sudo"), [])

    def test_key_flag_and_nothing_to_sign_never_ask_ykman(self) -> None:
        r = self.deploy("--yes", "--key", str(KEYS["yk"]), TEST_YKMAN_LIST="")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        r = self.deploy("--yes", TEST_YKMAN_LIST="")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("nothing to sign", r.stdout)
        self.assertEqual(self.ykman_calls(), [])
        self.assertEqual(len(self.deployed_tags()), 1)
        self.assertEqual(self.rebuilds(self.local), [self.tagged_build(self.tip)] * 2)
        # deploy-wait hears the key it was given, for its push hint.
        [tag] = self.deployed_tags()
        self.assertEqual(
            self.lines("waits"),
            [
                f"-C {self.work} --key {KEYS['yk']} --commit {self.tip} {tag}",
                f"-C {self.work} --commit {self.tip} {tag}",
            ],
        )

    def test_a_rewritten_tag_of_any_host_needs_a_terminal(self) -> None:
        self.sign(OLD1, "yk", rev="HEAD^", message="deploy sietch")
        self.sign(T2, "yk", rev=self.side, message="deploy tleilax\nHosts: tleilax")
        r = self.deploy("--yes", "--key", str(KEYS["yk"]), "sietch", "tleilax")
        self.assertEqual(r.returncode, 1)
        self.assertIn(f"nixos no longer contains {T2}", r.stdout)
        self.assertIn(f"Commits on nixos since {OLD1}:", r.stdout)
        self.assertIn("needs a terminal to confirm", r.stderr)


class DeployWait(DeployGate):
    """deploy-wait.sh itself, with stubs for gh and the planner."""

    def setUp(self) -> None:
        super().setUp()
        (self.work / "ci").mkdir()
        (self.work / "ci/cache-targets.py").write_text("committed planner\n")
        self.git("add", "ci")
        self.git("commit", "-q", "-m", "ci")
        self.tip = self.rev("HEAD")
        self.sign(T1, "yk", message="rebuild jacurutu\nHosts: jacurutu")
        (self.work / "ci/cache-targets.py").write_text("uncommitted planner\n")
        (self.tmp / "gh").mkdir()
        bin_dir = self.tmp / "wait-bin"
        bin_dir.mkdir()
        stubs = {
            "python3": (
                '[[ $# == 3 && $1 == */ci/cache-targets.py && $2 == heavy ]] || exit 96\n'
                f'printf "%s\\n" "$3" > "{self.tmp}/planner-flake"\n'
                f'cp "$1" "{self.tmp}/planner-script"\n'
                '[[ ${TEST_PLANNER_EXIT:-0} == 0 ]] || exit "$TEST_PLANNER_EXIT"\n'
                f'cat "{self.tmp}/heavy.json"'
            ),
            # Each call of `gh run list` or `gh run view` answers with the
            # next numbered response, repeating the last one.
            "gh": (
                f'd="{self.tmp}/gh"\n'
                'echo "$*" >> "$d/calls"\n'
                '[[ $1 == run && ( $2 == list || $2 == view ) ]] || exit 91\n'
                'n=$(( $(cat "$d/$2.n" 2>/dev/null || echo 0) + 1 ))\n'
                'echo "$n" > "$d/$2.n"\n'
                'while [[ ! -e $d/$2.$n ]] && ((n > 1)); do n=$((n - 1)); done\n'
                '[[ -e $d/$2.$n ]] || { echo "gh: no $2 response" >&2; exit 1; }\n'
                'if [[ $(head -c 5 "$d/$2.$n") == fail: ]]; then cat "$d/$2.$n" >&2; exit 1; fi\n'
                'cat "$d/$2.$n"'
            ),
        }
        for name, body in stubs.items():
            (bin_dir / name).write_text(f"#!/usr/bin/env bash\n{body}\n")
            (bin_dir / name).chmod(0o755)
        self.env["PATH"] = f"{bin_dir}:{self.env['PATH']}"
        self.env.update(DEPLOY_WAIT_POLL="0", DEPLOY_WAIT_FIND="3", DEPLOY_WAIT_TIMEOUT="20")
        self.cmd = ["bash", str(SCRIPTS / "deploy-wait.sh"), "-C", str(self.work), T1]

    def heavy(self, names: list[str] | str) -> None:
        (self.tmp / "heavy.json").write_text(names if isinstance(names, str) else json.dumps(names))

    def respond(self, kind: str, *responses: object) -> None:
        for i, response in enumerate(responses, 1):
            text = response if isinstance(response, str) else json.dumps(response)
            (self.tmp / f"gh/{kind}.{i}").write_text(text)

    def found(self) -> None:
        self.respond("list", [{"databaseId": 7, "url": "https://example.com/runs/7"}])

    def gh_calls(self) -> list[str]:
        path = self.tmp / "gh/calls"
        return path.read_text().splitlines() if path.exists() else []

    @staticmethod
    def run_json(status: str, *jobs: tuple[str, str, str | None], conclusion: str | None = None) -> dict:
        return {
            "status": status,
            "conclusion": conclusion,
            "jobs": [{"name": n, "status": s, "conclusion": c} for n, s, c in jobs],
        }

    def wait(self, **extra: str) -> subprocess.CompletedProcess[str]:
        return self.run_cmd(self.cmd, extra_env=extra)

    def test_nothing_heavy_builds_at_once(self) -> None:
        self.heavy([])
        r = self.wait()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("Every heavy package is in the local store or the cache.", r.stdout)
        self.assertEqual(self.gh_calls(), [])
        # The planner comes from the tagged commit and evaluates it by rev.
        self.assertEqual((self.tmp / "planner-script").read_text(), "committed planner\n")
        self.assertEqual(
            (self.tmp / "planner-flake").read_text(),
            f"git+file://{self.work.resolve()}?rev={self.tip}\n",
        )

    def test_waits_for_exactly_the_listed_packages(self) -> None:
        self.heavy(["niri", "ghostty"])
        self.respond("list", [], [{"databaseId": 7, "url": "https://example.com/runs/7"}])
        self.respond(
            "view",
            self.run_json("in_progress", ("plan", "in_progress", None)),
            self.run_json(
                "in_progress",
                ("plan", "completed", "success"),
                ("build niri", "in_progress", None),
                ("build dictator", "in_progress", None),
            ),
            self.run_json(
                "in_progress",
                ("plan", "completed", "success"),
                ("build niri", "completed", "success"),
                ("build dictator", "in_progress", None),
            ),
        )
        r = self.wait()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("Without CI this build would compile: niri ghostty", r.stdout)
        self.assertIn("Waiting for CI to publish them: https://example.com/runs/7", r.stdout)
        self.assertIn("Waiting on niri: plan in_progress, ghostty: plan in_progress.", r.stdout)
        self.assertIn("ghostty was in the cache by the time CI planned.", r.stdout)
        self.assertIn("CI published niri.", r.stdout)
        self.assertTrue(r.stdout.endswith("CI has published everything this build needs.\n"), r.stdout)
        calls = self.gh_calls()
        lists = [c for c in calls if c.startswith("run list")]
        self.assertEqual(len(lists), 2)
        for call in lists:
            self.assertIn(f"--workflow cache.yml --branch {T1} --event push", call)
            self.assertIn("--repo owner/dotfiles", call)
        self.assertEqual(
            [c for c in calls if c.startswith("run view")],
            ["run view 7 --repo owner/dotfiles --json status,conclusion,jobs"] * 3,
        )

    def test_a_failed_job_asks(self) -> None:
        self.heavy(["niri"])
        self.found()
        self.respond(
            "view",
            self.run_json("in_progress", ("plan", "completed", "success"), ("build niri", "completed", "failure")),
        )
        r = self.wait()
        self.assertEqual(r.returncode, 1)
        self.assertIn("CI didn't publish niri (its job ended failure).", r.stdout)
        self.assertIn("no terminal to ask whether to build locally", r.stderr)
        for typed, code in [("y\n", 0), ("n\n", 1), ("\n", 1)]:
            with self.subTest(typed=typed):
                got, out = self.at_terminal(self.cmd, typed)
                self.assertEqual(got, code, out)
                self.assertIn("Build locally anyway? [y/N]", out)

    def test_a_failed_plan_or_run_asks(self) -> None:
        self.heavy(["niri"])
        self.found()
        cases = {
            "the plan ended failure": self.run_json(
                "completed", ("plan", "completed", "failure"), conclusion="failure"
            ),
            "the run ended cancelled before building it": self.run_json(
                "completed", conclusion="cancelled"
            ),
        }
        for reason, view in cases.items():
            with self.subTest(reason):
                (self.tmp / "gh/view.n").unlink(missing_ok=True)
                self.respond("view", view)
                r = self.wait()
                self.assertEqual(r.returncode, 1)
                self.assertIn(f"CI didn't publish niri ({reason}).", r.stdout)

    def test_a_package_without_a_job_after_the_plan_was_cached(self) -> None:
        self.heavy(["niri"])
        self.found()
        self.respond(
            "view",
            self.run_json("in_progress", ("plan", "completed", "success")),
            self.run_json(
                "completed",
                ("plan", "completed", "success"),
                ("build ${{ matrix.package }}", "completed", "skipped"),
                conclusion="success",
            ),
        )
        r = self.wait()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("Waiting on niri: plan done.", r.stdout)
        self.assertIn("niri was in the cache by the time CI planned.", r.stdout)

    def test_a_run_cancelled_before_its_build_jobs_is_no_cache_hit(self) -> None:
        # The review's repro: the plan succeeds, then the run is cancelled
        # before the build matrix exists.
        self.heavy(["niri"])
        self.found()
        views = {
            "no build job": self.run_json(
                "completed", ("plan", "completed", "success"), conclusion="cancelled"
            ),
            "an unexpanded build job": self.run_json(
                "completed",
                ("plan", "completed", "success"),
                ("build ${{ matrix.package }}", "completed", "cancelled"),
                conclusion="cancelled",
            ),
        }
        for name, view in views.items():
            with self.subTest(name):
                (self.tmp / "gh/view.n").unlink(missing_ok=True)
                self.respond("view", view)
                r = self.wait()
                self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
                self.assertNotIn("in the cache", r.stdout)
                self.assertIn(
                    "CI didn't publish niri (the run ended cancelled before building it).", r.stdout
                )
                code, out = self.at_terminal(self.cmd, "y\n")
                self.assertEqual(code, 0, out)

    def test_a_package_left_out_of_the_build_matrix_was_cached(self) -> None:
        # Another package's build failed; niri was never planned.
        self.heavy(["niri"])
        self.found()
        self.respond(
            "view",
            self.run_json(
                "completed",
                ("plan", "completed", "success"),
                ("build ghostty", "completed", "failure"),
                conclusion="failure",
            ),
        )
        r = self.wait()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("niri was in the cache by the time CI planned.", r.stdout)

    def test_a_tag_missing_from_github_skips_the_wait(self) -> None:
        self.heavy(["niri"])
        self.found()
        self.sign(T2, "yk", message="rebuild jacurutu\nHosts: jacurutu", push=False)
        r = self.run_cmd(["bash", str(SCRIPTS / "deploy-wait.sh"), "-C", str(self.work), T2])
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn(f"{T2} isn't on GitHub, so no CI run builds for it. Building without waiting.", r.stdout)
        self.assertIn(f"Push it with: deploy-tag -C {self.work.resolve()} push --key <its key file> {T2}", r.stdout)
        self.assertEqual(self.gh_calls(), [])
        self.assertFalse((self.tmp / "planner-flake").exists())

    def test_it_plans_the_commit_it_is_given(self) -> None:
        self.heavy([])
        self.commit("later")
        self.git("tag", "--no-sign", "-f", T1, "HEAD")
        r = self.run_cmd(
            ["bash", str(SCRIPTS / "deploy-wait.sh"), "-C", str(self.work), "--commit", self.tip, T1]
        )
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(
            (self.tmp / "planner-flake").read_text(),
            f"git+file://{self.work.resolve()}?rev={self.tip}\n",
        )

    def test_the_push_hint_names_the_key_it_is_given(self) -> None:
        self.sign(T2, "yk", message="rebuild jacurutu\nHosts: jacurutu", push=False)
        r = self.run_cmd(
            ["bash", str(SCRIPTS / "deploy-wait.sh"), "-C", str(self.work), "--key", "/keys/yk-nano-deploy", T2]
        )
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn(f"push --key /keys/yk-nano-deploy {T2}", r.stdout)
        self.assertNotIn("<its key file>", r.stdout)

    def test_an_unreachable_remote_still_looks_for_the_run(self) -> None:
        self.heavy([])
        r = self.wait(DEPLOY_REPO_URL=f"file://{self.tmp}/nowhere.git")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("Every heavy package is in the local store or the cache.", r.stdout)

    def test_a_job_waiting_for_approval_says_so(self) -> None:
        self.heavy(["niri"])
        self.found()
        self.respond(
            "view",
            self.run_json("waiting", ("plan", "completed", "success"), ("build niri", "waiting", None)),
            self.run_json("completed", ("plan", "completed", "success"), ("build niri", "completed", "success")),
        )
        r = self.wait()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("needs its cache-publish deployment approved", r.stdout)

    def test_no_run_turns_up(self) -> None:
        self.heavy(["niri"])
        self.respond("list", [])
        r = self.wait(DEPLOY_WAIT_FIND="1")
        self.assertEqual(r.returncode, 1)
        self.assertIn(f"GitHub shows no cache run for {T1} after 1s.", r.stdout)

    def test_unreadable_github_keeps_trying_until_the_timeout(self) -> None:
        self.heavy(["niri"])
        self.found()
        self.respond("view", "fail: HTTP 502")
        r = self.wait(DEPLOY_WAIT_TIMEOUT="1")
        self.assertEqual(r.returncode, 1)
        self.assertEqual(r.stderr.count("can't read the run yet: fail: HTTP 502"), 1)
        self.assertIn("CI hasn't published niri after 1s.", r.stdout)

    def test_a_timeout_asks(self) -> None:
        self.heavy(["niri"])
        self.found()
        self.respond("view", self.run_json("in_progress", ("plan", "completed", "success"), ("build niri", "in_progress", None)))
        r = self.wait(DEPLOY_WAIT_TIMEOUT="1")
        self.assertEqual(r.returncode, 1)
        self.assertIn("CI hasn't published niri after 1s. https://example.com/runs/7", r.stdout)

    def start_polling(self, extra: dict[str, str] | None = None, **popen: object) -> subprocess.Popen:
        self.heavy(["niri"])
        self.found()
        self.respond("view", self.run_json("in_progress", ("plan", "completed", "success"), ("build niri", "in_progress", None)))
        proc = subprocess.Popen(
            self.cmd,
            cwd=self.work,
            env={**self.env, "DEPLOY_WAIT_POLL": "1", "DEPLOY_WAIT_TIMEOUT": "60", **(extra or {})},
            start_new_session=True,
            text=True,
            **popen,  # type: ignore[arg-type]
        )
        deadline = time.monotonic() + 30
        while not any(c.startswith("run view") for c in self.gh_calls()):
            self.assertLess(time.monotonic(), deadline, "deploy-wait never polled")
            time.sleep(0.1)
        return proc

    def test_ctrl_c_asks(self) -> None:
        proc = self.start_polling(stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        os.killpg(proc.pid, signal.SIGINT)
        out, err = proc.communicate(timeout=30)
        self.assertEqual(proc.returncode, 1, out + err)
        self.assertIn("Stopped waiting for CI.", out)
        self.assertIn("no terminal to ask", err)

    def test_ctrl_c_at_a_terminal_can_build_anyway(self) -> None:
        primary, secondary = pty.openpty()
        proc = self.start_polling(
            stdin=secondary,
            stdout=secondary,
            stderr=secondary,
            preexec_fn=lambda: fcntl.ioctl(0, termios.TIOCSCTTY, 0),
        )
        os.close(secondary)
        os.write(primary, b"\x03")
        time.sleep(1)
        os.write(primary, b"y\n")
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
        self.assertEqual(proc.wait(timeout=30), 0, output)
        self.assertIn(b"Stopped waiting for CI.", output)

    def test_a_planner_failure_asks(self) -> None:
        for name, setup in {
            "exit": lambda: self.heavy(["niri"]),
            "not a list": lambda: self.heavy('{"niri": true}'),
        }.items():
            with self.subTest(name):
                setup()
                r = self.wait(TEST_PLANNER_EXIT="1" if name == "exit" else "0")
                self.assertEqual(r.returncode, 1)
                self.assertIn(f"Couldn't tell which heavy packages {T1} needs.", r.stdout)
                self.assertEqual(self.gh_calls(), [])


def load_cache_targets() -> Any:
    spec = importlib.util.spec_from_file_location("cache_targets", ROOT / "ci/cache-targets.py")
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class FakeNix:
    """Answers cache-targets.py's nix and nix-store calls from fixed data."""

    def __init__(self, closures: dict[str, list[str]], drvs: dict[str, dict], invalid: set[str]):
        self.closures = closures
        self.drvs = drvs
        self.invalid = invalid
        self.calls: list[tuple[str, ...]] = []

    def __call__(self, *cmd: str) -> str:
        self.calls.append(cmd)
        if cmd[:2] == ("nix", "eval"):
            host = cmd[-1].rpartition("#nixosConfigurations.")[2]
            return f"/nix/store/{'t' * 32}-{host}-toplevel.drv"
        if cmd[:3] == ("nix-store", "--query", "--requisites"):
            return "\n".join(self.closures[cmd[3].split("-")[1]])
        if cmd[:3] == ("nix", "derivation", "show"):
            return json.dumps({path: self.drvs[path] for path in cmd[3:]})
        if cmd[:3] == ("nix-store", "--check-validity", "--print-invalid"):
            return "\n".join(path for path in cmd[3:] if path in self.invalid)
        raise AssertionError(f"unexpected command {cmd}")

    def evaluated(self) -> list[str]:
        return [c[-1] for c in self.calls if c[:2] == ("nix", "eval")]


def drv(letter: str, pname: str, *outputs: str) -> tuple[str, dict]:
    path = f"/nix/store/{letter * 32}-{pname}-1.0.drv"
    outs = {o: {"path": f"/nix/store/{letter * 31}{i}-{pname}-1.0-{o}"} for i, o in enumerate(outputs)}
    return path, {"env": {"pname": pname}, "outputs": outs}


class CacheTargets(unittest.TestCase):
    def setUp(self) -> None:
        self.ct = load_cache_targets()
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.ct.ROOT = Path(self.temp.name)
        (self.ct.ROOT / "ci").mkdir()
        (self.ct.ROOT / "ci/cache-packages").write_text(
            "# comment\n#\nniri # wait\nghostty # wait\ndictator-gui # wait\n"
            "dictator # wait\ndisktree # wait\npagebin\ntry # slow, but not marked\n\n"
        )

    def test_markers(self) -> None:
        self.assertEqual(
            self.ct.packages(),
            ["niri", "ghostty", "dictator-gui", "dictator", "disktree", "pagebin", "try"],
        )
        self.assertEqual(
            self.ct.heavy_packages(), ["niri", "ghostty", "dictator-gui", "dictator", "disktree"]
        )

    def test_the_plan_reads_the_real_list_as_before(self) -> None:
        ct = load_cache_targets()
        text = (ROOT / "ci/cache-packages").read_text()
        before = [
            line.strip()
            for line in text.replace(" # wait", "").splitlines()
            if line.strip() and not line.startswith("#")
        ]
        self.assertEqual(ct.packages(), before)
        self.assertEqual(ct.heavy_packages(), ["niri", "ghostty", "dictator-gui", "dictator", "disktree"])

    def fixture(self) -> tuple[FakeNix, set[tuple[str, str]]]:
        niri = drv("a", "niri", "out")
        ghostty = drv("b", "ghostty", "out")
        dictator = drv("c", "dictator", "out")
        gui = drv("d", "dictator-gui", "out", "lib")
        upstream_niri = drv("e", "niri", "out")
        pagebin = drv("f", "pagebin", "out")
        sietch_disktree = drv("g", "disktree", "out")
        drvs = dict([niri, ghostty, dictator, gui, upstream_niri, pagebin, sietch_disktree])
        out = lambda d, o="out": d[1]["outputs"][o]["path"]  # noqa: E731
        closures = {
            "jacurutu": [niri[0], ghostty[0], dictator[0], gui[0], upstream_niri[0], pagebin[0]],
            "sietch": [sietch_disktree[0], pagebin[0]],
        }
        # niri is built here; the rest are missing, but ghostty is in the
        # cache and the other niri on cache.nixos.org. One output of
        # dictator-gui is enough to wait for it.
        invalid = {out(ghostty), out(dictator), out(gui, "lib"), out(upstream_niri), out(pagebin)}
        cached = {
            (out(ghostty), self.ct.CACHE),
            (out(upstream_niri), self.ct.UPSTREAM),
        }
        return FakeNix(closures, drvs, invalid), cached

    def patched(self, nix: FakeNix, cached: set[tuple[str, str]]):
        def is_cached(path: str, cache: str = self.ct.CACHE) -> bool:
            return (path, cache) in cached

        return mock.patch.multiple(self.ct, run=nix, cached=is_cached)

    def test_heavy_lists_what_jacurutu_would_compile(self) -> None:
        nix, cached = self.fixture()
        with self.patched(nix, cached):
            self.assertEqual(self.ct.heavy("git+file:///r?rev=abc"), ["dictator-gui", "dictator"])
        self.assertEqual(nix.evaluated(), ["git+file:///r?rev=abc#nixosConfigurations.jacurutu"])
        self.assertFalse(any("sietch" in " ".join(c) for c in nix.calls), nix.calls)

    def test_heavy_with_everything_at_hand(self) -> None:
        nix, cached = self.fixture()
        nix.invalid = set()
        with self.patched(nix, cached):
            self.assertEqual(self.ct.heavy("x"), [])

    def test_main_prints_the_heavy_list(self) -> None:
        nix, cached = self.fixture()
        stdout = io.StringIO()
        with self.patched(nix, cached), mock.patch.object(sys, "argv", ["cache-targets.py", "heavy"]):
            with redirect_stdout(stdout):
                self.ct.main()
        self.assertEqual(json.loads(stdout.getvalue()), ["dictator-gui", "dictator"])
        self.assertEqual(nix.evaluated(), [f"{self.ct.ROOT}#nixosConfigurations.jacurutu"])

    def test_the_plan_still_evaluates_every_host(self) -> None:
        nix, cached = self.fixture()
        stdout = io.StringIO()
        with (
            self.patched(nix, cached),
            mock.patch.object(self.ct, "require_atuin_ifd") as atuin,
            mock.patch.object(sys, "argv", ["cache-targets.py", "plan"]),
            redirect_stdout(stdout),
        ):
            with self.assertRaises(SystemExit) as missing:
                self.ct.main()
        self.assertIn("not in any host system: try", str(missing.exception))
        atuin.assert_called_once()
        self.assertEqual(
            nix.evaluated(),
            [f"{self.ct.ROOT}#nixosConfigurations.{host}" for host in ["sietch", "jacurutu"]],
        )
        (self.ct.ROOT / "ci/cache-packages").write_text("niri # wait\ndisktree # wait\npagebin\n")
        nix.calls.clear()
        with (
            self.patched(nix, cached),
            mock.patch.object(self.ct, "require_atuin_ifd"),
            mock.patch.object(sys, "argv", ["cache-targets.py", "plan"]),
            redirect_stdout(stdout),
        ):
            self.ct.main()
        # The plan ignores the local store: niri is built on jacurutu but
        # not cached, so CI still builds it.
        self.assertEqual(json.loads(stdout.getvalue())["packages"], ["niri", "disktree", "pagebin"])


if __name__ == "__main__":
    unittest.main()
