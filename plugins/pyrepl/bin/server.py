import json
import os
import sys
import textwrap
import traceback
from http.server import BaseHTTPRequestHandler, HTTPServer
from typing import Optional

import rich
from IPython.terminal.embed import InteractiveShellEmbed
from IPython.utils.capture import capture_output
from traitlets.config import Config
from rich.syntax import Syntax

ipshell = None


# TODO: add a --log flag which would save the command outputs to a log file


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


class CodeExecutionHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.path == "/health":
            self.send_json_response(200, dict(status="alive"))
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self) -> None:
        if self.path == "/execute":
            self.execute_code()
        elif self.path == "/reset":
            self.reset_scope()
        else:
            self.send_response(404)
            self.end_headers()

    def execute_code(self) -> None:
        global ipshell
        if ipshell is None:
            self.send_json_response(500, dict(error="IPython shell not initialized"))
            return

        content_length = int(self.headers["Content-Length"])
        post_data = self.rfile.read(content_length)
        code, error = validate_code_exc_data(post_data.decode("utf-8"))
        if error is not None:
            self.send_json_response(400, dict(error=error))
            return

        rich.print("\n", format_code(code), "\n", end="")

        # Execute code within the IPython shell and capture its stdout/stderr
        # any icat output will go directly to the server's terminal
        output = None
        error_output = None
        try:
            # Dedent the code before running
            code_str = textwrap.dedent("\n".join(code))

            # Use IPython's capture_output context manager
            with capture_output() as captured:
                # Run the cell. store_history=False avoids polluting history
                # with potentially large multi-line blocks sent from vim
                exec_result = ipshell.run_cell(
                    code_str, store_history=False, silent=False
                )

            output = captured.stdout
            error_output = captured.stderr

            # Check for execution errors reported by IPython
            if exec_result.error_before_exec:
                # Error during IPython's preprocessing
                error_output = (
                    error_output or ""
                ) + f"Error before execution: {exec_result.error_before_exec}"
            elif exec_result.error_in_exec:
                # Error during code execution (exception)
                # IPython formats the traceback nicely
                # We captured stderr, which might contain the traceback
                # If not, format it from the result
                if not error_output:
                    error_output = "".join(
                        traceback.format_exception(
                            exec_result.error_in_exec.__class__,
                            exec_result.error_in_exec,
                            exec_result.error_in_exec.__traceback__,
                        )
                    )

            if error_output:
                rich.print("[red]", error_output, sep="", end="")
                result = dict(
                    output=output or "", error=error_output
                )  # Send stdout even if error
            else:
                # Print captured stdout to the server terminal as well
                if output:
                    sys.stdout.write(output)
                    sys.stdout.flush()
                result = dict(output=output, error=None)

        except Exception as e:
            # Catch unexpected errors in the handler itself
            error_output = traceback.format_exc()
            rich.print("[red]", error_output, sep="")
            result = dict(output=output, error=error_output)  # Send any captured output

        self.send_json_response(200, result)

    def reset_scope(self) -> None:
        global ipshell
        if ipshell:
            ipshell.reset(new_session=True)  # Clears namespace and history
            rich.print("[bold yellow]Cleared REPL scope (IPython reset)\n")
            self.send_json_response(200, dict(status="ok"))
        else:
            self.send_json_response(500, dict(error="IPython shell not initialized"))

    def log_message(self, format, *args):
        # Keep server quiet by default
        pass

    def send_json_response(self, status: int, resp_data: dict) -> None:
        self.send_response(status)
        self.send_header("Content-type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(resp_data).encode("utf-8"))


def get_address(default_port: int = 5000) -> tuple[str, int]:
    """Read port from environment variable set by bin/pyrepl"""
    port = int(os.environ.get("PYREPL_PORT", default_port))
    return "localhost", port


import foo


def run_server():
    global ipshell
    addr = get_address()

    try:
        # Initialize the embedded IPython shell
        # Configure it to be quiet, not exit on failure, etc.
        config = Config()
        ipshell = InteractiveShellEmbed(config=config, banner1="", exit_msg="")

        rich.print("[cyan]Initializing IPython & loading default extensions...")
        ipshell.run_cell("%load_ext autoreload", store_history=False, silent=True)
        ipshell.run_cell("%autoreload 2", store_history=False, silent=True)

        rich.print(f"[bold yellow]Server running on http://{addr[0]}:{addr[1]}")

        httpd = HTTPServer(addr, CodeExecutionHandler)
        httpd.serve_forever()

    except KeyboardInterrupt:
        rich.print("\n[bold yellow] exiting...")
    except OSError as e:
        rich.print(f"[red]Error starting pyrepl: {e}")
        if "Address already in use" in str(e):
            rich.print(f"[yellow]Is another pyrepl server running on port {addr[1]}?")
    except Exception as e:
        rich.print(f"[red]Unexpected error: {e}")
        traceback.print_exc()


if __name__ == "__main__":
    run_server()
