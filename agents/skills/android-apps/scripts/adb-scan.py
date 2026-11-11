#!/usr/bin/env python3
"""Print the open TCP ports in 30000-49999 on HOST, skipping any ports given after it.

Wireless debugging's connect and pairing ports both land in this range, and mDNS
discovery does not reach the phone over the tailnet.
"""

import asyncio
import sys

PORTS = range(30000, 50000)


async def probe(host: str, port: int, limit: asyncio.Semaphore, found: list[int]) -> None:
    async with limit:
        try:
            _, writer = await asyncio.wait_for(asyncio.open_connection(host, port), 0.6)
        except (OSError, asyncio.TimeoutError):
            return
        found.append(port)
        writer.close()


async def scan(host: str, skip: set[int]) -> list[int]:
    limit = asyncio.Semaphore(400)
    found: list[int] = []
    await asyncio.gather(*(probe(host, p, limit, found) for p in PORTS if p not in skip))
    return sorted(found)


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit("usage: adb-scan.py HOST [SKIP_PORT...]")
    skip = {int(p) for p in sys.argv[2:]}
    print(" ".join(map(str, asyncio.run(scan(sys.argv[1], skip)))))


if __name__ == "__main__":
    main()
