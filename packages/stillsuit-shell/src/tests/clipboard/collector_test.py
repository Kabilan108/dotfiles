#!/usr/bin/env python3
"""Collector classification, storage, gc and copy tests against fake wl-clipboard."""

from __future__ import annotations

import contextlib
import fcntl
import hashlib
import json
import math
import os
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import time
import unittest
import urllib.parse
from pathlib import Path

HERE = Path(__file__).resolve().parent
COLLECTOR = Path(os.environ.get(
    "STILLSUIT_CLIPBOARD_COLLECTOR", HERE.parents[2] / "bin" / "stillsuit-clipboard-collector"))
FAKE_PASTE = HERE / "fake-wl-paste"
FAKE_COPY = HERE / "fake-wl-copy"
FAKE_NIRI = HERE / "fake-niri"
BLOB_GONE = 3
BW_EXTENSION = "chrome-extension://nngceckbapebfimnlniiiahkandclblb/"
VAULT = "https://vault.sole-pierce.ts.net"
SECRET = b"hunter2-correct-horse"
TEXT = "text/plain;charset=utf-8"
CHROMIUM = "chromium/x-source-url"
MOZ_ORIGIN = "text/x-moz-url-priv"
RFH_TOKEN = "chromium/x-internal-source-rfh-token"
DEFAULT_GECKO_APP_IDS = (r"^(zen|zen-beta|zen-browser|zen-alpha|zen-twilight|app\.zen_browser\.zen"
                         r"|firefox|firefox-esr|firefox-nightly|librewolf|org\.mozilla\.firefox)$")

# Exact `wl-paste --list-types` output from the 2026-10-05 Wayland probe
# (Firefox 157, Chromium 154, Bitwarden extension 2026.9.3), duplicates and
# order kept. The probe's vault origin was https://localhost:8222.
PROBE_VAULT = "https://localhost:8222"
FIREFOX_PLAIN = [TEXT, "UTF8_STRING", "COMPOUND_TEXT", "TEXT", "text/plain", "STRING", TEXT, "text/plain",
                 "SAVE_TARGETS"]
FIREFOX_EXTENSION = FIREFOX_PLAIN
FIREFOX_URLBAR = FIREFOX_PLAIN
FIREFOX_CLEAR = FIREFOX_PLAIN
FIREFOX_VAULT = [TEXT, "UTF8_STRING", "COMPOUND_TEXT", "TEXT", "text/plain", "STRING", TEXT, "text/plain",
                 MOZ_ORIGIN, "SAVE_TARGETS"]
FIREFOX_PAGE = ["text/html", "text/_moz_htmlcontext", "text/_moz_htmlinfo", TEXT, "UTF8_STRING", "COMPOUND_TEXT",
                "TEXT", "text/plain", "STRING", TEXT, "text/plain", MOZ_ORIGIN, "SAVE_TARGETS"]
CHROMIUM_EXTENSION = ["text/plain", TEXT, "UTF8_STRING", RFH_TOKEN, TEXT, "TEXT", "STRING", CHROMIUM]
CHROMIUM_VAULT = CHROMIUM_EXTENSION
CHROMIUM_PAGE = ["text/plain", TEXT, "UTF8_STRING", RFH_TOKEN, TEXT, "TEXT", CHROMIUM, "STRING", "text/html"]
CHROMIUM_URLBAR = [TEXT, "text/plain", TEXT, "UTF8_STRING", "TEXT", "STRING"]
CHROMIUM_CLEAR = [RFH_TOKEN, CHROMIUM]
# Text offers of other toolkits, none with Gecko's GTK3 shape.
QT_TEXT = ["text/plain", TEXT, "UTF8_STRING", "TEXT", "STRING"]
FOOT_TEXT = [TEXT, "text/plain", "UTF8_STRING", "TEXT", "STRING"]
WL_COPY_TEXT = ["text/plain", TEXT, "TEXT", "STRING", "UTF8_STRING"]


def utf16(text: str) -> bytes:
    return text.encode("utf-16-le")


def shape_of(types: list[str]) -> str:
    return hashlib.sha256("\n".join(types).encode()).hexdigest()[:16]


