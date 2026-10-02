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
while True:
    connection, _ = server.accept()
    time.sleep(0.05)
    connection.sendall(
        b'{"type":"state","value":"recording","recording_duration_ms":0}\n'
    )
    connection.sendall(b'{"type":"meter","rms":0.03,"peak":0.2}\n')
    # Hold the connection until the shell closes it. The harness controls
    # daemon death and restart independently of the client's retry timing.
    try:
        while connection.recv(1024):
            pass
    except ConnectionResetError:
        pass
    connection.close()
server.close()
