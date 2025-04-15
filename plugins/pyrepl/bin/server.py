import argparse
import datetime
import json
import os
import re
import sys
import textwrap
import threading
import traceback
from http.server import BaseHTTPRequestHandler, HTTPServer
from typing import Dict, List, Optional, Tuple

import rich
from IPython.terminal.embed import InteractiveShellEmbed
from IPython.utils.capture import capture_output
from rich.syntax import Syntax
from traitlets.config import Config

ipshell = None
log_file_path = None
ansi_regex = re.compile(r"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])")

is_executing = False
execution_lock = threading.Lock()


def strip_ansi_codes(text: str) -> str:
    """Removes ANSI escape codes from a string."""
    return ansi_regex.sub("", text) if text else ""


def format_code(code: List[str]) -> List:
    cblk = (">> " + "\n   ".join(code)).strip()
    return Syntax(cblk, "python", theme="one-dark")


def validate_code_exc_data(post_data: str) -> Tuple[List[str], Optional[str]]:
    try:
        raw_data = json.loads(post_data)
        code = raw_data.get("code", [])
        if not isinstance(code, list):
            raise ValueError("'code' must be a list of strings")
        return code, None
    except Exception as e:
        return [], f"Failed to parse request: {e}"


def write_to_log(code_lines: List[str], result: Dict) -> None:
    """Appends the code and result (with ANSI codes stripped) to the log file."""
    global log_file_path
    if not log_file_path:
        return

    try:
        code_str = "\n".join(code_lines)
        output_str = strip_ansi_codes(result.get("output") or "")
        error_str = strip_ansi_codes(result.get("error") or "")

        log_content = ""
        if output_str:
            log_content += output_str
        if error_str:
            if log_content:
                log_content += "\n"
            log_content += error_str

        with open(log_file_path, "a", encoding="utf-8") as f:
            f.write(
                "```python\n"
                f"{code_str}\n"
                "```\n\n"
                "<output>\n"
                f"{log_content.strip()}\n"
                "</output>\n\n"
            )

    except Exception as e:
        rich.print(f"[red]Error writing to log file {log_file_path}: {e}")


