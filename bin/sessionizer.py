#!/usr/bin/env -S uv --quiet run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///

from __future__ import annotations

import argparse
import base64
import concurrent.futures
import contextlib
import fcntl
import hashlib
import json
import os
import re
import shlex
import shutil
import socket
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Literal, NoReturn

VERSION = "0.4.0"

CONFIG_PATH = Path(
    os.environ.get(
        "SESSIONIZER_CONFIG",
        Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
        / "sessionizer"
        / "config.json",
    )
)
CACHE_DIR = (
    Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "sessionizer"
)
REMOTE_CACHE_DIR = CACHE_DIR / "remotes"
FLEET_HOSTS_PATH = (
    Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "fleet" / "hosts"
)
SCRIPT_PATH = Path(__file__).resolve()

CandidateKind = Literal["local", "remote", "directory"]


class SessionizerError(RuntimeError):
    pass


@dataclass(frozen=True)
class Config:
    search_paths: tuple[str, ...]
    max_depth: int
    ignore: tuple[str, ...]
    session_commands: tuple[str, ...]
    remote_hosts: tuple[str, ...]


@dataclass(frozen=True)
class FleetHost:
    name: str
    color: str
    address: str


@dataclass(frozen=True)
class Candidate:
    identity: str
    kind: CandidateKind
    name: str
    target: str
    detail: str
    host: str = ""
    color: str = ""

    def token(self) -> str:
        payload = json.dumps(
            {
                "identity": self.identity,
                "kind": self.kind,
                "name": self.name,
                "target": self.target,
                "detail": self.detail,
                "host": self.host,
                "color": self.color,
            },
            separators=(",", ":"),
        ).encode()
        return base64.urlsafe_b64encode(payload).decode().rstrip("=")

    @classmethod
    def from_token(cls, token: str) -> Candidate:
        padding = "=" * (-len(token) % 4)
        try:
            raw = json.loads(base64.urlsafe_b64decode(token + padding))
            return cls(
                identity=str(raw["identity"]),
                kind=raw["kind"],
                name=str(raw["name"]),
                target=str(raw["target"]),
                detail=str(raw["detail"]),
                host=str(raw.get("host", "")),
                color=str(raw.get("color", "")),
            )
        except (KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
            raise SessionizerError("invalid picker row") from exc


DEFAULT_CONFIG = Config(
    search_paths=("~/", "~/repos", "~/gists"),
    max_depth=1,
    ignore=("node_modules", ".git", "target"),
    session_commands=("claude", "codex", "opencode"),
    remote_hosts=("sietch",),
)


def load_config() -> Config:
    if not CONFIG_PATH.exists():
        return DEFAULT_CONFIG

    try:
        raw = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
        search_paths = tuple(str(value) for value in raw["search_paths"])
        max_depth = int(raw.get("max_depth", 1))
        ignore = tuple(str(value) for value in raw.get("ignore", []))
        session_commands = tuple(str(value) for value in raw["session_commands"])
        remote_hosts = tuple(str(value) for value in raw.get("remote_hosts", []))
    except (KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
        raise SessionizerError(
            f"invalid configuration in {CONFIG_PATH}: {exc}"
        ) from exc

    if max_depth < 0:
        raise SessionizerError("max_depth must be non-negative")
    return Config(search_paths, max_depth, ignore, session_commands, remote_hosts)


def write_default_config() -> None:
    if CONFIG_PATH.exists():
        raise SessionizerError(f"configuration already exists: {CONFIG_PATH}")
    CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "search_paths": list(DEFAULT_CONFIG.search_paths),
        "max_depth": DEFAULT_CONFIG.max_depth,
        "ignore": list(DEFAULT_CONFIG.ignore),
        "session_commands": list(DEFAULT_CONFIG.session_commands),
        "remote_hosts": list(DEFAULT_CONFIG.remote_hosts),
    }
    CONFIG_PATH.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {CONFIG_PATH}")


def run(
    command: list[str],
    *,
    check: bool = True,
    timeout: float | None = 10,
    env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    try:
        result = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
            env=env,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise SessionizerError(f"failed to run {shlex.join(command)}: {exc}") from exc
    if check and result.returncode != 0:
        message = result.stderr.strip() or result.stdout.strip() or "command failed"
        raise SessionizerError(f"{shlex.join(command)}: {message}")
    return result


def tmux(*args: str, check: bool = True) -> str:
    return run(["tmux", *args], check=check).stdout.rstrip("\n")


def require_commands(*commands: str) -> None:
    missing = [command for command in commands if shutil.which(command) is None]
    if missing:
        raise SessionizerError("missing required commands: " + ", ".join(missing))


def current_session_id() -> str:
    if not os.environ.get("TMUX"):
        return ""
    return tmux("display-message", "-p", "#{session_id}", check=False)


def current_client_name() -> str:
    if not os.environ.get("TMUX"):
        return ""
    return tmux("display-message", "-p", "#{client_name}", check=False)


def fleet_hosts(allowed_hosts: tuple[str, ...] | None = None) -> list[FleetHost]:
    key_path = Path.home() / ".ssh" / f"agent-{socket.gethostname()}"
    if not FLEET_HOSTS_PATH.exists() or not key_path.exists():
        return []

    result: list[FleetHost] = []
    for line in FLEET_HOSTS_PATH.read_text(encoding="utf-8").splitlines():
        fields = line.split("\t")
        if len(fields) != 3 or not re.fullmatch(r"[A-Za-z0-9_-]+", fields[0]):
            continue
        if allowed_hosts is not None and fields[0] not in allowed_hosts:
            continue
        result.append(FleetHost(fields[0], fields[1], fields[2]))
    return result


def colorize(text: str, color: str) -> str:
    if not re.fullmatch(r"#[0-9A-Fa-f]{6}", color):
        return text
    components = [int(color[index : index + 2], 16) for index in (1, 3, 5)]
    return f"\033[38;2;{components[0]};{components[1]};{components[2]}m{text}\033[0m"


def local_candidates(origin_session: str = "") -> list[Candidate]:
    listing = tmux(
        "list-sessions",
        "-F",
        "#{session_id}\t#{session_activity}\t#{session_name}\t#{session_windows}\t#{session_attached}",
        check=False,
    )
    local_color = os.environ.get("FLEET_HOST_HEX", "")
    host = socket.gethostname()
    candidates: list[tuple[int, Candidate]] = []
    for line in listing.splitlines():
        fields = line.split("\t", 4)
        if len(fields) != 5:
            continue
        session_id, activity, name, windows, attached = fields
        detail = f"{windows} window{'s' if windows != '1' else ''}"
        if session_id == origin_session:
            detail += " (origin)"
        elif attached != "0":
            detail += " (attached)"
        candidate = Candidate(
            identity=f"local:{session_id}",
            kind="local",
            name=name,
            target=session_id,
            detail=detail,
            host=host,
            color=local_color,
        )
        with contextlib.suppress(ValueError):
            candidates.append((int(activity), candidate))
    candidates.sort(key=lambda item: (-item[0], item[1].name.casefold()))
    return [candidate for _, candidate in candidates]


def remote_cache_path(host: FleetHost) -> Path:
    return REMOTE_CACHE_DIR / f"{host.name}.json"


def read_remote_cache(host: FleetHost) -> dict[str, Any]:
    path = remote_cache_path(host)
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(raw.get("sessions"), list):
            raise TypeError("sessions is not a list")
        return raw
    except (OSError, TypeError, ValueError, json.JSONDecodeError):
        return {"status": "connecting", "sessions": []}


def write_remote_cache(host: FleetHost, data: dict[str, Any]) -> None:
    REMOTE_CACHE_DIR.mkdir(parents=True, exist_ok=True)
    path = remote_cache_path(host)
    temporary = path.with_suffix(f".{os.getpid()}.tmp")
    temporary.write_text(json.dumps(data), encoding="utf-8")
    temporary.replace(path)


def refresh_remote_host(host: FleetHost) -> None:
    REMOTE_CACHE_DIR.mkdir(parents=True, exist_ok=True)
    lock_path = REMOTE_CACHE_DIR / f"{host.name}.lock"
    with lock_path.open("w", encoding="utf-8") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return

        previous = read_remote_cache(host)
        try:
            result = run(
                [
                    "ssh",
                    "-o",
                    "BatchMode=yes",
                    "-o",
                    "ConnectTimeout=2",
                    f"{host.name}-agent",
                    "tmux list-sessions -F '#{session_id}\t#{session_name}\t#{session_windows}' 2>/dev/null",
                ],
                check=False,
                timeout=5,
            )
        except SessionizerError:
            write_remote_cache(
                host,
                {"status": "offline", "sessions": previous.get("sessions", [])},
            )
            return
        sessions: list[dict[str, str]] = []
        if result.returncode == 0:
            for line in result.stdout.splitlines():
                fields = line.split("\t", 2)
                if len(fields) != 3:
                    continue
                session_id, name, windows = fields
                if re.fullmatch(r"\$\d+", session_id):
                    sessions.append(
                        {"id": session_id, "name": name, "windows": windows}
                    )
            data = {"status": "online", "sessions": sessions}
        elif result.returncode == 1 and not result.stderr.strip():
            data = {"status": "online", "sessions": []}
        else:
            data = {
                "status": "offline",
                "sessions": previous.get("sessions", []),
            }
        write_remote_cache(host, data)


def refresh_remote_hosts(allowed_hosts: tuple[str, ...]) -> None:
    hosts = fleet_hosts(allowed_hosts)
    if not hosts:
        return
    with concurrent.futures.ThreadPoolExecutor(max_workers=min(4, len(hosts))) as pool:
        list(pool.map(refresh_remote_host, hosts))


def remote_candidates(allowed_hosts: tuple[str, ...]) -> list[Candidate]:
    result: list[Candidate] = []
    for host in fleet_hosts(allowed_hosts):
        cached = read_remote_cache(host)
        status = str(cached.get("status", "connecting"))
        sessions = cached.get("sessions", [])
        for raw in sessions:
            try:
                session_id = str(raw["id"])
                name = str(raw["name"])
                windows = str(raw["windows"])
            except (KeyError, TypeError):
                continue
            detail = f"{windows} window{'s' if windows != '1' else ''}"
            if status != "online":
                detail += f" ({status} cache)"
            result.append(
                Candidate(
                    identity=f"remote:{host.name}:{session_id}",
                    kind="remote",
                    name=name,
                    target=session_id,
                    detail=detail,
                    host=host.name,
                    color=host.color,
                )
            )
    return result


def parse_search_path(value: str, default_depth: int) -> tuple[Path, int]:
    match = re.fullmatch(r"(.+):([0-9]+)", value)
    if match:
        return Path(match.group(1)).expanduser(), int(match.group(2))
    return Path(value).expanduser(), default_depth


def directory_candidates(config: Config, overrides: list[str]) -> list[Candidate]:
    fd = shutil.which("fd") or shutil.which("fdfind")
    if fd is None:
        raise SessionizerError("missing required command: fd")

    roots = overrides or list(config.search_paths)
    seen: set[Path] = set()
    result: list[Candidate] = []
    for value in roots:
        root, depth = parse_search_path(value, config.max_depth)
        if not root.is_dir():
            continue
        command = [fd, "-L", "-I", "-t", "d", "-d", str(depth)]
        for pattern in config.ignore:
            command.extend(["-E", pattern])
        command.extend([".", str(root)])
        listing = run(command, check=False).stdout
        for line in listing.splitlines():
            path = Path(line).expanduser().resolve()
            if path in seen or not path.is_dir():
                continue
            seen.add(path)
            result.append(
                Candidate(
                    identity="directory:" + str(path),
                    kind="directory",
                    name=path.name or str(path),
                    target=str(path),
                    detail=str(path),
                )
            )
    return result


def all_candidates(
    config: Config, overrides: list[str], origin_session: str = ""
) -> list[Candidate]:
    return [
        *local_candidates(origin_session),
        *remote_candidates(config.remote_hosts),
        *directory_candidates(config, overrides),
    ]


def render_row(candidate: Candidate) -> str:
    if candidate.kind == "directory":
        badge = colorize("directory", os.environ.get("FLEET_HOST_HEX", ""))
    else:
        badge = colorize(candidate.host, candidate.color)
    name = candidate.name.replace("\t", " ").replace("\n", " ")
    detail = candidate.detail.replace("\t", " ").replace("\n", " ")
    return f"{candidate.identity}\t{candidate.token()}\t{name}\t{detail}\t{badge}"


def render_rows(candidates: list[Candidate]) -> str:
    if not candidates:
        return ""
    return "\n".join(render_row(candidate) for candidate in candidates) + "\n"


SWITCH_TYPING_KEYS = [
    *[chr(value) for value in range(ord("a"), ord("z") + 1)],
    *[chr(value) for value in range(ord("A"), ord("Z") + 1)],
    *[str(value) for value in range(10)],
    "-",
    "_",
    ".",
    "space",
]
SWITCH_EDIT_KEYS = ["backspace", "ctrl-h", "delete"]
SWITCH_NORMAL_KEYS = {
    "j": "down",
    "k": "up",
    "g": "first",
    "G": "last",
    "ctrl-d": "half-page-down",
    "ctrl-u": "half-page-up",
    "q": "abort",
    "i": "enter-insert",
    "/": "enter-insert",
}


def picker(
    config: Config, overrides: list[str], origin_session: str = ""
) -> Candidate | None:
    require_commands("fzf", "tmux", "ssh")
    candidates = all_candidates(config, overrides, origin_session)
    rows = render_rows(candidates)
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    descriptor, snapshot_name = tempfile.mkstemp(
        prefix="picker-", suffix=".txt", dir=CACHE_DIR
    )
    os.close(descriptor)
    snapshot = Path(snapshot_name)
    snapshot.write_text(rows, encoding="utf-8")

    refresh_command = shlex.join(
        [
            str(SCRIPT_PATH),
            "--refresh-picker",
            str(snapshot),
            origin_session,
            json.dumps(overrides, separators=(",", ":")),
        ]
    )
    modal_keys = sorted(set(SWITCH_TYPING_KEYS) | set(SWITCH_NORMAL_KEYS))
    edit_keys = ",".join(SWITCH_EDIT_KEYS)
    insert_action = (
        "change-prompt(insert> )+unbind("
        + ",".join(modal_keys)
        + ")+rebind("
        + edit_keys
        + ")"
    )
    normal_action = (
        "change-prompt(normal> )+rebind("
        + ",".join(modal_keys)
        + ")+unbind("
        + edit_keys
        + ")"
    )
    bindings = ["start:unbind(" + edit_keys + ")"]
    bindings.extend(
        key + ":ignore" for key in SWITCH_TYPING_KEYS if key not in SWITCH_NORMAL_KEYS
    )
    bindings.extend(
        key + ":" + (insert_action if action == "enter-insert" else action)
        for key, action in SWITCH_NORMAL_KEYS.items()
    )
    bindings.append(
        'esc:transform:[ "$FZF_PROMPT" = "insert> " ] && echo '
        + shlex.quote(normal_action)
        + " || echo abort"
    )
    bindings.append("load:bg-transform(" + refresh_command + ")+unbind(load)")

    command = [
        "fzf",
        "--ansi",
        "--reverse",
        "--no-multi",
        "--cycle",
        "--info=inline",
        "--print-query",
        "--prompt",
        "normal> ",
        "--delimiter",
        "\t",
        "--with-nth",
        "3,4,5",
        "--nth",
        "3,4,5",
        "--track",
        "--id-nth",
        "1",
        "--preview",
        shlex.join([str(SCRIPT_PATH), "--preview-token", "{2}"]),
        "--preview-window",
        "right,45%,border-left",
    ]
    for binding in bindings:
        command.extend(["--bind", binding])

    try:
        result = subprocess.run(
            command,
            input=rows,
            capture_output=True,
            text=True,
            check=False,
            env=dict(os.environ, SHELL="/bin/sh"),
        )
    finally:
        snapshot.unlink(missing_ok=True)

    output = result.stdout.splitlines()
    if result.returncode != 0 or len(output) < 2:
        return None
    fields = output[1].split("\t", 2)
    if len(fields) < 2:
        raise SessionizerError("invalid picker selection")
    token = fields[1]
    return Candidate.from_token(token)


def refresh_picker(
    snapshot_value: str, origin_session: str, overrides_value: str
) -> None:
    snapshot = Path(snapshot_value)
    config = load_config()
    try:
        overrides = [str(value) for value in json.loads(overrides_value)]
    except (TypeError, ValueError, json.JSONDecodeError) as exc:
        raise SessionizerError("invalid picker search-path state") from exc
    refresh_remote_hosts(config.remote_hosts)
    rows = render_rows(all_candidates(config, overrides, origin_session))
    try:
        previous = snapshot.read_text(encoding="utf-8")
    except OSError:
        return
    if rows == previous:
        return
    temporary = snapshot.with_suffix(f".{os.getpid()}.tmp")
    temporary.write_text(rows, encoding="utf-8")
    temporary.replace(snapshot)
    print("reload(cat " + shlex.quote(str(snapshot)) + ")")


def preview(candidate: Candidate) -> None:
    if candidate.kind == "local":
        output = tmux(
            "list-windows",
            "-t",
            candidate.target,
            "-F",
            "#{window_index}: #{window_name} (#{pane_current_command})",
            check=False,
        )
        print(output)
        return
    if candidate.kind == "remote":
        print(f"remote tmux session '{candidate.name}' on {candidate.host}")
        print("Enter: replace this client with the remote tmux client")
        print("M-s: return to the origin fleet picker")
        print("prefix+d: return to the origin local session")
        return

    path = Path(candidate.target)
    try:
        entries = sorted(path.iterdir(), key=lambda entry: entry.name.casefold())[:30]
    except OSError:
        return
    for entry in entries:
        suffix = "/" if entry.is_dir() else ""
        print(entry.name + suffix)


def marker_directory() -> Path:
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
    path = runtime / "sessionizer" / "managed-clients"
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    if path.is_symlink() or path.stat().st_uid != os.getuid():
        raise SessionizerError(f"unsafe managed-client directory: {path}")
    path.chmod(0o700)
    return path


def marker_path(tty_path: str) -> Path:
    digest = hashlib.sha256(tty_path.encode()).hexdigest()[:20]
    return marker_directory() / f"{digest}.json"


def process_owns_tty(pid: int, tty_path: str) -> bool:
    try:
        os.kill(pid, 0)
        return (Path("/proc") / str(pid) / "fd" / "0").resolve() == Path(
            tty_path
        ).resolve()
    except (OSError, RuntimeError):
        return False


def is_managed_client(tty_path: str) -> bool:
    path = marker_path(tty_path)
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
        managed = raw.get("tty") == tty_path and process_owns_tty(
            int(raw["pid"]), tty_path
        )
    except (KeyError, OSError, TypeError, ValueError, json.JSONDecodeError):
        managed = False
    if not managed:
        path.unlink(missing_ok=True)
    return managed


def remote_attach(target: str) -> int:
    try:
        tty_path = os.ttyname(0)
    except OSError as exc:
        raise SessionizerError("remote attach requires a terminal") from exc

    path = marker_path(tty_path)
    temporary = path.with_suffix(f".{os.getpid()}.tmp")
    temporary.write_text(
        json.dumps({"pid": os.getpid(), "tty": tty_path}), encoding="utf-8"
    )
    temporary.replace(path)
    try:
        return subprocess.run(
            ["tmux", "attach-session", "-t", target], check=False
        ).returncode
    finally:
        path.unlink(missing_ok=True)


def remote_command(target: str) -> str:
    executable = '"$HOME/bin/sessionizer"'
    return f"exec {executable} --remote-attach {shlex.quote(target)}"


def attach_remote(host: str, target: str) -> int:
    try:
        return subprocess.run(
            ["ssh", "-t", host, remote_command(target)], check=False
        ).returncode
    except OSError as exc:
        print(f"sessionizer: could not connect to {host}: {exc}", file=sys.stderr)
        return 255


def local_session_names() -> dict[str, str]:
    listing = tmux("list-sessions", "-F", "#{session_name}\t#{session_id}", check=False)
    result: dict[str, str] = {}
    for line in listing.splitlines():
        fields = line.split("\t", 1)
        if len(fields) == 2:
            result[fields[0]] = fields[1]
    return result


def session_name_for_directory(path: Path) -> str:
    base = re.sub(r"[:.]", "_", path.name or "shell")
    sessions = local_session_names()
    if base not in sessions:
        return base

    registered_path = tmux(
        "show-options",
        "-qv",
        "-t",
        sessions[base],
        "@sessionizer-path",
        check=False,
    )
    if not registered_path:
        return base
    with contextlib.suppress(OSError):
        if Path(registered_path).resolve() == path.resolve():
            return base

    parent = re.sub(r"[:.]", "_", path.parent.name)
    candidate = f"{parent}-{base}" if parent else base
    suffix = 2
    while candidate in sessions:
        candidate = f"{parent}-{base}-{suffix}" if parent else f"{base}-{suffix}"
        suffix += 1
    return candidate


def hydrate(session: str, path: Path) -> None:
    project_script = path / ".sessionizer"
    global_script = Path.home() / ".sessionizer"
    script = project_script if project_script.is_file() else global_script
    if script.is_file():
        tmux(
            "send-keys",
            "-t",
            session,
            "source " + shlex.quote(str(script)),
            "Enter",
        )


def ensure_directory_session(path_value: str) -> str:
    path = Path(path_value).resolve()
    name = session_name_for_directory(path)
    sessions = local_session_names()
    if name not in sessions:
        tmux("new-session", "-d", "-s", name, "-c", str(path))
        tmux("set-option", "-t", name, "@sessionizer-path", str(path))
        hydrate(name, path)
    return local_session_names()[name]


def switch_local(candidate: Candidate) -> None:
    target = (
        ensure_directory_session(candidate.target)
        if candidate.kind == "directory"
        else candidate.target
    )
    if os.environ.get("TMUX"):
        client = current_client_name()
        args = ["switch-client"]
        if client:
            args.extend(["-c", client])
        tmux(*args, "-t", target)
        return
    exec_attach_local(target)


def exec_attach_local(target: str) -> NoReturn:
    environment = dict(os.environ)
    environment.pop("TMUX", None)
    environment.pop("TMUX_PANE", None)
    os.execvpe("tmux", ["tmux", "attach-session", "-t", target], environment)


def fallback_local_session(preferred: str) -> str:
    sessions = local_candidates(preferred)
    if any(candidate.target == preferred for candidate in sessions):
        return preferred
    if sessions:
        return sessions[0].target
    return tmux("new-session", "-d", "-s", "main", "-P", "-F", "#{session_id}")


def travel(origin_session: str, initial_host: str, initial_target: str) -> NoReturn:
    config = load_config()
    host = initial_host
    target = initial_target
    while True:
        status = attach_remote(host, target)
        if status != 42:
            exec_attach_local(fallback_local_session(origin_session))

        selected = picker(config, [], origin_session)
        if selected is None:
            continue
        if selected.kind == "remote":
            host = selected.host
            target = selected.target
            continue
        local_target = (
            ensure_directory_session(selected.target)
            if selected.kind == "directory"
            else selected.target
        )
        exec_attach_local(local_target)


def begin_travel(candidate: Candidate) -> None:
    origin_session = current_session_id()
    if not os.environ.get("TMUX"):
        travel(origin_session, candidate.host, candidate.target)

    command = shlex.join(
        [
            str(SCRIPT_PATH),
            "--travel",
            origin_session,
            candidate.host,
            candidate.target,
        ]
    )
    client = current_client_name()
    args = ["detach-client"]
    if client:
        args.extend(["-t", client])
    tmux(*args, "-E", command)


def handle_session_command(index: int, split: str | None, config: Config) -> None:
    if not os.environ.get("TMUX"):
        raise SessionizerError("session commands require a running tmux client")
    if index < 0 or index >= len(config.session_commands):
        raise SessionizerError(
            f"session command index must be between 0 and {len(config.session_commands) - 1}"
        )

    command = config.session_commands[index]
    session = tmux("display-message", "-p", "#{session_id}")
    if split is None:
        window_index = 10 + index
        target = f"{session}:{window_index}"
        exists = tmux(
            "list-windows", "-t", session, "-F", "#{window_index}", check=False
        ).splitlines()
        if str(window_index) not in exists:
            tmux("new-window", "-d", "-t", target, command)
        tmux("select-window", "-t", target)
        return

    key = f"{index}:{split}"
    listing = tmux(
        "list-panes",
        "-s",
        "-t",
        session,
        "-F",
        "#{pane_id}\t#{@sessionizer-command}",
        check=False,
    )
    for line in listing.splitlines():
        pane_id, _, pane_key = line.partition("\t")
        if pane_key == key:
            tmux("select-pane", "-t", pane_id)
            return

    current_path = tmux("display-message", "-p", "#{pane_current_path}")
    flag = "-h" if split == "vsplit" else "-v"
    pane_id = tmux(
        "split-window",
        flag,
        "-c",
        current_path,
        "-P",
        "-F",
        "#{pane_id}",
        command,
    )
    tmux("set-option", "-p", "-t", pane_id, "@sessionizer-command", key)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="sessionizer",
        description="Switch between local projects and tmux sessions across the fleet.",
    )
    parser.add_argument("search_paths", nargs="*")
    parser.add_argument("-v", "--version", action="store_true")
    parser.add_argument("--init", action="store_true")
    parser.add_argument("-s", "--session", type=int)
    split = parser.add_mutually_exclusive_group()
    split.add_argument("--vsplit", action="store_true")
    split.add_argument("--hsplit", action="store_true")
    parser.add_argument("--preview-token", help=argparse.SUPPRESS)
    parser.add_argument("--refresh-picker", nargs=3, help=argparse.SUPPRESS)
    parser.add_argument("--is-managed", help=argparse.SUPPRESS)
    parser.add_argument("--remote-attach", help=argparse.SUPPRESS)
    parser.add_argument("--travel", nargs=3, help=argparse.SUPPRESS)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    if args.version:
        print(f"sessionizer version {VERSION}")
        return 0
    if args.init:
        write_default_config()
        return 0
    if args.preview_token:
        preview(Candidate.from_token(args.preview_token))
        return 0
    if args.refresh_picker:
        refresh_picker(*args.refresh_picker)
        return 0
    if args.is_managed:
        return 0 if is_managed_client(args.is_managed) else 1
    if args.remote_attach:
        return remote_attach(args.remote_attach)
    if args.travel:
        travel(*args.travel)

    config = load_config()
    if (args.vsplit or args.hsplit) and args.session is None:
        raise SessionizerError("--vsplit and --hsplit require --session")
    if args.session is not None:
        split = "vsplit" if args.vsplit else "hsplit" if args.hsplit else None
        handle_session_command(args.session, split, config)
        return 0

    selected = picker(config, args.search_paths, current_session_id())
    if selected is None:
        return 0
    if selected.kind == "remote":
        begin_travel(selected)
    else:
        switch_local(selected)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except SessionizerError as exc:
        print(f"sessionizer: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
