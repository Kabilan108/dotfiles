#!/usr/bin/env python3
"""Fake Dictator OSD socket: idle snapshot, then recording after a nudge file appears."""
from __future__ import annotations

import os
import socket
import sys
import time

path, nudge = sys.argv[1], sys.argv[2]
try:
    os.unlink(path)
except FileNotFoundError:
    pass
server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
server.bind(path)
server.listen(4)
connection, _ = server.accept()
connection.sendall(b'{"type":"state","value":"idle"}\n')
deadline = time.time() + 20
while time.time() < deadline and not os.path.exists(nudge):
    time.sleep(0.05)
connection.sendall(b'{"type":"state","value":"recording","recording_duration_ms":1200}\n')
connection.sendall(b'{"type":"meter","rms":0.05,"peak":0.4}\n')
time.sleep(1.0)
connection.sendall(b'{"type":"state","value":"idle"}\n')
time.sleep(20)
connection.close()
server.close()
