import json
import os
import sys
import traceback
from http.server import BaseHTTPRequestHandler, HTTPServer
from io import StringIO, TextIOWrapper

repl_scope = {}


def validate_code_exc_data(post_data: str) -> dict:
    try:
        raw_data = json.loads(post_data)

        raw_code = raw_data.get("code", [])
        if not isinstance(raw_code, list):
            raise ValueError("'code' must be a list of strings")

        code = "\n".join(raw_code)
        reset = bool(raw_data.get("reset", False))
        return dict(code=code, reset=reset, error=None)

    except Exception as e:
        return dict(code=[], reset=False, error=f"Failed to parse request: {e}")


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
        global repl_scope

        content_length = int(self.headers["Content-Length"])
        post_data = self.rfile.read(content_length)
        data = validate_code_exc_data(post_data.decode("utf-8"))

        if data["error"] is not None:
            self.send_json_response(400, dict(error=data["error"]))
            return

        if data["reset"]:
            print("Clearing REPL scope")
            repl_scope = {}

        print(">> " + "\n   ".join(data["code"].splitlines()))

        stdout = RedirectStdout(sys.stdout)
        sys.stdout = stdout

        try:
            exec(data["code"], repl_scope)
            output = stdout.redirectout.getvalue()
            result = dict(output=output, error=None)
        except Exception:
            error = traceback.format_exc()
            print(error)
            result = dict(output=None, error=error)
        finally:
            sys.stdout = stdout.sysout

        self.send_json_response(200, result)

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
    print(f"Server running on http://{addr[0]}:{addr[1]}")
    httpd.serve_forever()


if __name__ == "__main__":
    run_server()
