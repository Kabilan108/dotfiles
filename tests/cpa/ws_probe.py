"""One Codex-style Responses websocket turn: upgrade, response.create, stream to response.completed.

usage: ws_probe.py <ws-url> <inference-key> <model>
"""

import json
import sys
import time
from typing import Any

from websockets.sync.client import connect


def main() -> int:
    url, key, model = sys.argv[1], sys.argv[2], sys.argv[3]
    headers = {
        "Authorization": f"Bearer {key}",
        "OpenAI-Beta": "responses_websockets=2026-02-06",
    }
    start = time.monotonic()
    deltas: list[float] = []
    completed = False
    with connect(url, additional_headers=headers, compression="deflate", open_timeout=10) as ws:
        response = ws.response
        if response is not None:
            print(f"upgrade status={response.status_code} extensions={response.headers.get('Sec-WebSocket-Extensions')}")
        create = {
            "type": "response.create",
            "model": model,
            "input": [{"type": "message", "role": "user", "content": [{"type": "input_text", "text": "hi"}]}],
        }
        ws.send(json.dumps(create))
        while time.monotonic() - start < 30:
            event: dict[str, Any] = json.loads(ws.recv(timeout=20))
            kind = event.get("type", "")
            elapsed = round(time.monotonic() - start, 2)
            if kind == "response.output_text.delta":
                deltas.append(elapsed)
                print(f"{elapsed:6.2f}s delta {event.get('delta')!r}")
            elif kind in ("response.completed", "error", "response.failed"):
                print(f"{elapsed:6.2f}s {kind} {json.dumps(event)[:160]}")
                completed = kind == "response.completed"
                break
    spread = deltas[-1] - deltas[0] if len(deltas) > 1 else 0.0
    print(f"deltas={len(deltas)} spread={spread:.2f}s completed={completed}")
    return 0 if completed and len(deltas) >= 4 and spread >= 2.5 else 1


if __name__ == "__main__":
    sys.exit(main())