class CollectorCase(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp(prefix="clipboard-collector-"))
        self.fake = self.tmp / "fake"
        (self.fake / "payloads").mkdir(parents=True)
        self.state = self.tmp / "state" / "stillsuit" / "clipboard"
        self.runtime = self.tmp / "runtime"
        self.runtime.mkdir(mode=0o700)

    def tearDown(self) -> None:
        for hold in self.fake.glob("hold-*"):
            hold.unlink()
        shutil.rmtree(self.tmp)

    def offer(self, payloads: dict[str, bytes], types: list[str] | None = None,
              after_types: list[str] | None = None,
              after_payloads: dict[str, bytes] | None = None) -> None:
        for stale in ("types.after", "list-count", "calls.log"):
            (self.fake / stale).unlink(missing_ok=True)
        for marker in self.fake.glob("read-*"):
            marker.unlink()
        for directory in ("payloads", "payloads.after"):
            shutil.rmtree(self.fake / directory, ignore_errors=True)
        (self.fake / "payloads").mkdir()
        offered = types if types is not None else list(payloads)
        (self.fake / "types").write_text("".join(t + "\n" for t in offered), encoding="utf-8")
        for mime, data in payloads.items():
            (self.fake / "payloads" / urllib.parse.quote(mime, safe="")).write_bytes(data)
        if after_types is not None:
            (self.fake / "types.after").write_text("".join(t + "\n" for t in after_types), encoding="utf-8")
        if after_payloads:
            (self.fake / "payloads.after").mkdir(exist_ok=True)
            for mime, data in after_payloads.items():
                (self.fake / "payloads.after" / urllib.parse.quote(mime, safe="")).write_bytes(data)

    text_gate = "2"

    def collector_env(self, env: dict[str, str] | None = None) -> dict[str, str]:
        full_env = dict(os.environ)
        full_env["FAKE_CLIP_DIR"] = str(self.fake)
        full_env["XDG_RUNTIME_DIR"] = str(self.runtime)
        for inherited in ("CLIPBOARD_STATE", "STILLSUIT_CLIPBOARD_WATCH_PID"):
            full_env.pop(inherited, None)
        # Every fake wl-paste call is a Python startup, so a multi-read offer
        # can near a tight text bound on its own; the stall tests set
        # text_gate to 250 ms and stall the reads past it.
        full_env["STILLSUIT_CLIPBOARD_TEXT_GATE_SEC"] = self.text_gate
        full_env.update(env or {})
        return full_env

    @staticmethod
    def command() -> list[str]:
        return [str(COLLECTOR)] if os.access(COLLECTOR, os.X_OK) else [sys.executable, str(COLLECTOR)]

    def run_collector(self, *args: str, env: dict[str, str] | None = None,
                      stdin: bytes = b"") -> subprocess.CompletedProcess:
        return subprocess.run(
            [*self.command(), *args],
            input=stdin, capture_output=True, env=self.collector_env(env), timeout=30, check=False,
        )

    def start_collector(self, *args: str) -> subprocess.Popen:
        return subprocess.Popen(
            [*self.command(), *args],
            stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=self.collector_env(),
        )

    def reads(self) -> list[str]:
        """Payload and marker types read from the fake since the last offer()."""
        log = self.fake / "calls.log"
        lines = log.read_text().splitlines() if log.exists() else []
        return [line.split(" ", 2)[2] for line in lines if line.startswith("--no-newline --type ")]

    def hold_state_lock(self) -> int:
        self.state.mkdir(parents=True, exist_ok=True)
        os.chmod(self.state, 0o700)
        fd = os.open(self.state / ".lock", os.O_RDWR | os.O_CREAT, 0o600)
        fcntl.flock(fd, fcntl.LOCK_EX)
        return fd

    def emit(self, *extra: str, env: dict[str, str] | None = None, stdin: bytes = b"") -> dict:
        result = self.run_collector(
            "emit", "--state-dir", str(self.state), "--wl-paste", str(FAKE_PASTE),
            f"--secret-source-prefix={BW_EXTENSION}", f"--secret-source-prefix={VAULT}",
            *extra, env=env, stdin=stdin,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        lines = result.stdout.decode("ascii").splitlines()
        self.assertEqual(len(lines), 1, result.stdout)
        self.assertNotIn(SECRET, result.stdout)
        self.assertNotIn(SECRET, result.stderr)
        self.assertEqual(result.stderr, b"")
        return json.loads(lines[0])

    def blobs(self) -> list[str]:
        directory = self.state / "blobs"
        return sorted(os.listdir(directory)) if directory.exists() else []

    def assert_no_secret_on_disk(self, secret: bytes = SECRET) -> None:
        for root in (self.tmp / "state", self.runtime):
            for path in root.rglob("*"):
                if path.is_file():
                    self.assertNotIn(secret, path.read_bytes(), str(path))

    def eligible_ms(self, name: str, wait_sec: float) -> int:
        """When gc may first delete blobs/<name>, as wall-clock ms."""
        return math.ceil((os.stat(self.state / "blobs" / name).st_mtime + wait_sec) * 1000)

    def plant_blobs(self, names: dict[str, bytes], age: float = 0.0) -> Path:
        blobs = self.state / "blobs"
        blobs.mkdir(parents=True, exist_ok=True)
        os.chmod(self.state, 0o700)
        os.chmod(blobs, 0o700)
        for name, data in names.items():
            (blobs / name).write_bytes(data)
            if age:
                stamp = time.time() - age
                os.utime(blobs / name, (stamp, stamp))
        return blobs

    def reply(self, *args: str) -> tuple[int, dict]:
        result = self.run_collector(*args)
        return result.returncode, json.loads(result.stdout)


class ClassificationTests(CollectorCase):
    def test_kde_password_hint_is_skipped(self) -> None:
        self.offer({"text/plain;charset=utf-8": SECRET, "x-kde-passwordManagerHint": b"secret"})
        self.assertEqual(self.emit(), {"kind": "skipped", "reason": "hint"})
        self.assertEqual(self.blobs(), [])
        self.assert_no_secret_on_disk()

    def test_sensitive_clipboard_state_skips_without_reading(self) -> None:
        self.offer({"text/plain;charset=utf-8": SECRET})
        event = self.emit(env={"CLIPBOARD_STATE": "sensitive"}, stdin=SECRET)
        self.assertEqual(event, {"kind": "skipped", "reason": "hint"})
        self.assertFalse((self.fake / "calls.log").exists())

    def test_nil_clipboard_state_is_empty(self) -> None:
        self.assertEqual(self.emit(env={"CLIPBOARD_STATE": "nil"}), {"kind": "skipped", "reason": "empty"})

    def test_nil_clipboard_state_never_clears(self) -> None:
        # Both browsers announce their clear with state=nil before the data event.
        for state in ("nil", "clear"):
            with self.subTest(state=state):
                self.offer({TEXT: b"", "text/plain": b""}, types=FIREFOX_CLEAR)
                event = self.emit("--unattributed-firefox=record", env={"CLIPBOARD_STATE": state})
                self.assertEqual(event, {"kind": "skipped", "reason": "empty"})
                self.assertFalse((self.fake / "calls.log").exists(), "nothing is read")

    def test_nothing_copied_is_empty(self) -> None:
        self.assertEqual(self.emit(), {"kind": "skipped", "reason": "empty"})

    def test_chromium_bitwarden_extension_is_skipped(self) -> None:
        self.offer({
            "text/plain;charset=utf-8": SECRET,
            "chromium/x-source-url": (BW_EXTENSION + "offscreen-document/index.html").encode(),
        })
        self.assertEqual(self.emit(), {"kind": "skipped", "reason": "source"})
        self.assert_no_secret_on_disk()

    def test_chromium_vault_origin_is_skipped(self) -> None:
        self.offer({
            "text/plain;charset=utf-8": SECRET,
            "chromium/x-source-url": b"HTTPS://Vault.Sole-Pierce.ts.net/#/vault",
        })
        self.assertEqual(self.emit(), {"kind": "skipped", "reason": "source"})

    def test_chromium_other_page_is_recorded(self) -> None:
        self.offer({
            "text/plain;charset=utf-8": b"hello",
            "chromium/x-source-url": b"https://example.com/",
        })
        self.assertEqual(self.emit()["kind"], "text")

    def test_firefox_vault_origin_is_skipped(self) -> None:
        for encoded in (utf16(VAULT + "/"), b"\xff\xfe" + utf16(VAULT), (VAULT + "/#/").encode()):
            with self.subTest(encoded=encoded[:6]):
                self.offer({
                    "text/plain;charset=utf-8": SECRET,
                    "text/x-moz-url-priv": encoded,
                    "text/html": b"<b>x</b>",
                })
                self.assertEqual(self.emit(), {"kind": "skipped", "reason": "source"})
                self.assert_no_secret_on_disk()

    def test_clear_payloads_without_gecko_shape_are_empty(self) -> None:
        # Only Firefox's Bitwarden clear needs a purge, and it is Gecko-shaped;
        # any other app's empty, NUL or space text is just empty.
        for payload in (b"", b"\x00", b" "):
            with self.subTest(payload=payload):
                self.offer({"text/plain;charset=utf-8": payload, "text/plain": payload})
                self.assertEqual(self.emit(), {"kind": "skipped", "reason": "empty"})
        self.assertEqual(self.blobs(), [])

    def test_failed_wl_copy_after_wl_copy_is_not_a_clear(self) -> None:
        # Two unrelated wl-copy offers share a type list. When the second
        # sender fails, wl-paste still exits 0 with zero bytes; that read must
        # not purge the first copy, so it is skipped rather than a clear.
        self.offer(dict.fromkeys(WL_COPY_TEXT, b"first copy"), types=WL_COPY_TEXT)
        first = self.emit()
        self.assertEqual((first["kind"], first["shape"]), ("text", shape_of(WL_COPY_TEXT)))
        self.offer(dict.fromkeys(WL_COPY_TEXT, b""), types=WL_COPY_TEXT)
        self.assertEqual(self.emit(), {"kind": "skipped", "reason": "empty"})
        self.assertEqual(self.blobs(), [first["sha"]])

    def test_clear_from_secret_source_is_skipped_not_cleared(self) -> None:
        self.offer({"text/plain;charset=utf-8": b"\x00", "chromium/x-source-url": BW_EXTENSION.encode()})
        self.assertEqual(self.emit(), {"kind": "skipped", "reason": "source"})

    def test_whitespace_only_text_is_empty(self) -> None:
        self.offer({"text/plain;charset=utf-8": b"\n\t \n"})
        self.assertEqual(self.emit(), {"kind": "skipped", "reason": "empty"})

    def test_normal_text_is_stored_privately(self) -> None:
        payload = "naïve café\n".encode()
        self.offer({"text/plain": b"wrong", "text/plain;charset=utf-8": payload, "UTF8_STRING": b"wrong"})
        event = self.emit(stdin=b"x" * 200000)
        digest = hashlib.sha256(payload).hexdigest()
        self.assertEqual(event, {
            "kind": "text", "sha": digest, "mime": "text/plain;charset=utf-8",
            "bytes": len(payload), "preview": payload.decode(),
            "shape": shape_of(["text/plain", TEXT, "UTF8_STRING"]),
        })
        blob = self.state / "blobs" / digest
        self.assertEqual(blob.read_bytes(), payload)
        self.assertEqual(stat.S_IMODE(blob.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(self.state.stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE((self.state / "blobs").stat().st_mode), 0o700)
        self.assertEqual(self.blobs(), [digest])

    def test_text_type_preference(self) -> None:
        self.offer({"text/plain": b"plain", "UTF8_STRING": b"atom"})
        self.assertEqual(self.emit()["mime"], "UTF8_STRING")
        self.offer({"text/plain": b"plain", "text/html": b"<p>"}, ["text/html", "text/plain"])
        self.assertEqual(self.emit()["mime"], "text/plain")
        self.offer({"text/plain;charset=UTF-8": b"upper"}, ["text/plain;charset=UTF-8"])
        self.assertEqual(self.emit()["mime"], "text/plain;charset=UTF-8")

    def test_png_image(self) -> None:
        png = b"\x89PNG\r\n\x1a\n" + bytes(range(256)) * 4
        self.offer({"image/jpeg": b"jpeg", "image/png": png, "text/html": b"<img>"})
        event = self.emit()
        self.assertEqual(event, {
            "kind": "image", "sha": hashlib.sha256(png).hexdigest(), "mime": "image/png",
            "bytes": len(png), "preview": "",
        })
        self.assertEqual((self.state / "blobs" / event["sha"]).read_bytes(), png)

    def test_other_image_types(self) -> None:
        self.offer({"image/webp": b"RIFFwebp"})
        self.assertEqual(self.emit()["mime"], "image/webp")
        self.offer({"image/x-exotic": b"exotic"})
        self.assertEqual(self.emit()["mime"], "image/x-exotic")

    def test_unsupported_offer(self) -> None:
        self.offer({"application/x-thing": b"x"})
        self.assertEqual(self.emit(), {"kind": "skipped", "reason": "unsupported"})

    def test_oversize_is_skipped(self) -> None:
        self.offer({"text/plain;charset=utf-8": SECRET + b"x" * 64})
        self.assertEqual(self.emit("--max-text-bytes", "32"), {"kind": "skipped", "reason": "too-large"})
        self.offer({"image/png": b"p" * 100})
        self.assertEqual(self.emit("--max-image-bytes", "99"), {"kind": "skipped", "reason": "too-large"})
        self.assertEqual(self.emit("--max-image-bytes", "100")["kind"], "image")

    def test_preview_truncates_on_character_boundary(self) -> None:
        for char in ("é", "€", "𝄞"):
            with self.subTest(char=char):
                payload = b"a" * 2047 + char.encode() * 4
                self.offer({"text/plain;charset=utf-8": payload})
                event = self.emit()
                self.assertEqual(event["preview"], "a" * 2047)
                self.assertEqual(event["bytes"], len(payload))
        payload = b"a" * 2046 + "é".encode() + b"b" * 10
        self.offer({"text/plain;charset=utf-8": payload})
        self.assertEqual(self.emit()["preview"], "a" * 2046 + "é")

    def test_invalid_utf8_preview_is_replaced(self) -> None:
        self.offer({"text/plain": b"caf\xe9"})
        self.assertEqual(self.emit()["preview"], "caf�")

    def test_offer_change_during_read_is_dropped(self) -> None:
        self.offer({"text/plain;charset=utf-8": SECRET},
                   after_types=["text/plain;charset=utf-8", "chromium/x-source-url"])
        self.assertEqual(self.emit(), {"kind": "skipped", "reason": "changed"})
        self.assert_no_secret_on_disk()

    def test_marker_change_during_read_is_dropped(self) -> None:
        self.offer(
            {"text/plain;charset=utf-8": SECRET, "chromium/x-source-url": b"https://example.com/"},
            after_payloads={"chromium/x-source-url": BW_EXTENSION.encode()},
        )
        self.assertEqual(self.emit(), {"kind": "skipped", "reason": "changed"})
        self.assert_no_secret_on_disk()

    def test_repeat_refreshes_existing_blob_mtime(self) -> None:
        self.offer({"text/plain;charset=utf-8": b"again"})
        sha = self.emit()["sha"]
        blob = self.state / "blobs" / sha
        os.utime(blob, (1, 1))
        self.assertEqual(self.emit()["sha"], sha)
        self.assertGreater(blob.stat().st_mtime, time.time() - 60)

    def test_planted_symlink_blob_is_replaced(self) -> None:
        payload = b"planted"
        sha = hashlib.sha256(payload).hexdigest()
        outside = self.tmp / "outside"
        outside.write_bytes(b"do not touch")
        (self.state / "blobs").mkdir(parents=True)
        os.chmod(self.state, 0o700)
        (self.state / "blobs" / sha).symlink_to(outside)
        self.offer({"text/plain;charset=utf-8": payload})
        self.assertEqual(self.emit()["sha"], sha)
        self.assertEqual(outside.read_bytes(), b"do not touch")
        self.assertFalse((self.state / "blobs" / sha).is_symlink())
        self.assertEqual((self.state / "blobs" / sha).read_bytes(), payload)


    def test_offer_returning_to_previous_during_read_is_dropped(self) -> None:
        # Types and markers come from offer A, the payload from secret offer B,
        # and A is back before the recheck: only a second payload read sees it.
        self.offer(
            {TEXT: SECRET, "chromium/x-source-url": b"https://example.com/"},
            after_payloads={TEXT: b"what A really offers"},
        )
        self.assertEqual(self.emit(), {"kind": "skipped", "reason": "changed"})
        self.assertEqual(self.blobs(), [])
        self.assert_no_secret_on_disk()
        self.offer({"image/png": b"\x89PNG-from-B"}, after_payloads={"image/png": b"\x89PNG-from-A"})
        self.assertEqual(self.emit(), {"kind": "skipped", "reason": "changed"})
        self.assertEqual(self.blobs(), [])

    def test_stable_offer_reads_payload_twice(self) -> None:
        self.offer({TEXT: b"steady"})
        self.assertEqual(self.emit()["kind"], "text")
        reads = (self.fake / "calls.log").read_text().splitlines().count(f"--no-newline --type {TEXT}")
        self.assertEqual(reads, 2)

    def test_unreadable_source_marker_is_skipped(self) -> None:
        cases = [
            ("chromium/x-source-url", None),
            ("chromium/x-source-url", b"https://example.com/" + b"x" * 8192),
            ("chromium/x-source-url", b"chrome-extension://\xff\xfe\xfd"),
            ("text/x-moz-url-priv", None),
            ("text/x-moz-url-priv", b"\xff\xfe" + "https://".encode("utf-16-le") + b"\x00\xd8"),
        ]
        for marker, raw in cases:
            with self.subTest(marker=marker, raw=None if raw is None else raw[:24]):
                payloads = {TEXT: SECRET}
                if raw is not None:
                    payloads[marker] = raw
                self.offer(payloads, types=[TEXT, marker])
                self.assertEqual(self.emit(), {"kind": "skipped", "reason": "source"})
                self.assert_no_secret_on_disk()

    def test_hint_outranks_unreadable_marker(self) -> None:
        self.offer({TEXT: SECRET}, types=[TEXT, "chromium/x-source-url", "x-kde-passwordManagerHint"])
        self.assertEqual(self.emit(), {"kind": "skipped", "reason": "hint"})

    def test_capture_rewrites_existing_blob(self) -> None:
        payload = b"fresh payload"
        sha = hashlib.sha256(payload).hexdigest()
        blobs = self.plant_blobs({sha: b"x" * len(payload)}, age=3600)
        os.chmod(blobs / sha, 0o644)
        self.offer({TEXT: payload})
        self.assertEqual(self.emit()["sha"], sha)
        self.assertEqual((blobs / sha).read_bytes(), payload)
        self.assertEqual(stat.S_IMODE((blobs / sha).stat().st_mode), 0o600)
        self.assertEqual(self.blobs(), [sha], "no temp file is left behind")

class StateTests(CollectorCase):
    def test_init_creates_private_state(self) -> None:
        result = self.run_collector("init", "--state-dir", str(self.state))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), {"ok": True})
        history = self.state / "history.v1.json"
        self.assertEqual(json.loads(history.read_text()), {"schemaVersion": 1, "entries": []})
        self.assertEqual(stat.S_IMODE(history.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(self.state.stat().st_mode), 0o700)
        history.write_text('{"schemaVersion":1,"entries":[{"x":1}]}')
        os.chmod(self.state, 0o755)
        os.chmod(history, 0o644)
        self.assertEqual(self.run_collector("init", "--state-dir", str(self.state)).returncode, 0)
        self.assertEqual(stat.S_IMODE(self.state.stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE(history.stat().st_mode), 0o600)
        self.assertIn('"x"', history.read_text(), "init never rewrites an existing history")

    def test_init_reports_unusable_state(self) -> None:
        self.state.parent.mkdir(parents=True)
        self.state.write_text("file")
        result = self.run_collector("init", "--state-dir", str(self.state))
        self.assertEqual(result.returncode, 1)
        reply = json.loads(result.stdout)
        self.assertFalse(reply["ok"])
        self.assertIn("not a directory", reply["error"])

        self.state.unlink()
        self.state.mkdir(mode=0o700)
        (self.state / "history.v1.json").symlink_to(self.tmp / "elsewhere")
        result = self.run_collector("init", "--state-dir", str(self.state))
        self.assertEqual(result.returncode, 1)
        self.assertFalse((self.tmp / "elsewhere").exists())

    def test_relative_state_dir_is_rejected(self) -> None:
        self.assertEqual(self.run_collector("init", "--state-dir", "relative").returncode, 2)

    def test_gc_deletes_only_old_unreferenced_blobs(self) -> None:
        blobs = self.state / "blobs"
        blobs.mkdir(parents=True)
        keep, orphan, fresh, linked = (hashlib.sha256(bytes([n])).hexdigest() for n in range(4))
        for name in (keep, orphan, fresh, ".tmp-1-abc", "notes.txt"):
            (blobs / name).write_bytes(b"x")
        outside_dir = self.tmp / "outside"
        outside_dir.mkdir()
        outside = outside_dir / "victim"
        outside.write_bytes(b"victim")
        (blobs / linked).symlink_to(outside)
        subdir_name = hashlib.sha256(b"dir").hexdigest()
        (blobs / subdir_name).mkdir()
        old = time.time() - 3600
        for name in (keep, orphan, ".tmp-1-abc", "notes.txt"):
            os.utime(blobs / name, (old, old))
        os.utime(blobs / linked, (old, old), follow_symlinks=False)

        result = self.run_collector("gc", "--state-dir", str(self.state), "--keep", keep)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout),
                         {"ok": True, "removed": 2, "deferred": 1, "nextEligibleMs": self.eligible_ms(fresh, 120)})
        self.assertEqual(sorted(os.listdir(blobs)), sorted([keep, fresh, linked, "notes.txt", subdir_name]))
        self.assertEqual(outside.read_bytes(), b"victim")

        result = self.run_collector("gc", "--state-dir", str(self.state), "--grace-sec", "0", "--keep")
        self.assertEqual(json.loads(result.stdout)["removed"], 2)
        self.assertEqual(sorted(os.listdir(blobs)), sorted([linked, "notes.txt", subdir_name]))
        self.assertTrue(outside.exists())

    def test_gc_refuses_symlinked_blob_directory(self) -> None:
        target = self.tmp / "target"
        target.mkdir()
        orphan = hashlib.sha256(b"o").hexdigest()
        (target / orphan).write_bytes(b"x")
        os.utime(target / orphan, (1, 1))
        self.state.mkdir(parents=True)
        (self.state / "blobs").symlink_to(target)
        result = self.run_collector("gc", "--state-dir", str(self.state), "--grace-sec", "0")
        self.assertEqual(result.returncode, 1)
        self.assertTrue((target / orphan).exists())

    def test_gc_rejects_invalid_keep(self) -> None:
        (self.state / "blobs").mkdir(parents=True)
        result = self.run_collector("gc", "--state-dir", str(self.state), "--keep", "../x")
        self.assertEqual(result.returncode, 2)

    def test_gc_without_blob_directory(self) -> None:
        result = self.run_collector("gc", "--state-dir", str(self.state))
        self.assertEqual(result.returncode, 0)
        self.assertEqual(json.loads(result.stdout), {"ok": True, "removed": 0, "deferred": 0})

    def test_gc_reports_deferred_orphans(self) -> None:
        young, old = (hashlib.sha256(bytes([n])).hexdigest() for n in range(2))
        self.plant_blobs({young: b"y"})
        self.plant_blobs({old: b"o"}, age=3600)
        self.assertEqual(self.reply("gc", "--state-dir", str(self.state)),
                         (0, {"ok": True, "removed": 1, "deferred": 1, "nextEligibleMs": self.eligible_ms(young, 120)}))
        self.assertEqual(self.blobs(), [young])

    def test_gc_keeps_young_staging_files_without_grace(self) -> None:
        orphan = hashlib.sha256(b"orphan").hexdigest()
        blobs = self.plant_blobs({orphan: b"o", ".tmp-41-staging": b"in flight"})
        self.plant_blobs({".tmp-40-crashed": b"left over"}, age=601)
        self.assertEqual(self.reply("gc", "--state-dir", str(self.state), "--grace-sec", "0"),
                         (0, {"ok": True, "removed": 2, "deferred": 1,
                              "nextEligibleMs": self.eligible_ms(".tmp-41-staging", 600)}))
        self.assertEqual(sorted(os.listdir(blobs)), [".tmp-41-staging"])

    def test_gc_reports_the_earliest_eligibility_of_what_it_deferred(self) -> None:
        blob = hashlib.sha256(b"young").hexdigest()
        self.plant_blobs({blob: b"y"}, age=10)
        self.plant_blobs({".tmp-42-staging": b"s"}, age=550)
        code, reply = self.reply("gc", "--state-dir", str(self.state), "--grace-sec", "120")
        self.assertEqual((code, reply["deferred"]), (0, 2))
        self.assertEqual(reply["nextEligibleMs"], self.eligible_ms(".tmp-42-staging", 600),
                         "a staging file waits 600 s, whatever the grace")
        code, reply = self.reply("gc", "--state-dir", str(self.state), "--grace-sec", "30")
        self.assertEqual(reply["nextEligibleMs"], self.eligible_ms(blob, 30))

    def test_rm_deletes_named_blobs_without_grace(self) -> None:
        self.offer({TEXT: b"just captured"})
        fresh = self.emit()["sha"]
        keep, linked, subdir = (hashlib.sha256(bytes([n])).hexdigest() for n in range(3))
        blobs = self.plant_blobs({keep: b"k", "notes.txt": b"n"})
        outside = self.tmp / "outside"
        outside.write_bytes(b"victim")
        (blobs / linked).symlink_to(outside)
        (blobs / subdir).mkdir()
        self.assertEqual(
            self.reply("rm", "--state-dir", str(self.state), "--sha", fresh, linked, subdir, fresh),
            (0, {"ok": True, "removed": 1}))
        self.assertEqual(sorted(os.listdir(blobs)), sorted([keep, linked, subdir, "notes.txt"]))
        self.assertEqual(outside.read_bytes(), b"victim")

    def test_rm_rejects_invalid_sha_before_deleting(self) -> None:
        keep = hashlib.sha256(b"k").hexdigest()
        self.plant_blobs({keep: b"k"})
        for bad in ("notes.txt", "../blobs/" + keep, keep.upper()):
            with self.subTest(bad=bad):
                result = self.run_collector("rm", "--state-dir", str(self.state), "--sha", keep, bad)
                self.assertEqual(result.returncode, 2)
        self.assertEqual(self.blobs(), [keep])

    def test_rm_keeps_blob_rewritten_after_the_decision(self) -> None:
        old, recaptured = (hashlib.sha256(bytes([n])).hexdigest() for n in range(2))
        self.plant_blobs({old: b"o"}, age=60)
        self.plant_blobs({recaptured: b"r"})
        decided = (time.time() - 30) * 1000
        self.assertEqual(
            self.reply("rm", "--state-dir", str(self.state), "--before-ms", str(decided), "--sha", old, recaptured),
            (0, {"ok": True, "removed": 1}))
        self.assertEqual(self.blobs(), [recaptured])

    def test_symlinked_or_shared_state_dir_is_refused(self) -> None:
        elsewhere = self.tmp / "elsewhere"
        (elsewhere / "blobs").mkdir(parents=True)
        os.chmod(elsewhere, 0o700)
        os.chmod(elsewhere / "blobs", 0o700)
        victim = hashlib.sha256(b"victim").hexdigest()
        (elsewhere / "blobs" / victim).write_bytes(b"victim")
        os.utime(elsewhere / "blobs" / victim, (1, 1))
        self.state.parent.mkdir(parents=True)
        self.state.symlink_to(elsewhere)
        self.offer({TEXT: b"payload"})
        commands = [
            ("init", "--state-dir", str(self.state)),
            ("emit", "--state-dir", str(self.state), "--wl-paste", str(FAKE_PASTE)),
            ("gc", "--state-dir", str(self.state), "--grace-sec", "0"),
            ("rm", "--state-dir", str(self.state), "--sha", victim),
            ("copy", "--state-dir", str(self.state), "--sha", victim, "--mime", "text/plain",
             "--wl-copy", str(FAKE_COPY)),
        ]
        for command in commands:
            with self.subTest(command=command[0]):
                result = self.run_collector(*command)
                if command[0] == "emit":
                    self.assertEqual(json.loads(result.stdout), {"kind": "skipped", "reason": "error"})
                else:
                    self.assertNotEqual(result.returncode, 0)
        self.assertEqual(sorted(os.listdir(elsewhere)), ["blobs"])
        self.assertEqual(os.listdir(elsewhere / "blobs"), [victim])
        self.assertFalse((self.fake / "wl-copy.argv").exists())

        self.state.unlink()
        self.state.mkdir(mode=0o700)
        os.chmod(self.state, 0o770)
        result = self.run_collector("init", "--state-dir", str(self.state))
        self.assertEqual(result.returncode, 1)
        self.assertIn("writable by other users", json.loads(result.stdout)["error"])
        self.assertEqual(os.listdir(self.state), [])


class CopyAndWatchTests(CollectorCase):
    def copy(self, sha: str, mime: str) -> subprocess.CompletedProcess:
        return self.run_collector(
            "copy", "--state-dir", str(self.state), "--sha", sha, "--mime", mime,
            "--wl-copy", str(FAKE_COPY),
        )

    def test_copy_feeds_exact_bytes(self) -> None:
        payload = b"line one\r\n\x00tab\tend\n\n"
        self.offer({"text/plain;charset=utf-8": payload})
        sha = self.emit()["sha"]
        result = self.copy(sha, "text/plain;charset=utf-8")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.fake / "wl-copy.stdin").read_bytes(), payload)
        self.assertEqual((self.fake / "wl-copy.argv").read_text().splitlines(),
                         ["--type", "text/plain;charset=utf-8"])

    def test_copy_image_and_atom_mimes(self) -> None:
        png = b"\x89PNG" + bytes(range(256))
        self.offer({"image/png": png})
        sha = self.emit()["sha"]
        self.assertEqual(self.copy(sha, "image/png").returncode, 0)
        self.assertEqual((self.fake / "wl-copy.stdin").read_bytes(), png)
        self.offer({"UTF8_STRING": b"atom"})
        sha = self.emit()["sha"]
        self.assertEqual(self.copy(sha, "UTF8_STRING").returncode, 0)
        self.assertEqual((self.fake / "wl-copy.argv").read_text().splitlines(), ["--type", "UTF8_STRING"])

    def test_copy_rejects_bad_arguments(self) -> None:
        (self.state / "blobs").mkdir(parents=True)
        good = hashlib.sha256(b"x").hexdigest()
        (self.state / "blobs" / good).write_bytes(b"x")
        for sha, mime in (("../../etc/passwd", "text/plain"), (good, "--foreground"),
                          (good, "text/plain; rm -rf"), (good.upper(), "text/plain")):
            with self.subTest(sha=sha[:8], mime=mime):
                self.assertEqual(self.copy(sha, mime).returncode, 2)
        self.assertFalse((self.fake / "wl-copy.argv").exists())

    def test_copy_refuses_symlink_and_missing_blob(self) -> None:
        blobs = self.state / "blobs"
        blobs.mkdir(parents=True)
        outside = self.tmp / "outside"
        outside.write_bytes(b"secret")
        linked = hashlib.sha256(b"link").hexdigest()
        (blobs / linked).symlink_to(outside)
        subdir = hashlib.sha256(b"dir").hexdigest()
        (blobs / subdir).mkdir()
        for sha in (linked, subdir, hashlib.sha256(b"none").hexdigest()):
            with self.subTest(sha=sha[:8]):
                self.assertEqual(self.copy(sha, "text/plain").returncode, BLOB_GONE)
        self.assertFalse((self.fake / "wl-copy.argv").exists())

    def test_copy_without_blob_directory_reports_the_blob_gone(self) -> None:
        self.state.mkdir(parents=True, mode=0o700)
        self.assertEqual(self.copy(hashlib.sha256(b"x").hexdigest(), "text/plain").returncode, BLOB_GONE)

    def test_copy_failures_other_than_the_blob_are_not_blob_gone(self) -> None:
        payload = b"present"
        sha = hashlib.sha256(payload).hexdigest()
        self.plant_blobs({sha: payload})
        result = self.run_collector("copy", "--state-dir", str(self.state), "--sha", sha, "--mime", "text/plain",
                                    "--wl-copy", str(self.tmp / "no-such-wl-copy"))
        self.assertEqual(result.returncode, 1)
        os.chmod(self.state, 0o770)
        self.assertEqual(self.copy(sha, "text/plain").returncode, 1, "a shared state dir is refused, not gone")

    def test_copy_refuses_tampered_blob(self) -> None:
        payload = b"stored"
        sha = hashlib.sha256(payload).hexdigest()
        self.plant_blobs({sha: b"swapd!"})
        result = self.copy(sha, "text/plain")
        self.assertEqual(result.returncode, BLOB_GONE)
        self.assertIn(b"does not match", result.stderr)
        self.assertFalse((self.fake / "wl-copy.argv").exists())

    def hold_payload(self) -> Path:
        hold = self.fake / ("hold-" + urllib.parse.quote(TEXT, safe=""))
        hold.touch()
        return hold

    def wait_for(self, path: Path, timeout: float = 10.0) -> None:
        deadline = time.monotonic() + timeout
        while not path.exists():
            self.assertLess(time.monotonic(), deadline, f"{path.name} never appeared")
            time.sleep(0.02)

    def assert_nothing_collected(self, events: Path) -> None:
        deadline = time.monotonic() + 3.0
        while time.monotonic() < deadline:
            self.assertEqual(events.read_bytes(), b"", "an event was emitted after the watcher died")
            self.assertEqual(self.blobs(), [], "a blob was written after the watcher died")
            time.sleep(0.1)
        self.assert_no_secret_on_disk()

    def test_stopped_watcher_takes_inflight_emit_with_it(self) -> None:
        scenario = self.fake / "scenarios" / "01"
        (scenario / "payloads").mkdir(parents=True)
        (scenario / "types").write_text(TEXT + "\n", encoding="utf-8")
        (scenario / "payloads" / urllib.parse.quote(TEXT, safe="")).write_bytes(SECRET)
        hold = self.hold_payload()
        events = self.tmp / "events"
        command = [str(COLLECTOR)] if os.access(COLLECTOR, os.X_OK) else [sys.executable, str(COLLECTOR)]
        with events.open("wb") as sink:
            watcher = subprocess.Popen(
                [*command, "watch", "--state-dir", str(self.state), "--collector", str(COLLECTOR),
                 "--wl-paste", str(FAKE_PASTE)],
                stdout=sink, stderr=subprocess.DEVNULL,
                env={**os.environ, "FAKE_CLIP_DIR": str(self.fake), "XDG_RUNTIME_DIR": str(self.runtime)},
            )
        try:
            self.wait_for(self.fake / hold.name.replace("hold-", "held-"))
            watcher.send_signal(signal.SIGTERM)
            watcher.wait(timeout=10)
        finally:
            if watcher.poll() is None:
                watcher.kill()
                watcher.wait()
        hold.unlink()
        self.assert_nothing_collected(events)

    def test_emit_dies_with_its_parent(self) -> None:
        self.offer({TEXT: SECRET})
        hold = self.hold_payload()
        events = self.tmp / "events"
        command = [str(COLLECTOR)] if os.access(COLLECTOR, os.X_OK) else [sys.executable, str(COLLECTOR)]
        emit = [*command, "emit", "--state-dir", str(self.state), "--wl-paste", str(FAKE_PASTE)]
        parent = subprocess.Popen(
            [sys.executable, "-c",
             "import subprocess, sys, time\n"
             "subprocess.Popen(sys.argv[2:], stdin=subprocess.DEVNULL, stdout=open(sys.argv[1], 'wb'))\n"
             "time.sleep(3600)\n",
             str(events), *emit],
            env={**os.environ, "FAKE_CLIP_DIR": str(self.fake), "XDG_RUNTIME_DIR": str(self.runtime)},
        )
        try:
            self.wait_for(self.fake / hold.name.replace("hold-", "held-"))
        finally:
            parent.kill()
            parent.wait()
        hold.unlink()
        self.assert_nothing_collected(events)

    def test_watch_execs_wl_paste_with_fixed_argv(self) -> None:
        collector = "/nix/store/fake-collector/bin/stillsuit-clipboard-collector"
        result = self.run_collector(
            "watch", "--state-dir", str(self.state), "--collector", collector,
            "--wl-paste", str(FAKE_PASTE), "--max-text-bytes", "10", "--max-image-bytes", "20",
            f"--secret-source-prefix={BW_EXTENSION}", "--secret-source-prefix=-dash",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.fake / "watch.argv").read_text().splitlines(), [
            "--watch", collector, "emit", "--state-dir", str(self.state),
            "--wl-paste", str(FAKE_PASTE), "--max-text-bytes", "10", "--max-image-bytes", "20",
            f"--secret-source-prefix={BW_EXTENSION}", "--secret-source-prefix=-dash",
            "--unattributed-firefox=skip", f"--gecko-app-ids={DEFAULT_GECKO_APP_IDS}", "--focus-settle-ms=2000",
        ])

    def test_watch_passes_attribution_settings(self) -> None:
        collector = "/nix/store/fake-collector/bin/stillsuit-clipboard-collector"
        result = self.run_collector(
            "watch", "--state-dir", str(self.state), "--collector", collector, "--wl-paste", str(FAKE_PASTE),
            "--niri", "/nix/store/fake-niri/bin/niri", "--gecko-app-ids=-^(zen)$", "--focus-settle-ms", "1500.5")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.fake / "watch.argv").read_text().splitlines()[-3:],
                         ["--gecko-app-ids=-^(zen)$", "--focus-settle-ms=1500.5", "--niri=/nix/store/fake-niri/bin/niri"])
        for invalid in ("-1", "nan", "inf"):
            result = self.run_collector(
                "watch", "--state-dir", str(self.state), "--collector", collector, "--wl-paste", str(FAKE_PASTE),
                f"--focus-settle-ms={invalid}")
            self.assertEqual(result.returncode, 2, f"--focus-settle-ms={invalid} is refused")
        result = self.run_collector(
            "watch", "--state-dir", str(self.state), "--collector", collector, "--wl-paste", str(FAKE_PASTE),
            "--gecko-app-ids=(unclosed")
        self.assertEqual(result.returncode, 2, "an invalid pattern is refused")

    def test_watch_passes_unattributed_mode_and_exit_status(self) -> None:
        collector = "/nix/store/fake-collector/bin/stillsuit-clipboard-collector"
        result = self.run_collector(
            "watch", "--state-dir", str(self.state), "--collector", collector,
            "--wl-paste", str(FAKE_PASTE), "--unattributed-firefox", "record",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--unattributed-firefox=record", (self.fake / "watch.argv").read_text().splitlines())
        result = self.run_collector(
            "watch", "--state-dir", str(self.state), "--collector", collector,
            "--wl-paste", str(FAKE_PASTE), "--unattributed-firefox", "quarantine",
        )
        self.assertEqual(result.returncode, 2, "an unknown mode is refused")
        scenario = self.fake / "scenarios" / "01"
        scenario.mkdir(parents=True)
        (scenario / "exit").write_text("3")
        result = self.run_collector(
            "watch", "--state-dir", str(self.state), "--collector", collector, "--wl-paste", str(FAKE_PASTE))
        self.assertEqual(result.returncode, 3)

    def test_watch_requires_absolute_collector(self) -> None:
        result = self.run_collector("watch", "--state-dir", str(self.state), "--collector", "collector")
        self.assertEqual(result.returncode, 2)


class ProbeCase(CollectorCase):
    """Offers shaped like the real browser offers."""

    PASSWORD = b"Pr0be-Secret-Password!!"
    PAGE_TEXT = b"An ordinary paragraph.\n"
    URL = b"https://example.org/abc"
    FIREFOX_TEXT_TYPES: tuple[str, ...] = (TEXT, "UTF8_STRING", "TEXT", "text/plain", "STRING")
    CHROMIUM_TEXT_TYPES: tuple[str, ...] = ("text/plain", TEXT, "UTF8_STRING", "TEXT", "STRING")

    def firefox(self, types: list[str], text: bytes, origin: str | None = None) -> None:
        payloads: dict[str, bytes] = dict.fromkeys(self.FIREFOX_TEXT_TYPES, text)
        payloads["COMPOUND_TEXT"] = b""
        if origin is not None:
            payloads[MOZ_ORIGIN] = utf16(origin)
        if "text/html" in types:
            payloads.update({"text/html": b"<p>" + text + b"</p>",
                             "text/_moz_htmlcontext": utf16("<html><body></body></html>"),
                             "text/_moz_htmlinfo": utf16("0,0")})
        self.offer(payloads, types=types)

    def chromium(self, types: list[str], text: bytes | None, source: str | None) -> None:
        payloads: dict[str, bytes] = dict.fromkeys(self.CHROMIUM_TEXT_TYPES, text) if text is not None else {}
        payloads[RFH_TOKEN] = bytes.fromhex("140000002d0000003eda338a5d15231e430fd5d555074cd6")
        if source is not None:
            payloads[CHROMIUM] = source.encode()
        if "text/html" in types:
            payloads["text/html"] = b"<p>" + (text or b"") + b"</p>"
        self.offer(payloads, types=types)

    def probe_emit(self, *extra: str) -> dict:
        return self.emit(f"--secret-source-prefix={PROBE_VAULT}", *extra)


class ProbeTests(ProbeCase):
    """The real browser offers: which copies enter history."""

    def test_firefox_extension_password_is_skipped_unread(self) -> None:
        self.firefox(FIREFOX_EXTENSION, self.PASSWORD)
        self.assertEqual(self.probe_emit(), {"kind": "skipped", "reason": "unattributed"})
        self.assertEqual(self.reads(), [], "neither payload nor markers are read")
        self.assertEqual(self.blobs(), [])
        self.assert_no_secret_on_disk(self.PASSWORD)

    def test_firefox_web_vault_password_is_skipped(self) -> None:
        self.firefox(FIREFOX_VAULT, self.PASSWORD, origin=PROBE_VAULT)
        self.assertEqual(self.probe_emit(), {"kind": "skipped", "reason": "source"})
        self.assertEqual(self.reads(), [MOZ_ORIGIN])
        self.assert_no_secret_on_disk(self.PASSWORD)

    def test_firefox_page_copy_is_recorded(self) -> None:
        self.firefox(FIREFOX_PAGE, self.PAGE_TEXT, origin="http://localhost:8333")
        event = self.probe_emit()
        self.assertEqual((event["kind"], event["mime"], event["preview"]), ("text", TEXT, self.PAGE_TEXT.decode()))

    def test_firefox_address_bar_copy_is_skipped(self) -> None:
        # The cost of the rule: Zen/Firefox address-bar copies offer exactly
        # what the extension's password copy offers.
        self.firefox(FIREFOX_URLBAR, self.URL)
        self.assertEqual(self.probe_emit(), {"kind": "skipped", "reason": "unattributed"})
        self.assertEqual(self.blobs(), [])

    def test_record_mode_keeps_unattributed_firefox_copies(self) -> None:
        self.firefox(FIREFOX_URLBAR, self.URL)
        event = self.probe_emit("--unattributed-firefox=record")
        self.assertEqual((event["kind"], event["preview"]), ("text", self.URL.decode()))
        self.assertIn(event["sha"], self.blobs())

    def test_firefox_clear_records_nothing(self) -> None:
        self.firefox(FIREFOX_CLEAR, b"")
        self.assertEqual(self.probe_emit(), {"kind": "skipped", "reason": "unattributed"})
        for payload in (b"", b"\x00", b" "):
            with self.subTest(payload=payload):
                self.firefox(FIREFOX_CLEAR, payload)
                self.assertEqual(self.probe_emit("--unattributed-firefox=record"),
                                 {"kind": "clear", "shape": shape_of(FIREFOX_CLEAR)})
        self.assertEqual(self.blobs(), [])

    def test_clear_shape_matches_only_the_same_offer_types(self) -> None:
        # The model purges on a clear only when its shape matches the newest
        # capture's: the extension's clear offers what its copy offered. A
        # failed transfer from an app without Gecko's shape is no clear at all.
        self.firefox(FIREFOX_EXTENSION, self.PASSWORD)
        copied = self.probe_emit("--unattributed-firefox=record")
        self.firefox(FIREFOX_CLEAR, b"")
        cleared = self.probe_emit("--unattributed-firefox=record")
        self.assertEqual(copied["kind"], "text")
        self.assertEqual(cleared["kind"], "clear")
        self.assertRegex(copied["shape"], r"^[0-9a-f]{16}$")
        self.assertEqual(cleared["shape"], copied["shape"])
        self.offer(dict.fromkeys(FOOT_TEXT, b""), types=FOOT_TEXT)
        self.assertEqual(self.probe_emit("--unattributed-firefox=record"), {"kind": "skipped", "reason": "empty"})

    def test_chromium_extension_password_is_skipped(self) -> None:
        self.chromium(CHROMIUM_EXTENSION, self.PASSWORD, BW_EXTENSION
                      + "popup/index.html#/view-cipher?cipherId=1bbd5ec6-9d73-4975-8748-0da727ee2426&type=1")
        self.assertEqual(self.probe_emit(), {"kind": "skipped", "reason": "source"})
        self.assertEqual(self.reads(), [CHROMIUM])
        self.assert_no_secret_on_disk(self.PASSWORD)

    def test_chromium_web_vault_password_is_skipped(self) -> None:
        self.chromium(CHROMIUM_VAULT, self.PASSWORD,
                      PROBE_VAULT + "/#/vault?itemId=1bbd5ec6-9d73-4975-8748-0da727ee2426&action=view")
        self.assertEqual(self.probe_emit(), {"kind": "skipped", "reason": "source"})
        self.assert_no_secret_on_disk(self.PASSWORD)

    def test_stalled_text_classification_is_skipped(self) -> None:
        # Benign offer A can answer the metadata reads while a secret offer B
        # answers the payload reads (A, B, A, B); that needs the reads to
        # stall long enough for several copies.
        self.text_gate = "0.25"
        self.chromium(CHROMIUM_PAGE, self.PAGE_TEXT, "http://localhost:8333/")
        (self.fake / "read-delay").write_text("0.15", encoding="utf-8")
        self.assertEqual(self.probe_emit(), {"kind": "skipped", "reason": "changed"})
        self.assertEqual(self.blobs(), [])

    def test_chromium_page_copy_is_recorded(self) -> None:
        self.chromium(CHROMIUM_PAGE, self.PAGE_TEXT, "http://localhost:8333/")
        event = self.probe_emit()
        self.assertEqual((event["kind"], event["mime"]), ("text", TEXT))

    def test_chromium_address_bar_copy_is_recorded(self) -> None:
        self.chromium(CHROMIUM_URLBAR, self.URL, None)
        event = self.probe_emit()
        self.assertEqual((event["kind"], event["preview"]), ("text", self.URL.decode()))

    def test_chromium_clear_records_nothing_and_never_clears(self) -> None:
        offscreen = BW_EXTENSION + "offscreen-document/index.html"
        self.chromium(CHROMIUM_CLEAR, None, offscreen)
        self.assertEqual(self.probe_emit(), {"kind": "skipped", "reason": "source"})
        # Without a matching prefix there is still no text to read.
        self.chromium(CHROMIUM_CLEAR, None, offscreen)
        result = self.run_collector("emit", "--state-dir", str(self.state), "--wl-paste", str(FAKE_PASTE))
        self.assertEqual(json.loads(result.stdout), {"kind": "skipped", "reason": "unsupported"})
        self.assertEqual(self.reads(), [CHROMIUM])
        self.assertEqual(self.blobs(), [])

    def test_gecko_shape_needs_every_marker(self) -> None:
        cases = [
            ([t for t in FIREFOX_PLAIN if t != "SAVE_TARGETS"], "text"),
            ([t for t in FIREFOX_PLAIN if t != "COMPOUND_TEXT"], "text"),
            (FIREFOX_PLAIN[:6] + FIREFOX_PLAIN[7:], "text"),
            (FIREFOX_PLAIN, "skipped"),
        ]
        for types, kind in cases:
            with self.subTest(types=types):
                self.firefox(types, self.URL)
                self.assertEqual(self.probe_emit()["kind"], kind)
        self.firefox(FIREFOX_VAULT, self.URL, origin="")
        self.assertEqual(self.probe_emit(), {"kind": "skipped", "reason": "unattributed"},
                         "an empty origin attributes nothing")


class AttributionTests(ProbeCase):
    """GTK3 apps offer Gecko's unattributed shape; niri's focus decides.

    A copy is recorded only when niri shows the same settled non-Gecko focus
    before the payload is read and after it is read again.
    """

    ZEN = "zen-beta"
    EDITOR = "org.gnome.TextEditor"
    TERMINAL_GTK = "com.example.GtkTerm"
    PAYLOAD_READ = f"--no-newline --type {TEXT}"
    NIRI_WINDOWS = "niri msg --json windows"

    def reset_niri(self) -> None:
        for path in self.fake.glob("niri-*"):
            path.unlink()

    def windows(self, *windows: dict) -> None:
        self.reset_niri()
        (self.fake / "niri-windows").write_text(json.dumps(list(windows)), encoding="utf-8")

    def samples(self, *answers: list[dict] | str) -> None:
        """One niri answer per call: a window list, or raw reply bytes."""
        self.reset_niri()
        for call, answer in enumerate(answers, 1):
            if isinstance(answer, str):
                (self.fake / f"niri-reply.{call}").write_text(answer, encoding="utf-8")
            else:
                (self.fake / f"niri-windows.{call}").write_text(json.dumps(answer), encoding="utf-8")

    def history(self, focused: str, focused_ms_ago: float, previous: str | None = None,
                previous_ms_ago: float = 60_000) -> None:
        """`focused` holds focus since `focused_ms_ago`; `previous` had it before."""
        windows = [{"id": 1, "app_id": focused, "is_focused": True, "focus_age_ms": focused_ms_ago}]
        if previous is not None:
            windows.append({"id": 2, "app_id": previous, "is_focused": False, "focus_age_ms": previous_ms_ago})
        windows.append({"id": 3, "app_id": "never-focused", "is_focused": False, "focus_timestamp": None})
        self.windows(*windows)

    def focused(self, app_id: str) -> None:
        self.history(app_id, 60_000, self.TERMINAL_GTK, 120_000)

    def raw_reply(self, raw: str) -> None:
        self.reset_niri()
        (self.fake / "niri-reply").write_text(raw, encoding="utf-8")

    def niri_calls(self) -> list[str]:
        log = self.fake / "niri.log"
        return log.read_text().splitlines() if log.exists() else []

    def niri_count(self) -> int:
        counter = self.fake / "niri-count"
        return int(counter.read_text()) if counter.exists() else 0

    def niri_emit(self, *extra: str) -> dict:
        return self.probe_emit(f"--niri={FAKE_NIRI}", *extra)

    def assert_password_skipped(self, message: str = "", *extra: str) -> None:
        """Skipped on niri's first answer, before anything is read."""
        self.firefox(FIREFOX_EXTENSION, self.PASSWORD)
        self.assertEqual(self.niri_emit(*extra), {"kind": "skipped", "reason": "unattributed"}, message)
        self.assertEqual(self.reads(), [], "neither payload nor markers are read")
        self.assertEqual(self.niri_count(), 1, message)
        self.assert_no_secret_on_disk(self.PASSWORD)

    def assert_password_skipped_after_reading(self, message: str = "", *extra: str) -> None:
        """Skipped on niri's second answer, after the payload was read twice."""
        self.firefox(FIREFOX_EXTENSION, self.PASSWORD)
        self.assertEqual(self.niri_emit(*extra), {"kind": "skipped", "reason": "unattributed"}, message)
        self.assertEqual(self.reads(), [TEXT, TEXT], message)
        self.assertEqual(self.niri_count(), 2, message)
        self.assertEqual(self.blobs(), [], message)
        self.assert_no_secret_on_disk(self.PASSWORD)

    def assert_recorded(self, *extra: str) -> None:
        self.firefox(FIREFOX_PLAIN, self.PAGE_TEXT)
        event = self.niri_emit(*extra)
        self.assertEqual((event["kind"], event.get("preview")), ("text", self.PAGE_TEXT.decode()))

    def settled_editor(self) -> list[dict]:
        return [{"id": 1, "app_id": self.EDITOR, "is_focused": True, "focus_age_ms": 60_000},
                {"id": 2, "app_id": self.ZEN, "is_focused": False, "focus_age_ms": 120_000}]

    def test_gtk3_copy_from_other_apps_is_recorded(self) -> None:
        for app_id in (self.EDITOR, "blueman-manager", "zenity", "firefox-tools"):
            with self.subTest(app_id=app_id):
                self.focused(app_id)
                self.assert_recorded()
        self.assertEqual(set(self.niri_calls()), {"msg --json windows"})

    def test_settled_gtk3_focus_in_both_samples_is_recorded(self) -> None:
        self.samples(self.settled_editor(), self.settled_editor())
        self.assert_recorded()
        log = (self.fake / "calls.log").read_text().splitlines()
        self.assertEqual(log, ["--list-types", self.NIRI_WINDOWS, self.PAYLOAD_READ,
                               "--list-types", self.PAYLOAD_READ, self.NIRI_WINDOWS],
                         "niri is asked before the first payload read and after the last")

    def test_empty_gtk3_offer_in_skip_mode_is_not_a_clear(self) -> None:
        # A settled GTK3 app's empty, NUL or space offer has the Gecko shape;
        # in the default mode it must not purge that app's previous copy.
        for payload in (b"", b"\x00", b" "):
            with self.subTest(payload=payload):
                self.samples(self.settled_editor(), self.settled_editor())
                self.firefox(FIREFOX_CLEAR, payload)
                self.assertEqual(self.niri_emit(), {"kind": "skipped", "reason": "empty"})

    def test_stalled_reads_between_identical_samples_are_skipped(self) -> None:
        # A mouse-only Zen visit commits no niri stamp, so both answers can
        # match while a stalled read returned the browser's copy.
        self.text_gate = "0.25"
        self.samples(self.settled_editor(), self.settled_editor())
        self.firefox(FIREFOX_EXTENSION, self.PASSWORD)
        (self.fake / "read-delay").write_text("0.2", encoding="utf-8")
        self.assertEqual(self.niri_emit(), {"kind": "skipped", "reason": "unattributed"})
        self.assertEqual(self.reads(), [TEXT, TEXT])
        self.assertEqual(self.niri_count(), 2)
        self.assertEqual(self.blobs(), [])
        self.assert_no_secret_on_disk(self.PASSWORD)

    def test_slow_first_focus_answer_counts_toward_the_gate(self) -> None:
        # niri takes its snapshot, then answers late: a Zen visit in that
        # time happens after the snapshot the first sample reflects.
        self.text_gate = "0.25"
        self.samples(self.settled_editor(), self.settled_editor())
        self.firefox(FIREFOX_EXTENSION, self.PASSWORD)
        # Below niri's 0.3 s timeout, but with the reads past the 250 ms gate.
        (self.fake / "niri-sleep.1").write_text("0.2", encoding="utf-8")
        (self.fake / "read-delay").write_text("0.03", encoding="utf-8")
        self.assertEqual(self.niri_emit(), {"kind": "skipped", "reason": "unattributed"})
        self.assertEqual(self.blobs(), [])
        self.assert_no_secret_on_disk(self.PASSWORD)

    def test_gtk3_copy_with_a_gecko_browser_focused_is_skipped_unread(self) -> None:
        for app_id in ("zen-beta", "zen", "firefox", "app.zen_browser.zen", "org.mozilla.firefox", "librewolf"):
            with self.subTest(app_id=app_id):
                self.focused(app_id)
                self.assert_password_skipped()

    def test_gecko_focused_in_the_second_sample_is_skipped(self) -> None:
        # Settle 0 leaves the Gecko match as the only reason to skip.
        zen_after_first = [{"id": 1, "app_id": self.EDITOR, "is_focused": False, "focus_age_ms": 60_000},
                           {"id": 2, "app_id": self.ZEN, "is_focused": True, "focus_age_ms": -1}]
        self.samples(self.settled_editor(), zen_after_first)
        self.assert_password_skipped_after_reading("", "--focus-settle-ms=0")

    def test_switch_between_samples_is_skipped(self) -> None:
        # The first answer approved the editor; then focus moved, and a Zen
        # copy made in that time is what the payload reads returned.
        editor, zen = self.settled_editor()
        second_answers = {
            "Zen focused, not yet stamped": [{**editor, "is_focused": False}, {**zen, "is_focused": True}],
            "Zen focused and stamped": [{**editor, "is_focused": False},
                                        {**zen, "is_focused": True, "focus_age_ms": 0}],
        }
        for via in (self.ZEN, self.TERMINAL_GTK):
            hop = {"id": 2, "app_id": via, "is_focused": False, "focus_age_ms": 0}
            second_answers[f"back in the editor via {via}, not yet stamped"] = [editor, hop]
            second_answers[f"back in the editor via {via}, stamped"] = [{**editor, "focus_age_ms": -1}, hop]
        for name, second in second_answers.items():
            with self.subTest(second=name):
                self.samples(self.settled_editor(), second)
                self.assert_password_skipped_after_reading(name)

    def test_focus_moved_between_samples_is_skipped(self) -> None:
        # Settle 0 makes the second focus settled, so only the change skips.
        editor, zen = self.settled_editor()
        second_answers = {
            "another app": [{**editor, "is_focused": False}, zen,
                            {"id": 4, "app_id": self.TERMINAL_GTK, "is_focused": True, "focus_age_ms": -1}],
            "another window of the same app": [{**editor, "is_focused": False}, zen,
                                               {"id": 4, "app_id": self.EDITOR, "is_focused": True,
                                                "focus_age_ms": -1}],
            "the same window, refocused": [{**editor, "focus_age_ms": -1}, zen],
        }
        for name, second in second_answers.items():
            with self.subTest(second=name):
                self.samples(self.settled_editor(), second)
                self.assert_password_skipped_after_reading(name, "--focus-settle-ms=0")

    def test_niri_failure_on_the_second_sample_is_skipped(self) -> None:
        editor, zen = self.settled_editor()
        cases = {
            "exit status": lambda: (self.samples(self.settled_editor(), self.settled_editor()),
                                    (self.fake / "niri-exit.2").write_text("1")),
            "timeout": lambda: (self.samples(self.settled_editor(), self.settled_editor()),
                                (self.fake / "niri-sleep.2").write_text("5")),
            "unparseable": lambda: self.samples(self.settled_editor(), "{not json"),
            "no focused window": lambda: self.samples(self.settled_editor(), [{**editor, "is_focused": False}, zen]),
        }
        for name, arrange in cases.items():
            with self.subTest(case=name):
                arrange()
                self.assert_password_skipped_after_reading(name)

    def test_copy_then_quick_switch_away_from_zen_is_skipped(self) -> None:
        # Copied in Zen, then Alt-Tab to a GTK3 app before the collector asked.
        self.history(self.EDITOR, 50, previous=self.ZEN, previous_ms_ago=10_000)
        self.assert_password_skipped("a focus change 50 ms old leaves the copy with Zen")
        self.assertEqual(self.niri_calls(), ["msg --json windows"], "niri is asked once")

    def test_switch_away_from_zen_inside_niris_debounce_is_skipped(self) -> None:
        # niri stamps a refocused window only after recent-windows debounce
        # (750 ms): until then the focused editor keeps its old stamp and Zen's
        # is the newest.
        self.windows({"id": 1, "app_id": self.EDITOR, "is_focused": True, "focus_age_ms": 3_600_000},
                     {"id": 2, "app_id": self.ZEN, "is_focused": False, "focus_age_ms": 30_000})
        self.assert_password_skipped("a focus niri has not committed yet is unsettled")

    def test_new_focus_is_skipped_whatever_came_before(self) -> None:
        cases = {
            "young stamp": [{"id": 1, "app_id": self.EDITOR, "is_focused": True, "focus_age_ms": 50},
                            {"id": 2, "app_id": self.TERMINAL_GTK, "is_focused": False, "focus_age_ms": 10_000}],
            "not yet stamped": [{"id": 1, "app_id": self.EDITOR, "is_focused": True, "focus_age_ms": 3_600_000},
                                {"id": 2, "app_id": self.TERMINAL_GTK, "is_focused": False, "focus_age_ms": 30_000}],
            "never stamped": [{"id": 1, "app_id": self.EDITOR, "is_focused": True, "focus_timestamp": None},
                              {"id": 2, "app_id": self.TERMINAL_GTK, "is_focused": False, "focus_age_ms": 30_000}],
        }
        for name, windows in cases.items():
            with self.subTest(case=name):
                self.windows(*windows)
                self.assert_password_skipped(name)

    def test_two_hop_switch_from_zen_is_skipped(self) -> None:
        # Zen, then another app long enough for niri to stamp it, then the
        # editor: the newest unfocused window is the intermediate app.
        hops = [{"id": 2, "app_id": self.TERMINAL_GTK, "is_focused": False, "focus_age_ms": 1_000},
                {"id": 3, "app_id": self.ZEN, "is_focused": False, "focus_age_ms": 2_500}]
        cases = {
            "editor not yet stamped": {"id": 1, "app_id": self.EDITOR, "is_focused": True,
                                       "focus_age_ms": 3_600_000},
            "editor stamped": {"id": 1, "app_id": self.EDITOR, "is_focused": True, "focus_age_ms": 100},
        }
        for name, editor in cases.items():
            with self.subTest(case=name):
                self.windows(editor, *hops)
                self.assert_password_skipped(name)

    def test_settled_focus_after_zen_is_recorded(self) -> None:
        self.history(self.EDITOR, 5_000, previous=self.ZEN, previous_ms_ago=60_000)
        self.assert_recorded()

    def test_focus_settle_is_configurable(self) -> None:
        self.history(self.EDITOR, 5_000, previous=self.ZEN)
        self.firefox(FIREFOX_EXTENSION, self.PASSWORD)
        self.assertEqual(self.niri_emit("--focus-settle-ms=10000"), {"kind": "skipped", "reason": "unattributed"})
        self.history(self.EDITOR, 50, previous=self.ZEN)
        self.assert_recorded("--focus-settle-ms=0")

    def test_unknown_owner_fails_closed(self) -> None:
        focused = {"id": 1, "app_id": self.EDITOR, "is_focused": True}
        cases = {
            "exit status": lambda: (self.focused(self.EDITOR), (self.fake / "niri-exit").write_text("1")),
            "timeout": lambda: (self.focused(self.EDITOR), (self.fake / "niri-sleep").write_text("5")),
            "unparseable": lambda: self.raw_reply("{not json"),
            "not a list": lambda: self.raw_reply(json.dumps({**focused, "focus_timestamp": {"secs": 1, "nanos": 0}})),
            "no windows": lambda: self.windows(),
            "no focused window": lambda: self.windows({**focused, "is_focused": False, "focus_age_ms": 9_000}),
            "two focused windows": lambda: self.windows({**focused, "focus_age_ms": 9_000},
                                                        {**focused, "id": 2, "focus_age_ms": 8_000}),
            "no app_id": lambda: self.windows({**focused, "app_id": None, "focus_age_ms": 9_000}),
            "no window id": lambda: self.windows({**focused, "id": None, "focus_age_ms": 9_000}),
            "window id not an integer": lambda: self.windows({**focused, "id": "1", "focus_age_ms": 9_000}),
            "focused window without timestamp": lambda: self.windows({**focused, "focus_timestamp": None}),
            "malformed timestamp": lambda: self.windows({**focused, "focus_timestamp": {"secs": "1", "nanos": 0}}),
            "malformed timestamp on another window": lambda: self.windows(
                {**focused, "focus_age_ms": 9_000},
                {"id": 2, "app_id": self.TERMINAL_GTK, "is_focused": False, "focus_timestamp": [1, 0]}),
            "young lone focus": lambda: self.windows({**focused, "focus_age_ms": 50}),
        }
        for name, arrange in cases.items():
            with self.subTest(case=name):
                arrange()
                started = time.monotonic()
                self.assert_password_skipped(name)
                self.assertLess(time.monotonic() - started, 3.0, "the niri query is bounded")

    def test_settled_lone_window_is_recorded(self) -> None:
        self.windows({"id": 1, "app_id": self.EDITOR, "is_focused": True, "focus_age_ms": 9_000})
        self.assert_recorded()

    def test_without_niri_unattributed_copies_are_skipped(self) -> None:
        self.firefox(FIREFOX_URLBAR, self.URL)
        self.assertEqual(self.probe_emit(), {"kind": "skipped", "reason": "unattributed"})

    def test_gecko_app_ids_are_configurable(self) -> None:
        self.focused("zen-beta")
        self.firefox(FIREFOX_URLBAR, self.URL)
        self.assertEqual(self.niri_emit("--gecko-app-ids=^my-browser$")["kind"], "text")
        self.focused("my-browser")
        self.firefox(FIREFOX_URLBAR, self.URL)
        self.assertEqual(self.niri_emit("--gecko-app-ids=^my-browser$"),
                         {"kind": "skipped", "reason": "unattributed"})

    def test_niri_is_only_asked_about_the_gtk3_shape(self) -> None:
        self.focused("zen-beta")
        offers = {
            "chromium page": lambda: self.chromium(CHROMIUM_PAGE, self.PAGE_TEXT, "http://localhost:8333/"),
            "chromium address bar": lambda: self.chromium(CHROMIUM_URLBAR, self.URL, None),
            "firefox page": lambda: self.firefox(FIREFOX_PAGE, self.PAGE_TEXT, origin="http://localhost:8333"),
            "qt": lambda: self.offer(dict.fromkeys(QT_TEXT, self.URL), types=QT_TEXT),
            "foot": lambda: self.offer(dict.fromkeys(FOOT_TEXT, self.URL), types=FOOT_TEXT),
            "wl-copy": lambda: self.offer(dict.fromkeys(WL_COPY_TEXT, self.URL), types=WL_COPY_TEXT),
            "image": lambda: self.offer({"image/png": b"\x89PNG"}),
        }
        for name, arrange in offers.items():
            with self.subTest(offer=name):
                arrange()
                self.assertIn(self.niri_emit()["kind"], ("text", "image"))
        self.firefox(FIREFOX_URLBAR, self.URL)
        self.assertEqual(self.niri_emit("--unattributed-firefox=record")["kind"], "text")
        self.assertEqual(self.niri_calls(), [], "niri was queried for an offer without the GTK3 shape")


class LockTests(CollectorCase):
    """A blob replace and rm/gc's check-then-unlink never interleave."""

    def test_rm_keeps_a_blob_recaptured_while_it_waited(self) -> None:
        payload = b"recaptured content"
        sha = hashlib.sha256(payload).hexdigest()
        blobs = self.plant_blobs({sha: payload}, age=60)
        decided = (time.time() - 30) * 1000
        lock = self.hold_state_lock()
        try:
            rm = self.start_collector("rm", "--state-dir", str(self.state), "--before-ms", str(decided), "--sha", sha)
            time.sleep(0.5)
            self.assertIsNone(rm.poll(), "rm must wait for the state lock")
            (blobs / sha).write_bytes(payload)
        finally:
            os.close(lock)
        out, err = rm.communicate(timeout=10)
        self.assertEqual(rm.returncode, 0, err)
        self.assertEqual(json.loads(out), {"ok": True, "removed": 0})
        self.assertEqual(self.blobs(), [sha])

    def test_gc_waits_for_the_state_lock(self) -> None:
        orphan = hashlib.sha256(b"orphan").hexdigest()
        self.plant_blobs({orphan: b"orphan"}, age=3600)
        lock = self.hold_state_lock()
        try:
            gc = self.start_collector("gc", "--state-dir", str(self.state), "--grace-sec", "0")
            time.sleep(0.5)
            self.assertIsNone(gc.poll(), "gc must wait for the state lock")
            self.assertEqual(self.blobs(), [orphan])
        finally:
            os.close(lock)
        out, _ = gc.communicate(timeout=10)
        self.assertEqual(json.loads(out), {"ok": True, "removed": 1, "deferred": 0})

    def test_capture_replaces_under_the_lock_and_stamps_the_replace(self) -> None:
        payload = b"captured under lock"
        self.offer({TEXT: payload})
        lock = self.hold_state_lock()
        try:
            emit = self.start_collector("emit", "--state-dir", str(self.state), "--wl-paste", str(FAKE_PASTE))
            time.sleep(0.8)
            self.assertIsNone(emit.poll(), "the capture must wait for the state lock")
            self.assertEqual([name for name in self.blobs() if not name.startswith(".tmp-")], [],
                             "only the temp file exists before the replace")
            released = time.time()
        finally:
            os.close(lock)
        out, err = emit.communicate(timeout=10)
        self.assertEqual(emit.returncode, 0, err)
        sha = json.loads(out)["sha"]
        self.assertGreaterEqual((self.state / "blobs" / sha).stat().st_mtime, released - 0.05,
                                "mtime is the replace time, not the write time")

    def test_symlinked_lock_is_refused(self) -> None:
        victim = hashlib.sha256(b"v").hexdigest()
        self.plant_blobs({victim: b"v"}, age=3600)
        outside = self.tmp / "outside"
        outside.write_bytes(b"untouched")
        (self.state / ".lock").symlink_to(outside)
        for command in (("rm", "--state-dir", str(self.state), "--sha", victim),
                        ("gc", "--state-dir", str(self.state), "--grace-sec", "0")):
            with self.subTest(command=command[0]):
                self.assertEqual(self.run_collector(*command).returncode, 1)
        self.assertEqual(self.blobs(), [victim])
        self.assertEqual(outside.read_bytes(), b"untouched")


class ArgumentTests(CollectorCase):
    def test_bad_numbers_are_refused_before_touching_files(self) -> None:
        victim = hashlib.sha256(b"victim").hexdigest()
        self.plant_blobs({victim: b"victim"}, age=3600)
        for value in ("nan", "NaN", "inf", "-inf", "-1", "1e999"):
            with self.subTest(value=value):
                rm = self.run_collector("rm", "--state-dir", str(self.state), f"--before-ms={value}", "--sha", victim)
                gc = self.run_collector("gc", "--state-dir", str(self.state), f"--grace-sec={value}")
                self.assertEqual((rm.returncode, gc.returncode), (2, 2))
                self.assertEqual(rm.stdout + gc.stdout, b"")
        self.assertEqual(self.blobs(), [victim])
        self.assertFalse((self.state / ".lock").exists(), "no state file was touched")


class OrphanTests(CollectorCase):
    def test_emit_under_a_foreign_parent_reads_nothing(self) -> None:
        self.offer({TEXT: SECRET})
        result = self.run_collector(
            "emit", "--state-dir", str(self.state), "--wl-paste", str(FAKE_PASTE),
            env={"STILLSUIT_CLIPBOARD_WATCH_PID": str(os.getpid())},
        )
        self.assertEqual((result.returncode, result.stdout), (1, b""))
        self.assertIn(b"not running under its watcher", result.stderr)
        self.assertFalse((self.fake / "calls.log").exists())

    def test_watch_under_its_owner_starts_wl_paste(self) -> None:
        result = self.run_collector(
            "watch", "--state-dir", str(self.state), "--collector", str(COLLECTOR),
            "--wl-paste", str(FAKE_PASTE), "--owner-pid", str(os.getpid()))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.fake / "watch.argv").exists())

    def test_watch_orphaned_before_it_started_collects_nothing(self) -> None:
        # The owner spawns watch and dies before watch arms its death signal,
        # so watch starts already reparented to a subreaper.
        child_pid = self.tmp / "child.pid"
        child_err = self.tmp / "child.err"
        owner = subprocess.run(
            [sys.executable, "-c",
             "import os, sys, time\n"
             "if os.fork() == 0:\n"
             "    owner = os.getppid()\n"
             "    while os.getppid() == owner:\n"
             "        time.sleep(0.01)\n"
             "    os.dup2(os.open(sys.argv[2], os.O_WRONLY | os.O_CREAT, 0o600), 2)\n"
             "    open(sys.argv[1], 'w').write(str(os.getpid()))\n"
             "    os.execvp(sys.argv[3], sys.argv[3:] + ['--owner-pid', str(owner)])\n",
             str(child_pid), str(child_err), *self.command(), "watch", "--state-dir", str(self.state),
             "--collector", str(COLLECTOR), "--wl-paste", str(FAKE_PASTE)],
            env=self.collector_env(), timeout=10, check=False,
        )
        self.assertEqual(owner.returncode, 0)
        deadline = time.monotonic() + 10
        while not child_pid.exists() or not child_pid.read_text():
            self.assertLess(time.monotonic(), deadline, "the orphan never started")
            time.sleep(0.02)
        pid = int(child_pid.read_text())
        try:
            while Path(f"/proc/{pid}").exists() and time.monotonic() < deadline:
                time.sleep(0.05)
            self.assertFalse(Path(f"/proc/{pid}").exists(), "the orphaned watch kept running")
        finally:
            with contextlib.suppress(ProcessLookupError):
                os.kill(pid, signal.SIGKILL)
        self.assertFalse((self.fake / "calls.log").exists(), "the orphaned watch started wl-paste")
        self.assertIn(b"watch outlived its owner", child_err.read_bytes())

    def test_watcher_killed_during_emit_bootstrap(self) -> None:
        # The fake wl-paste starts emit through a shell that sleeps before
        # exec; the watcher dies meanwhile, so emit starts already orphaned.
        scenario = self.fake / "scenarios" / "01"
        (scenario / "payloads").mkdir(parents=True)
        (scenario / "types").write_text(TEXT + "\n", encoding="utf-8")
        (scenario / "payloads" / urllib.parse.quote(TEXT, safe="")).write_bytes(SECRET)
        (scenario / "delay").write_text("1")
        events = self.tmp / "events"
        errors = self.tmp / "errors"
        with events.open("wb") as sink, errors.open("wb") as error_sink:
            watcher = subprocess.Popen(
                [*self.command(), "watch", "--state-dir", str(self.state), "--collector", str(COLLECTOR),
                 "--wl-paste", str(FAKE_PASTE)],
                stdout=sink, stderr=error_sink, env=self.collector_env(),
            )
        try:
            deadline = time.monotonic() + 10
            while not (self.fake / "emit-starting").exists():
                self.assertLess(time.monotonic(), deadline, "emit never started")
                time.sleep(0.02)
            watcher.kill()
            watcher.wait(timeout=10)
        finally:
            if watcher.poll() is None:
                watcher.kill()
                watcher.wait()
        deadline = time.monotonic() + 5
        while not errors.read_bytes() and not events.read_bytes() and time.monotonic() < deadline:
            time.sleep(0.05)
        time.sleep(0.5)
        self.assertEqual(events.read_bytes(), b"", "the orphaned emit produced an event")
        self.assertEqual(self.blobs(), [], "the orphaned emit wrote a blob")
        calls = (self.fake / "calls.log").read_text().splitlines()
        self.assertEqual([c for c in calls if not c.startswith("--watch")], [], "the orphan read nothing")
        self.assertIn(b"not running under its watcher", errors.read_bytes())
        self.assert_no_secret_on_disk()


if __name__ == "__main__":
    unittest.main(verbosity=1)
