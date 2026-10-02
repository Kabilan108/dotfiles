from __future__ import annotations

import email.utils
import http.client
import importlib.machinery
import importlib.util
import json
import os
import tempfile
import threading
import time
import urllib.error
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from types import SimpleNamespace
from typing import Any, Self


def load_helper(path: Path) -> Any:
    loader = importlib.machinery.SourceFileLoader("stillsuit_agent_usage", str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    if spec is None:
        raise RuntimeError("could not load agent usage helper")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


class FakeResponse:
    def __init__(self, payload: dict[str, Any]) -> None:
        self.payload = payload

    def __enter__(self) -> Self:
        return self

    def __exit__(self, *args: object) -> None:
        return None

    def read(self) -> bytes:
        return json.dumps(self.payload).encode()


def main() -> None:
    helper_path = Path(__file__).resolve().parents[3] / "bin" / "stillsuit-agent-usage"
    helper = load_helper(helper_path)

    with tempfile.TemporaryDirectory(prefix="stillsuit-agent-usage-test-") as temp:
        root = Path(temp)
        home = root / "home"
        shadow = home / ".shadow-home-dirs"
        direct_claude = shadow / "claude--direct"
        t3_claude = shadow / "claude--t3" / ".claude"
        codex_shadow = shadow / "codex--rani"
        for directory in (direct_claude, t3_claude, codex_shadow):
            directory.mkdir(parents=True)
        (direct_claude / ".credentials.json").write_text("{}")
        (t3_claude / ".credentials.json").write_text("{}")
        (codex_shadow / "auth.json").write_text("{}")

        accounts = helper.discover_accounts(
            {"homeDir": str(home), "shadowRoot": str(shadow)}
        )
        by_id = {account["id"]: account for account in accounts}
        assert by_id["codex-default"]["configDir"] == str(home / ".codex")
        assert by_id["claude-default"]["configDir"] == str(home / ".claude")
        assert by_id["codex-rani"]["configDir"] == str(codex_shadow)
        assert by_id["claude-direct"]["configDir"] == str(direct_claude)
        assert by_id["claude-t3"]["configDir"] == str(t3_claude)

        configured_home = root / "configured-home"
        configured = helper.discover_accounts(
            {
                "homeDir": str(home),
                "includeDefaults": False,
                "accounts": [
                    {
                        "id": "claude-work",
                        "provider": "claude",
                        "label": "Work",
                        "homeDir": str(configured_home),
                    },
                    {
                        "id": "codex-rani-copy",
                        "provider": "codex",
                        "label": "Duplicate",
                        "configDir": str(codex_shadow),
                    },
                ],
                "shadowRoot": str(shadow),
            }
        )
        assert any(
            account["id"] == "claude-work"
            and account["configDir"] == str(configured_home / ".claude")
            for account in configured
        )
        assert (
            sum(
                account["provider"] == "codex"
                and account["configDir"] == str(codex_shadow)
                for account in configured
            )
            == 1
        )

        token = "fixture-secret-token"
        claude_dir = root / "claude-profile"
        claude_dir.mkdir()
        (claude_dir / ".credentials.json").write_text(
            json.dumps(
                {
                    "claudeAiOauth": {
                        "accessToken": token,
                        "expiresAt": 4_102_444_800_000,
                        "rateLimitTier": "default_claude_max_20x",
                    }
                }
            )
        )
        captured_headers: dict[str, str] = {}

        def fake_urlopen(request: Any, timeout: int = 0) -> FakeResponse:
            captured_headers.update(dict(request.header_items()))
            assert timeout == 12
            return FakeResponse(
                {
                    "five_hour": {
                        "utilization": 1.0,
                        "resets_at": "2030-01-02T03:04:05Z",
                    },
                    "seven_day": {
                        "utilization": 37,
                        "resets_at": "2030-01-08T03:04:05Z",
                    },
                    "limits": [
                        {
                            "kind": "weekly_scoped",
                            "percent": 62,
                            "resets_at": "2030-01-08T03:04:05Z",
                            "scope": {"model": {"display_name": "Opus"}},
                        }
                    ],
                }
            )

        original_open_usage_request = helper._open_usage_request
        helper._open_usage_request = fake_urlopen
        try:
            claude_result = helper._collect_claude(
                helper._account("claude", "Fixture", claude_dir, "configured")
            )
        finally:
            helper._open_usage_request = original_open_usage_request
        assert captured_headers["Authorization"] == f"Bearer {token}"
        assert token not in json.dumps(claude_result)
        assert claude_result["plan"] == "Max 20x"
        assert [window["used"] for window in claude_result["windows"]] == [
            0.01,
            0.37,
            0.62,
        ]
        assert claude_result["windows"][2]["label"] == "Opus Weekly"

        low_usage = helper._claude_windows(
            {
                "five_hour": {"utilization": 0.5},
                "seven_day": {"utilization": 0.8},
            }
        )
        assert [window["used"] for window in low_usage] == [0.005, 0.008]

        redirected_headers: list[str] = []

        class RedirectTarget(BaseHTTPRequestHandler):
            def do_GET(self) -> None:
                redirected_headers.append(self.headers.get("Authorization", ""))
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(b"{}")

            def log_message(self, format: str, *args: Any) -> None:
                return None

        target = ThreadingHTTPServer(("127.0.0.1", 0), RedirectTarget)
        target_thread = threading.Thread(target=target.serve_forever, daemon=True)
        target_thread.start()

        class RedirectSource(BaseHTTPRequestHandler):
            def do_GET(self) -> None:
                self.send_response(302)
                self.send_header(
                    "Location",
                    f"http://127.0.0.1:{target.server_address[1]}/capture",
                )
                self.end_headers()

            def log_message(self, format: str, *args: Any) -> None:
                return None

        source = ThreadingHTTPServer(("127.0.0.1", 0), RedirectSource)
        source_thread = threading.Thread(target=source.serve_forever, daemon=True)
        source_thread.start()
        original_endpoint = helper.ANTHROPIC_USAGE_ENDPOINT
        helper.ANTHROPIC_USAGE_ENDPOINT = (
            f"http://127.0.0.1:{source.server_address[1]}/usage"
        )
        try:
            redirected_result = helper._collect_claude(
                helper._account("claude", "Fixture", claude_dir, "configured")
            )
        finally:
            helper.ANTHROPIC_USAGE_ENDPOINT = original_endpoint
            source.shutdown()
            target.shutdown()
            source.server_close()
            target.server_close()
            source_thread.join()
            target_thread.join()
        assert redirected_result["status"] == "error"
        assert redirected_result["statusText"] == "Usage request failed (302)"
        assert redirected_headers == []

        invalid_dir = root / "invalid-claude-profile"
        invalid_dir.mkdir()
        (invalid_dir / ".credentials.json").write_text("[]")
        invalid_result = helper._collect_claude(
            helper._account("claude", "Invalid", invalid_dir, "configured")
        )
        assert invalid_result["status"] == "error"
        assert invalid_result["statusText"] == "Credentials are invalid"

        primary = helper._codex_window(
            "primary",
            {
                "usedPercent": 42,
                "windowDurationMins": 300,
                "resetsAt": 1_893_456_000,
            },
        )
        assert primary == {
            "id": "primary",
            "label": "5 hour",
            "used": 0.42,
            "resetsAt": "2030-01-01T00:00:00+00:00",
        }
        assert helper._humanize_plan("proLite") == "Pro Lite"
        assert helper._humanize_plan("prolite") == "Pro Lite"
        assert helper._humanize_plan("chatgpt_team") == "ChatGPT Team"
        assert helper._normalize_reset(1_893_456_000.0) == "2030-01-01T00:00:00+00:00"

        fake_codex = root / "fake-codex"
        fake_codex.write_text(
            """#!/usr/bin/env python3
import json
import os
import sys
from pathlib import Path

if sys.argv[1:] != ["app-server"]:
    raise SystemExit(2)
probe_home = Path(os.environ["CODEX_HOME"])
if not (probe_home / "auth.json").is_file():
    raise SystemExit(3)
auth = json.loads((probe_home / "auth.json").read_text())
if auth["tokens"]["refresh_token"] != "":
    raise SystemExit(4)
if os.environ.get("CODEX_REFRESH_TOKEN_URL_OVERRIDE") != "http://127.0.0.1:0/token":
    raise SystemExit(5)
if "127.0.0.1" not in os.environ.get("NO_PROXY", "").split(","):
    raise SystemExit(6)
if "127.0.0.1" not in os.environ.get("no_proxy", "").split(","):
    raise SystemExit(7)
if (probe_home / "auth.json").stat().st_mode & 0o777 != 0o600:
    raise SystemExit(8)
(probe_home / "app-server-created").write_text("probe state")
for line in sys.stdin:
    request = json.loads(line)
    request_id = request.get("id")
    method = request.get("method")
    if request_id is None:
        continue
    if method == "initialize":
        response = {"id": request_id, "result": {}}
    elif method == "account/read":
        response = {
            "id": request_id,
            "result": {"account": {"email": "fixture@example.test"}},
        }
    elif os.environ.get("STILLSUIT_TEST_CODEX_RPC_ERROR") == "1":
        response = {"id": request_id, "error": {"code": -1, "message": "fixture"}}
    else:
        response = {
            "id": request_id,
            "result": {
                "rateLimits": {
                    "planType": "proLite",
                    "primary": {
                        "usedPercent": 12,
                        "windowDurationMins": 300,
                    },
                }
            },
        }
    print(json.dumps(response), flush=True)
"""
        )
        fake_codex.chmod(0o755)
        codex_dir = root / "codex-profile"
        codex_dir.mkdir()
        auth_contents = json.dumps(
            {
                "auth_mode": "chatgpt",
                "tokens": {
                    "access_token": "near-expiry-access",
                    "account_id": "fixture-account",
                    "id_token": "fixture-id",
                    "refresh_token": "must-not-leave-source",
                },
                "last_refresh": "2000-01-01T00:00:00Z",
            }
        )
        (codex_dir / "auth.json").write_text(auth_contents)
        original_which = helper.shutil.which
        helper.shutil.which = lambda name: str(fake_codex) if name == "codex" else None
        try:
            codex_result = helper._collect_codex(
                helper._account("codex", "Fixture", codex_dir, "configured")
            )
            os.environ["STILLSUIT_TEST_CODEX_RPC_ERROR"] = "1"
            rpc_error_result = helper._collect_codex(
                helper._account("codex", "Fixture", codex_dir, "configured")
            )
        finally:
            os.environ.pop("STILLSUIT_TEST_CODEX_RPC_ERROR", None)
            helper.shutil.which = original_which
        assert codex_result["status"] == "ready"
        assert codex_result["plan"] == "Pro Lite"
        assert codex_result["windows"][0]["used"] == 0.12
        assert rpc_error_result["status"] == "error"
        assert rpc_error_result["statusText"] == "Codex usage is unavailable"
        assert [path.name for path in codex_dir.iterdir()] == ["auth.json"]
        assert (codex_dir / "auth.json").read_text() == auth_contents

        assert helper._retry_after_seconds("120") == 120
        assert helper._retry_after_seconds(" 0 ") == 0
        assert helper._retry_after_seconds("") is None
        assert helper._retry_after_seconds(None) is None
        assert helper._retry_after_seconds("soon") is None
        assert helper._retry_after_seconds("-5") is None
        future = helper._utc_now() + helper.dt.timedelta(minutes=10)
        until_future = helper._retry_after_seconds(email.utils.format_datetime(future, usegmt=True))
        assert until_future is not None and 590 <= until_future <= 600
        assert helper._retry_after_seconds("Wed, 21 Oct 2015 07:28:00 GMT") == 0
        assert helper._retry_after_seconds("999999999") == helper.MAX_RETRY_AFTER_SECONDS

        clock = [1000.0]
        responses: list[Any] = []
        requests: list[str] = []

        def scripted_urlopen(request: Any, timeout: int = 0) -> FakeResponse:
            requests.append(request.full_url)
            response = responses.pop(0)
            if isinstance(response, BaseException):
                raise response
            return FakeResponse(response)

        def rate_limited(retry_after: str | None = None) -> urllib.error.HTTPError:
            headers = http.client.HTTPMessage()
            if retry_after is not None:
                headers["Retry-After"] = retry_after
            return urllib.error.HTTPError(
                helper.ANTHROPIC_USAGE_ENDPOINT, 429, "Too Many Requests", headers, None
            )

        usage = {"seven_day": {"utilization": 40, "resets_at": "2030-01-08T03:04:05Z"}}
        claude_account = helper._account("claude", "Default", claude_dir, "default")
        original_time = helper.time
        helper.time = SimpleNamespace(monotonic=lambda: clock[0], time=time.time)
        helper._open_usage_request = scripted_urlopen
        helper._account_states.clear()
        try:
            responses.append(usage)
            fresh = helper._collect_account(claude_account, False)
            assert fresh["status"] == "ready" and fresh["stale"] is False
            assert helper.FAILURE_KEY not in fresh

            clock[0] += 60
            assert helper._collect_account(claude_account, False) is fresh
            assert len(requests) == 1, "panel opens within the cache window reuse the result"

            clock[0] += helper.CACHE_SECONDS
            responses.append(rate_limited())
            stale = helper._collect_account(claude_account, False)
            assert len(requests) == 2
            assert stale["status"] == "ready" and stale["stale"] is True
            assert stale["staleReason"] == "Rate limited"
            assert stale["windows"] == fresh["windows"]
            assert stale["fetchedAt"] == fresh["fetchedAt"]
            assert stale["retryAt"] != ""
            assert helper.FAILURE_KEY not in stale
            state = next(iter(helper._account_states.values()))
            assert state.backoff_seconds == helper.RATE_LIMIT_BACKOFF_SECONDS

            clock[0] += helper.CACHE_SECONDS + 1
            assert helper._collect_account(claude_account, False) is stale
            assert len(requests) == 2, "exponential backoff skips the network"

            responses.append(rate_limited())
            assert helper._collect_account(claude_account, True)["stale"] is True
            assert len(requests) == 3, "a forced refresh bypasses exponential backoff"
            assert state.backoff_seconds == 2 * helper.RATE_LIMIT_BACKOFF_SECONDS

            for _ in range(5):
                responses.append(rate_limited())
                helper._collect_account(claude_account, True)
            assert state.backoff_seconds == helper.MAX_RATE_LIMIT_BACKOFF_SECONDS

            responses.append(rate_limited("900"))
            explicit = helper._collect_account(claude_account, True)
            assert explicit["stale"] is True
            requested = len(requests)
            clock[0] += 899
            assert helper._collect_account(claude_account, True) is explicit
            assert len(requests) == requested, "a forced refresh honours Retry-After"

            clock[0] += 2
            responses.append(usage)
            recovered = helper._collect_account(claude_account, True)
            assert recovered["stale"] is False and recovered["retryAt"] == ""
            assert state.backoff_seconds == 0 and state.backoff_until == 0

            clock[0] += helper.CACHE_SECONDS
            responses.append(urllib.error.URLError("offline"))
            offline = helper._collect_account(claude_account, False)
            assert offline["status"] == "ready" and offline["stale"] is True
            assert offline["staleReason"] == "Claude usage is unreachable"
            assert offline["retryAt"] == "" and state.backoff_until == 0

            helper._account_states.clear()
            responses.append(rate_limited("60"))
            first_failure = helper._collect_account(claude_account, False)
            assert first_failure["status"] == "error"
            assert first_failure["statusText"] == "Rate limited"
            assert first_failure["windows"] == [] and first_failure["stale"] is False
            assert first_failure["retryAt"] != ""
            assert responses == []
        finally:
            helper.time = original_time
            helper._open_usage_request = original_open_usage_request
            helper._account_states.clear()

        helper.shutil.which = lambda name: str(fake_codex) if name == "codex" else None
        codex_account = helper._account("codex", "Default", codex_dir, "default")
        try:
            codex_fresh = helper._collect_account(codex_account, True)
            os.environ["STILLSUIT_TEST_CODEX_RPC_ERROR"] = "1"
            codex_stale = helper._collect_account(codex_account, True)
        finally:
            os.environ.pop("STILLSUIT_TEST_CODEX_RPC_ERROR", None)
            helper.shutil.which = original_which
            helper._account_states.clear()
        assert codex_fresh["status"] == "ready" and codex_fresh["stale"] is False
        assert codex_stale["status"] == "ready" and codex_stale["stale"] is True
        assert codex_stale["staleReason"] == "Codex usage is unavailable"
        assert codex_stale["windows"] == codex_fresh["windows"]
        assert codex_stale["identity"] == "fixture@example.test"

        original_collect = helper._collect_account

        def fake_collect(account: dict[str, Any], force: bool) -> dict[str, Any]:
            result = helper._empty_result(account)
            result.update(
                status="ready",
                statusText="",
                windows=[{"id": "primary", "label": "Limit", "used": 0.73}],
            )
            return result

        helper._collect_account = fake_collect
        try:
            snapshot = helper.collect_snapshot(
                {"homeDir": str(home), "includeDefaults": True}
            )
        finally:
            helper._collect_account = original_collect
        assert snapshot["summary"] == {
            "accountCount": 2,
            "readyCount": 2,
            "maxUsed": 0.73,
        }
        assert [account["provider"] for account in snapshot["accounts"]] == [
            "codex",
            "claude",
        ]
        assert helper._dispatch([])["operation"] == "error"

    print("agent usage helper tests ok")


if __name__ == "__main__":
    main()
