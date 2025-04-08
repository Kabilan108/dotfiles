import json
import os
import sys
import traceback
from http.server import BaseHTTPRequestHandler, HTTPServer
from io import StringIO, TextIOWrapper
from typing import Optional

import rich
from rich.syntax import Syntax

# TODO: add a --log flag which would save the command outputs to a log file
# TODO: add support for using icat to display PIL Images and mpl plots

repl_scope = {}


def format_code(code: list[str]) -> list:
    cblk = (">> " + "\n   ".join(code)).strip()
    return Syntax(cblk, "python", theme="one-dark")


def validate_code_exc_data(post_data: str) -> tuple[list[str], Optional[str]]:
    try:
        raw_data = json.loads(post_data)
        code = raw_data.get("code", [])
        if not isinstance(code, list):
            raise ValueError("'code' must be a list of strings")
        return code, None

    except Exception as e:
        return [], f"Failed to parse request: {e}"


class RedirectStdout:
    def __init__(self, original_stdout: TextIOWrapper) -> None:
        self.sysout = original_stdout
        self.redirectout = StringIO()

    def write(self, text: str) -> None:
        self.sysout.write(text)
        self.sysout.flush()
        self.redirectout.write(text)

    def flush(self) -> None:
        self.sysout.flush()
        self.redirectout.flush()


class CodeExecutionHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.path == "/health":
            self.send_json_response(200, dict(status="alive"))

    def do_POST(self) -> None:
        if self.path == "/execute":
            self.execute_code()
        elif self.path == "/reset":
            self.reset_scope()
        else:
            self.send_response(404)
            self.end_headers()

    def execute_code(self) -> None:
        global repl_scope

        content_length = int(self.headers["Content-Length"])
        post_data = self.rfile.read(content_length)
        code, error = validate_code_exc_data(post_data.decode("utf-8"))
        if error is not None:
            self.send_json_response(400, dict(error=error))
            return

        rich.print("\n", format_code(code), "\n", end="")

        stdout = RedirectStdout(sys.stdout)
        sys.stdout = stdout

        try:
            exec("\n".join(code), repl_scope)
            output = stdout.redirectout.getvalue()
            result = dict(output=output, error=None)
        except Exception:
            error = traceback.format_exc()
            rich.print("[red]", error, sep="")
            result = dict(output=None, error=error)
        finally:
            sys.stdout = stdout.sysout

        self.send_json_response(200, result)

    def reset_scope(self) -> None:
        global repl_scope
        repl_scope = {}
        rich.print("[bold yellow]Cleared REPL scope\n")
        self.send_json_response(200, dict(status="ok"))

    def log_message(self, format, *args):
        pass

    def send_json_response(self, status: int, resp_data: dict) -> None:
        self.send_response(status)
        self.send_header("Content-type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(resp_data).encode("utf-8"))


def get_address(default_port: int = 5000) -> tuple[str, int]:
    return "localhost", int(os.environ.get("PYREPL_PORT", default_port))


def run_server():
    addr = get_address()
    httpd = HTTPServer(addr, CodeExecutionHandler)
    rich.print(f"[bold yellow]Server running on http://{addr[0]}:{addr[1]}")
    httpd.serve_forever()


if __name__ == "__main__":
    try:
        run_server()
    except KeyboardInterrupt as e:
        rich.print("[bold yellow] exiting...")
    except OSError as e:
        rich.print(f"[red]Error starting pyrepl: {e}")
    except Exception as e:
        rich.print(f"[red]Unexpected error: {e}")
