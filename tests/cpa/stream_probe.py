"""Stream one chat turn and check the upstream's four ticks arrive spread out, not buffered.

usage: stream_probe.py <port> </v1/chat/completions|/v1/messages> <model> <inference-key>
"""

import http.client
import json
import sys
import time
from typing import Any


def request_for(path: str, model: str, key: str) -> tuple[dict[str, Any], dict[str, str]]:
    messages = [{"role": "user", "content": "hi"}]
    if path == "/v1/messages":
        body: dict[str, Any] = {"model": model, "max_tokens": 32, "stream": True, "messages": messages}
        headers = {"x-api-key": key, "anthropic-version": "2023-06-01", "Content-Type": "application/json"}
    else:
        body = {"model": model, "stream": True, "messages": messages}
        headers = {"Authorization": f"Bearer {key}", "Content-Type": "application/json"}
    return body, headers


def main() -> int:
    port, path, model, key = int(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4]
    body, headers = request_for(path, model, key)
    conn = http.client.HTTPConnection("127.0.0.1", port, timeout=30)
    start = time.monotonic()
    conn.request("POST", path, json.dumps(body), headers)
    response = conn.getresponse()
    print(f"status={response.status} content-type={response.getheader('Content-Type')}")
    arrivals: list[float] = []
    while line := response.readline():
        text = line.decode().strip()
        if "tick" in text:
            arrivals.append(round(time.monotonic() - start, 2))
            print(f"{arrivals[-1]:6.2f}s {text[:110]}")
    spread = arrivals[-1] - arrivals[0] if len(arrivals) > 1 else 0.0
    print(f"tick_events={len(arrivals)} spread={spread:.2f}s")
    return 0 if response.status == 200 and len(arrivals) >= 4 and spread >= 2.5 else 1


if __name__ == "__main__":
    sys.exit(main())
