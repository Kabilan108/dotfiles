"""Dummy OpenAI-compatible upstream: lists one model and streams four chunks one second apart."""

import json
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any

TICKS = 4


def chunk(model: str, delta: dict[str, Any], finish_reason: str | None) -> dict[str, Any]:
    return {
        "id": "chatcmpl-dummy",
        "object": "chat.completion.chunk",
        "created": int(time.time()),
        "model": model,
        "choices": [{"index": 0, "delta": delta, "finish_reason": finish_reason}],
    }


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"

    def log_message(self, format: str, *args: object) -> None:
        sys.stderr.write("upstream: " + format % args + "\n")

    def do_GET(self) -> None:
        body = json.dumps({"object": "list", "data": [{"id": "up", "object": "model"}]}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self) -> None:
        length = int(self.headers.get("Content-Length", "0"))
        request: dict[str, Any] = json.loads(self.rfile.read(length) or b"{}")
        model = str(request.get("model", "up"))
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        for index in range(TICKS):
            event = chunk(model, {"role": "assistant", "content": f"tick{index} "}, None)
            self.wfile.write(f"data: {json.dumps(event)}\n\n".encode())
            self.wfile.flush()
            time.sleep(1)
        final = chunk(model, {}, "stop")
        final["usage"] = {"prompt_tokens": 1, "completion_tokens": TICKS, "total_tokens": TICKS + 1}
        self.wfile.write(f"data: {json.dumps(final)}\n\ndata: [DONE]\n\n".encode())
        self.wfile.flush()


def main() -> None:
    ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()


if __name__ == "__main__":
    main()
