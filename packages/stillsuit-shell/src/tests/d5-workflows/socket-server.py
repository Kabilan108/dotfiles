#!/usr/bin/env python3
from __future__ import annotations

import os
import socket
import sys
import time

path = sys.argv[1]
try:
    os.unlink(path)
except FileNotFoundError:
    pass
server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
server.bind(path)
server.listen(4)
for _ in range(2):
    connection, _ = server.accept()
    time.sleep(0.05)
    connection.sendall(b'{"type":"state","value":"recording","recording_duration_ms":0}\n')
    connection.sendall(b'{"type":"meter","rms":0.03,"peak":0.2}\n')
    time.sleep(10)
    connection.close()
server.close()
