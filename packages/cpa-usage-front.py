"""Answers sera's two CPA calls with CPA's management key, so sera never holds it.

GET  /v0/management/auth-files: Claude and Codex accounts, only the fields sera reads.
POST /v0/management/api-call:   that account's usage. Only auth_index is read from the
                                request; the URL and headers are fixed per provider.
"""

import json
import os
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

CPA = "http://127.0.0.1:8317/v0/management/"
KEY = os.environ["CLIPROXY_MANAGEMENT_KEY"]
USAGE = {
    "claude": (
        "https://api.anthropic.com/api/oauth/usage",
        {"anthropic-beta": "oauth-2025-04-20"},
    ),
    "codex": (
        "https://chatgpt.com/backend-api/wham/usage",
        {"OpenAI-Beta": "codex-1", "Originator": "Codex Desktop", "Content-Type": "application/json"},
    ),
}


def cpa(path, body=None):
    request = urllib.request.Request(
        CPA + path,
        data=json.dumps(body).encode() if body else None,
        headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.load(response)


def accounts():
    return [
        {
            "id": a.get("id"),
            "auth_index": a.get("auth_index"),
            "provider": a["provider"],
            "disabled": a.get("disabled", False),
            "id_token": {"chatgpt_account_id": (a.get("id_token") or {}).get("chatgpt_account_id")},
        }
        for a in cpa("auth-files")["files"]
        if a.get("provider") in USAGE
    ]


def usage(auth_index):
    account = next((a for a in accounts() if a["auth_index"] == auth_index), None)
    if account is None:
        return None
    url, extra = USAGE[account["provider"]]
    header = {"Authorization": "Bearer $TOKEN$", **extra}
    if account["provider"] == "codex" and account["id_token"]["chatgpt_account_id"]:
        header["Chatgpt-Account-Id"] = account["id_token"]["chatgpt_account_id"]
    result = cpa("api-call", {"auth_index": auth_index, "method": "GET", "url": url, "header": header})
    return {"status_code": result["status_code"], "body": result["body"]}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/v0/management/auth-files":
            return self.send_error(404)
        self.reply(lambda: {"files": accounts()})

    def do_POST(self):
        if self.path != "/v0/management/api-call":
            return self.send_error(404)
        body = json.loads(self.rfile.read(int(self.headers.get("Content-Length") or 0)) or b"{}")
        self.reply(lambda: usage(body.get("auth_index")))

    def reply(self, answer):
        try:
            result = answer()
        except Exception:
            return self.send_error(502)
        if result is None:
            return self.send_error(404)
        data = json.dumps(result).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


ThreadingHTTPServer(("127.0.0.1", 8322), Handler).serve_forever()