def _run_code_in_background(
    shell_instance: InteractiveShellEmbed, code_lines: List[str], code_str: str
) -> None:
    """Executes the code in IPython and handles output/errors."""
    global is_executing, execution_lock

    rich.print("\n", format_code(code_lines), "\n", end="")

    output = None
    error_output = None
    result = {}

    try:
        with capture_output() as captured:
            exec_result = shell_instance.run_cell(
                code_str, store_history=False, silent=False
            )

        output = captured.stdout
        error_output = captured.stderr

        if exec_result.error_before_exec:
            error_output = (
                error_output or ""
            ) + f"Error before execution: {exec_result.error_before_exec}"
        elif exec_result.error_in_exec:
            if not output and not error_output:
                error_output = "".join(
                    traceback.format_exception(
                        exec_result.error_in_exec.__class__,
                        exec_result.error_in_exec,
                        exec_result.error_in_exec.__traceback__,
                    )
                )

        if output:
            sys.stdout.write(output)
            sys.stdout.flush()
        if error_output:
            rich.print("[red]", error_output, sep="")

        result = dict(output=output or "", error=error_output or "")

    except Exception:
        error_output = traceback.format_exc()
        if output:
            sys.stdout.write(output)
            sys.stdout.flush()
        rich.print("[red]Error during background execution:", error_output, sep="")
        result = dict(output=output or "", error=error_output)

    finally:
        with execution_lock:
            is_executing = False
        write_to_log(code_lines, result)


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
            # Reset should ideally interrupt/clear execution state too,
            # but for now, we just reset IPython's scope.
            # A more robust reset might need to signal the execution thread.
            self.reset_scope()
        else:
            self.send_response(404)
            self.end_headers()

    def execute_code(self) -> None:
        global ipshell, is_executing, execution_lock
        if ipshell is None:
            self.send_json_response(500, dict(error="IPython shell not initialized"))
            return

        content_length = int(self.headers["Content-Length"])
        post_data = self.rfile.read(content_length)
        code, error = validate_code_exc_data(post_data.decode("utf-8"))
        if error is not None:
            self.send_json_response(400, dict(error=error))
            return

        with execution_lock:
            if is_executing:
                self.send_json_response(
                    409, {"error": "Server is busy executing previous code"}
                )
                return

            is_executing = True

        self.send_json_response(200, {"status": "Execution request accepted"})

        code_str = textwrap.dedent("\n".join(code))
        thread = threading.Thread(
            target=_run_code_in_background, args=(ipshell, code, code_str), daemon=True
        )
        thread.start()

    def reset_scope(self) -> None:
        global ipshell, is_executing, execution_lock
        if ipshell:
            ipshell.reset(new_session=True)
            reset_msg = "Cleared REPL scope (IPython reset)"
            rich.print(f"[bold yellow]{reset_msg}\n")
            with execution_lock:
                is_executing = False
            self.send_json_response(200, dict(status="ok"))
            write_to_log(["# Reset Command Received"], {"output": reset_msg})
        else:
            self.send_json_response(500, dict(error="IPython shell not initialized"))

    def log_message(self, format, *args):
        pass

    def send_json_response(self, status: int, resp_data: Dict) -> None:
        self.send_response(status)
        self.send_header("Content-type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(resp_data).encode("utf-8"))


def get_address(default_port: int = 5000) -> Tuple[str, int]:
    port = int(os.environ.get("PYREPL_PORT", default_port))
    return "localhost", port


def setup_logging(log_dir: str, log_name: Optional[str]) -> Optional[str]:
    """Creates log directory and constructs the log file path."""
    global log_file_path
    if not log_dir:
        return None

    try:
        target_dir = os.path.join(log_dir, ".pyrepl")
        os.makedirs(target_dir, exist_ok=True)

        filename = f"{datetime.datetime.now().strftime('%b%d%Y-%H%M%S')}"
        if log_name:
            safe_log_name = re.sub(r"[^\w\-]+", "_", log_name)
            filename += f"-{safe_log_name}"
        filename += ".md"

        log_file_path = os.path.join(target_dir, filename)
        rich.print(f"[blue]Logging enabled. Log file: {log_file_path}")
        with open(log_file_path, "a", encoding="utf-8") as f:
            f.write(f"# PyREPL Session Log: {datetime.datetime.now()}\n")
            f.write(f"# CWD: {log_dir}\n")
            if log_name:
                f.write(f"# Session Name: {log_name}\n")
            f.write("\n")
        return log_file_path
    except Exception as e:
        rich.print(f"[red]Failed to setup logging in {log_dir}: {e}")
        return None


def run_server(args):
    global ipshell, log_file_path
    addr = get_address()

    log_file_path = setup_logging(args.log_dir, args.log_name)

    try:
        config = Config()
        ipshell = InteractiveShellEmbed(config=config, banner1="", exit_msg="")

        rich.print("[blue]Initializing IPython & loading default extensions...")
        ipshell.run_cell("%load_ext autoreload", store_history=False, silent=True)
        ipshell.run_cell("%autoreload 2", store_history=False, silent=True)

        rich.print(f"[bold blue]Server running on http://{addr[0]}:{addr[1]}")

        httpd = HTTPServer(addr, CodeExecutionHandler)
        httpd.serve_forever()

    except KeyboardInterrupt:
        rich.print("\n[bold blue] exiting...")
    except OSError as e:
        rich.print(f"[red]Error starting pyrepl: {e}")
        if "Address already in use" in str(e):
            rich.print(f"[yellow]Is another pyrepl server running on port {addr[1]}?")
    except Exception as e:
        rich.print(f"[red]Unexpected error: {e}")
        traceback.print_exc()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="PyREPL Server")
    parser.add_argument(
        "--log-dir", help="Directory where .pyrepl logs should be stored."
    )
    parser.add_argument("--log-name", help="Optional name for the log session file.")
    cli_args, unknown = parser.parse_known_args()

    run_server(cli_args)
