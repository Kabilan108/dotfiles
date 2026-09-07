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

VERSION = "0.6.0"

MACHINE_COLUMN_WIDTH = 10
SESSION_COLUMN_WIDTH = 32
DIRECTORY_COLOR = "#6c7086"
AGENT_COLOR = "#a6e3a1"
AGENT_NAMES = ("opencode2", "opencode", "claude", "codex")
PANE_SEPARATOR = "\x1f"
PANE_FORMAT = PANE_SEPARATOR.join(
    (
        "#{window_index}",
        "#{window_name}",
        "#{window_active}",
        "#{pane_index}",
        "#{pane_active}",
        "#{pane_pid}",
        "#{pane_current_command}",
        "#{pane_current_path}",
        "#{pane_title}",
    )
)

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

CandidateKind = Literal["local", "remote", "directory", "remote-directory"]


class SessionizerError(RuntimeError):
    pass


@dataclass(frozen=True)
class Config:
    search_paths: tuple[str, ...]
    max_depth: int
    ignore: tuple[str, ...]
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


@dataclass(frozen=True)
class Pane:
    window_index: str
    window_name: str
    window_active: bool
    pane_index: str
    pane_active: bool
    pid: int
    command: str
    path: str
    title: str


DEFAULT_CONFIG = Config(
    search_paths=("~/", "~/repos", "~/gists"),
    max_depth=1,
    ignore=("node_modules", ".git", "target"),
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
        remote_hosts = tuple(str(value) for value in raw.get("remote_hosts", []))
    except (KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
        raise SessionizerError(
            f"invalid configuration in {CONFIG_PATH}: {exc}"
        ) from exc

    if max_depth < 0:
        raise SessionizerError("max_depth must be non-negative")
    return Config(search_paths, max_depth, ignore, remote_hosts)


def write_default_config() -> None:
    if CONFIG_PATH.exists():
        raise SessionizerError(f"configuration already exists: {CONFIG_PATH}")
    CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "search_paths": list(DEFAULT_CONFIG.search_paths),
        "max_depth": DEFAULT_CONFIG.max_depth,
        "ignore": list(DEFAULT_CONFIG.ignore),
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


def sanitize_field(value: str) -> str:
    return value.replace("\t", " ").replace("\n", " ")


def fit_column(value: str, width: int) -> str:
    value = sanitize_field(value)
    if len(value) > width:
        return value[: width - 1] + "…"
    return value.ljust(width)


def local_session_inventory() -> list[dict[str, str]]:
    listing = tmux(
        "list-sessions",
        "-F",
        PANE_SEPARATOR.join(
            (
                "#{session_id}",
                "#{session_activity}",
                "#{session_name}",
                "#{session_windows}",
                "#{session_attached}",
                "#{@sessionizer-path}",
                "#{session_path}",
            )
        ),
        check=False,
    )
    result: list[dict[str, str]] = []
    for line in listing.splitlines():
        fields = line.split(PANE_SEPARATOR, 6)
        if len(fields) != 7:
            continue
        result.append(
            dict(
                zip(
                    (
                        "id",
                        "activity",
                        "name",
                        "windows",
                        "attached",
                        "registered_path",
                        "session_path",
                    ),
                    fields,
                    strict=True,
                )
            )
        )
    return result


def inventory_session_paths(inventory: list[dict[str, str]]) -> set[Path]:
    result: set[Path] = set()
    for session in inventory:
        for key in ("registered_path", "session_path"):
            value = session.get(key, "")
            if not value:
                continue
            with contextlib.suppress(OSError):
                result.add(Path(value).expanduser().resolve())
    return result


def local_candidates(
    origin_session: str = "", inventory: list[dict[str, str]] | None = None
) -> list[Candidate]:
    if inventory is None:
        inventory = local_session_inventory()
    local_color = os.environ.get("FLEET_HOST_HEX", "")
    host = socket.gethostname()
    candidates: list[tuple[int, Candidate]] = []
    for session in inventory:
        session_id = session["id"]
        activity = session["activity"]
        name = session["name"]
        windows = session["windows"]
        attached = session["attached"]
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
        if not isinstance(raw.get("directories", []), list):
            raise TypeError("directories is not a list")
        return raw
    except (OSError, TypeError, ValueError, json.JSONDecodeError):
        return {"status": "connecting", "sessions": [], "directories": []}


def write_remote_cache(host: FleetHost, data: dict[str, Any]) -> None:
    REMOTE_CACHE_DIR.mkdir(parents=True, exist_ok=True)
    path = remote_cache_path(host)
    temporary = path.with_suffix(f".{os.getpid()}.tmp")
    temporary.write_text(json.dumps(data), encoding="utf-8")
    temporary.replace(path)


def remote_sessionizer_command(*args: str) -> str:
    return '"$HOME/bin/sessionizer" ' + shlex.join(args)


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
                    remote_sessionizer_command("--inventory"),
                ],
                check=False,
                timeout=15,
            )
        except SessionizerError:
            write_remote_cache(
                host,
                {
                    "status": "offline",
                    "sessions": previous.get("sessions", []),
                    "directories": previous.get("directories", []),
                },
            )
            return
        if result.returncode == 0:
            try:
                inventory = json.loads(result.stdout)
                sessions = inventory["sessions"]
                directories = inventory["directories"]
                if not isinstance(sessions, list) or not isinstance(directories, list):
                    raise TypeError("inventory lists are invalid")
            except (KeyError, TypeError, ValueError, json.JSONDecodeError):
                data = {
                    "status": "offline",
                    "sessions": previous.get("sessions", []),
                    "directories": previous.get("directories", []),
                }
            else:
                data = {
                    "status": "online",
                    "sessions": sessions,
                    "directories": directories,
                }
        else:
            data = {
                "status": "offline",
                "sessions": previous.get("sessions", []),
                "directories": previous.get("directories", []),
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
        directories = cached.get("directories", [])
        for raw in directories:
            try:
                name = str(raw["name"])
                path = str(raw["path"])
            except (KeyError, TypeError):
                continue
            result.append(
                Candidate(
                    identity=f"remote-directory:{host.name}:{path}",
                    kind="remote-directory",
                    name=name,
                    target=path,
                    detail=path,
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


def directory_candidates(
    config: Config,
    overrides: list[str],
    used_paths: set[Path] | None = None,
) -> list[Candidate]:
    fd = shutil.which("fd") or shutil.which("fdfind")
    if fd is None:
        raise SessionizerError("missing required command: fd")

    roots = overrides or list(config.search_paths)
    host = socket.gethostname()
    color = os.environ.get("FLEET_HOST_HEX", "")
    used_paths = used_paths or set()
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
            if path in seen or path in used_paths or not path.is_dir():
                continue
            seen.add(path)
            result.append(
                Candidate(
                    identity="directory:" + str(path),
                    kind="directory",
                    name=path.name or str(path),
                    target=str(path),
                    detail=str(path),
                    host=host,
                    color=color,
                )
            )
    return result


def all_candidates(
    config: Config, overrides: list[str], origin_session: str = ""
) -> list[Candidate]:
    inventory = local_session_inventory()
    return [
        *local_candidates(origin_session, inventory),
        *remote_candidates(config.remote_hosts),
        *directory_candidates(config, overrides, inventory_session_paths(inventory)),
    ]


def print_inventory(config: Config) -> None:
    inventory = local_session_inventory()
    sessions = [
        {
            "id": session["id"],
            "name": session["name"],
            "windows": session["windows"],
        }
        for session in inventory
        if re.fullmatch(r"\$\d+", session["id"])
    ]
    directories = [
        {"name": candidate.name, "path": candidate.target}
        for candidate in directory_candidates(
            config, [], inventory_session_paths(inventory)
        )
    ]
    print(json.dumps({"sessions": sessions, "directories": directories}))


def render_row(candidate: Candidate) -> str:
    machine = colorize(
        fit_column(candidate.host, MACHINE_COLUMN_WIDTH), candidate.color
    )
    name = fit_column(candidate.name, SESSION_COLUMN_WIDTH)
    detail = sanitize_field(candidate.detail)
    if candidate.kind in {"directory", "remote-directory"}:
        name = colorize(name, DIRECTORY_COLOR)
        detail = colorize(detail, DIRECTORY_COLOR)
    display = f"{machine} │ {name} │ {detail}"
    return f"{candidate.identity}\t{candidate.token()}\t{display}"


def render_rows(candidates: list[Candidate]) -> str:
    if not candidates:
        return ""
    return "\n".join(render_row(candidate) for candidate in candidates) + "\n"


def picker_header(machine: str = "") -> str:
    label = machine.upper() if machine else "ALL"
    return (
        f"{label:<{MACHINE_COLUMN_WIDTH}} │ "
        f"{'SESSION':<{SESSION_COLUMN_WIDTH}} │ DETAILS  Tab cycles machine"
    )


def snapshot_candidates(snapshot: Path) -> list[tuple[str, Candidate]]:
    try:
        rows = snapshot.read_text(encoding="utf-8").splitlines()
    except OSError:
        return []

    result: list[tuple[str, Candidate]] = []
    for row in rows:
        fields = row.split("\t", 2)
        if len(fields) < 2:
            continue
        with contextlib.suppress(SessionizerError):
            result.append((row, Candidate.from_token(fields[1])))
    return result


def read_machine_filter(state: Path) -> str:
    try:
        return state.read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def print_machine_rows(snapshot_value: str, state_value: str) -> None:
    machine = read_machine_filter(Path(state_value))
    for row, candidate in snapshot_candidates(Path(snapshot_value)):
        if not machine or candidate.host == machine:
            print(row)


def machine_rows_command(snapshot: Path, state: Path) -> str:
    return shlex.join([str(SCRIPT_PATH), "--machine-rows", str(snapshot), str(state)])


def cycle_machine(snapshot_value: str, state_value: str) -> None:
    snapshot = Path(snapshot_value)
    state = Path(state_value)
    machines = list(
        dict.fromkeys(
            candidate.host
            for _, candidate in snapshot_candidates(snapshot)
            if candidate.host
        )
    )
    local_host = socket.gethostname()
    if local_host in machines:
        machines.remove(local_host)
        machines.insert(0, local_host)

    filters = ["", *machines]
    current = read_machine_filter(state)
    try:
        index = filters.index(current)
    except ValueError:
        index = 0
    selected = filters[(index + 1) % len(filters)]
    temporary = state.with_suffix(f".{os.getpid()}.tmp")
    temporary.write_text(selected + "\n", encoding="utf-8")
    temporary.replace(state)
    print(
        f"reload({machine_rows_command(snapshot, state)})"
        f"+change-header({picker_header(selected)})+first"
    )


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
    descriptor, state_name = tempfile.mkstemp(
        prefix="picker-machine-", suffix=".txt", dir=CACHE_DIR
    )
    os.close(descriptor)
    state = Path(state_name)
    state.write_text("\n", encoding="utf-8")

    refresh_command = shlex.join(
        [
            str(SCRIPT_PATH),
            "--refresh-picker",
            str(snapshot),
            str(state),
            origin_session,
            json.dumps(overrides, separators=(",", ":")),
        ]
    )
    cycle_machine_command = shlex.join(
        [str(SCRIPT_PATH), "--cycle-machine", str(snapshot), str(state)]
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
    bindings = ["start:unbind(" + ",".join(modal_keys) + ")"]
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
    bindings.append("change:first")
    bindings.append("tab:transform(" + cycle_machine_command + ")")
    bindings.append("load:bg-transform(" + refresh_command + ")+unbind(load)")

    command = [
        "fzf",
        "--ansi",
        "--reverse",
        "--no-multi",
        "--cycle",
        "--exact",
        "--no-hscroll",
        "--info=inline",
        "--print-query",
        "--prompt",
        "insert> ",
        "--header",
        picker_header(),
        "--delimiter",
        "\t",
        "--with-nth",
        "3",
        "--nth",
        "1",
        "--scheme=default",
        "--tiebreak=begin,length,index",
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
        state.unlink(missing_ok=True)

    output = result.stdout.splitlines()
    if result.returncode != 0 or len(output) < 2:
        return None
    fields = output[1].split("\t", 2)
    if len(fields) < 2:
        raise SessionizerError("invalid picker selection")
    token = fields[1]
    return Candidate.from_token(token)


def refresh_picker(
    snapshot_value: str,
    state_value: str,
    origin_session: str,
    overrides_value: str,
) -> None:
    snapshot = Path(snapshot_value)
    state = Path(state_value)
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
    print("reload(" + machine_rows_command(snapshot, state) + ")")


def parse_panes(output: str) -> list[Pane]:
    panes: list[Pane] = []
    for line in output.splitlines():
        fields = line.split(PANE_SEPARATOR, 8)
        if len(fields) != 9:
            continue
        try:
            pid = int(fields[5])
        except ValueError:
            pid = 0
        panes.append(
            Pane(
                window_index=fields[0],
                window_name=fields[1],
                window_active=fields[2] == "1",
                pane_index=fields[3],
                pane_active=fields[4] == "1",
                pid=pid,
                command=fields[6],
                path=fields[7],
                title=fields[8],
            )
        )
    return panes


def descendant_process_text(pid: int) -> str:
    if pid <= 0:
        return ""
    pending = [pid]
    seen: set[int] = set()
    fragments: list[str] = []
    while pending:
        current = pending.pop()
        if current in seen:
            continue
        seen.add(current)
        process_dir = Path("/proc") / str(current)
        with contextlib.suppress(OSError):
            fragments.append((process_dir / "comm").read_text(encoding="utf-8"))
        with contextlib.suppress(OSError):
            fragments.append(
                (process_dir / "cmdline")
                .read_bytes()
                .replace(b"\0", b" ")
                .decode(errors="replace")
            )
        children_path = process_dir / "task" / str(current) / "children"
        with contextlib.suppress(OSError, ValueError):
            pending.extend(int(value) for value in children_path.read_text().split())
    return " ".join(fragments)


def detect_agents(pane: Pane, *, inspect_processes: bool) -> tuple[str, ...]:
    text = f"{pane.window_name} {pane.command} {pane.title}"
    if inspect_processes:
        text += " " + descendant_process_text(pane.pid)
    lowered = text.casefold()
    return tuple(
        agent
        for agent in AGENT_NAMES
        if re.search(rf"(?<![a-z0-9]){re.escape(agent)}(?![a-z0-9])", lowered)
    )


def abbreviated_path(value: str) -> str:
    home = str(Path.home())
    if value == home:
        return "~"
    if value.startswith(home + "/"):
        return "~" + value[len(home) :]
    return value


def session_panes(candidate: Candidate) -> tuple[list[Pane], bool]:
    if candidate.kind == "local":
        output = tmux(
            "list-panes",
            "-s",
            "-t",
            candidate.target,
            "-F",
            PANE_FORMAT,
            check=False,
        )
        return parse_panes(output), True

    remote_command = (
        shlex.join(
            ["tmux", "list-panes", "-s", "-t", candidate.target, "-F", PANE_FORMAT]
        )
        + " 2>/dev/null"
    )
    result = run(
        [
            "ssh",
            "-o",
            "BatchMode=yes",
            "-o",
            "ConnectTimeout=2",
            f"{candidate.host}-agent",
            remote_command,
        ],
        check=False,
        timeout=5,
    )
    return parse_panes(result.stdout), False


def render_session_preview(candidate: Candidate) -> None:
    panes, inspect_processes = session_panes(candidate)
    agents_by_pane = {
        (pane.window_index, pane.pane_index): detect_agents(
            pane, inspect_processes=inspect_processes
        )
        for pane in panes
    }
    agents = tuple(
        dict.fromkeys(
            agent for detected in agents_by_pane.values() for agent in detected
        )
    )
    windows = len({pane.window_index for pane in panes})

    print(colorize(candidate.name, candidate.color))
    summary = f"{candidate.host} · {windows} window{'s' if windows != 1 else ''} · {len(panes)} pane{'s' if len(panes) != 1 else ''}"
    if agents:
        summary += " · agents: " + ", ".join(agents)
    print(summary)
    print()

    previous_window = ""
    for pane in panes:
        if pane.window_index != previous_window:
            if previous_window:
                print()
            marker = "●" if pane.window_active else "○"
            print(f"{marker} {pane.window_index}: {pane.window_name}")
            previous_window = pane.window_index
        marker = "›" if pane.pane_active else " "
        detected = agents_by_pane[(pane.window_index, pane.pane_index)]
        agent_label = ""
        if detected:
            agent_label = " " + colorize("[" + ", ".join(detected) + "]", AGENT_COLOR)
        command = sanitize_field(pane.command) or "shell"
        print(f"  {marker} {pane.pane_index}  {command}{agent_label}")
        path = abbreviated_path(sanitize_field(pane.path))
        if path:
            print(f"      {path}")

    if candidate.kind == "remote":
        print()
        print("M-s returns to the origin picker · prefix+d returns locally")


def print_directory_preview(path_value: str) -> None:
    path = Path(path_value)
    try:
        entries = sorted(path.iterdir(), key=lambda entry: entry.name.casefold())[:30]
    except OSError:
        return
    for entry in entries:
        suffix = "/" if entry.is_dir() else ""
        print(entry.name + suffix)


def preview(candidate: Candidate) -> None:
    if candidate.kind in {"local", "remote"}:
        render_session_preview(candidate)
        return

    if candidate.kind == "remote-directory":
        result = run(
            [
                "ssh",
                "-o",
                "BatchMode=yes",
                "-o",
                "ConnectTimeout=2",
                f"{candidate.host}-agent",
                remote_sessionizer_command("--preview-directory", candidate.target),
            ],
            check=False,
            timeout=5,
        )
        print(result.stdout, end="")
        return

    print_directory_preview(candidate.target)


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


def ensure_remote_directory_session(candidate: Candidate) -> Candidate:
    result = run(
        [
            "ssh",
            "-o",
            "BatchMode=yes",
            "-o",
            "ConnectTimeout=2",
            f"{candidate.host}-agent",
            remote_sessionizer_command("--ensure-directory-session", candidate.target),
        ],
        check=False,
        timeout=15,
    )
    target = result.stdout.strip()
    if result.returncode != 0 or not re.fullmatch(r"\$\d+", target):
        message = result.stderr.strip() or "remote session creation failed"
        raise SessionizerError(
            f"could not open {candidate.target} on {candidate.host}: {message}"
        )
    return Candidate(
        identity=f"remote:{candidate.host}:{target}",
        kind="remote",
        name=candidate.name,
        target=target,
        detail=candidate.detail,
        host=candidate.host,
        color=candidate.color,
    )


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
        if selected.kind == "remote-directory":
            selected = ensure_remote_directory_session(selected)
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


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="sessionizer",
        description="Switch between local projects and tmux sessions across the fleet.",
    )
    parser.add_argument("search_paths", nargs="*")
    parser.add_argument("-v", "--version", action="store_true")
    parser.add_argument("--init", action="store_true")
    parser.add_argument("--preview-token", help=argparse.SUPPRESS)
    parser.add_argument("--preview-directory", help=argparse.SUPPRESS)
    parser.add_argument("--refresh-picker", nargs=4, help=argparse.SUPPRESS)
    parser.add_argument("--machine-rows", nargs=2, help=argparse.SUPPRESS)
    parser.add_argument("--cycle-machine", nargs=2, help=argparse.SUPPRESS)
    parser.add_argument("--inventory", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--ensure-directory-session", help=argparse.SUPPRESS)
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
    if args.preview_directory:
        print_directory_preview(args.preview_directory)
        return 0
    if args.refresh_picker:
        refresh_picker(*args.refresh_picker)
        return 0
    if args.machine_rows:
        print_machine_rows(*args.machine_rows)
        return 0
    if args.cycle_machine:
        cycle_machine(*args.cycle_machine)
        return 0
    if args.is_managed:
        return 0 if is_managed_client(args.is_managed) else 1
    if args.remote_attach:
        return remote_attach(args.remote_attach)
    if args.travel:
        travel(*args.travel)

    config = load_config()
    if args.inventory:
        print_inventory(config)
        return 0
    if args.ensure_directory_session:
        print(ensure_directory_session(args.ensure_directory_session))
        return 0
    selected = picker(config, args.search_paths, current_session_id())
    if selected is None:
        return 0
    if selected.kind == "remote-directory":
        selected = ensure_remote_directory_session(selected)
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
