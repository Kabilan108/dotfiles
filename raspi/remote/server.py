#!/usr/bin/env python3
import html
import json
import os
import re
import secrets
import subprocess
import threading
import time
from http import HTTPStatus
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from urllib.parse import parse_qs, urlencode, urlparse

ROOT = Path(__file__).resolve().parent
STATE_DIR = Path(os.environ.get("REMOTE_STATE_DIR", str(ROOT))).expanduser()
RUNS = Path(os.environ.get("REMOTE_RUNS_DIR", str(STATE_DIR / "runs"))).expanduser()
TOKEN_FILE = Path(os.environ.get("REMOTE_TOKEN_FILE", str(STATE_DIR / ".remote-token"))).expanduser()
JELLYFIN_AUTH_CACHE = Path(
    os.environ.get("JELLYFIN_AUTH_CACHE", str(STATE_DIR / "jellyfin-auth.json"))
).expanduser()
PORT = int(os.environ.get("REMOTE_PORT", "8787"))
WORKSPACE = os.environ.get("REMOTE_CODEX_WORKSPACE", str(ROOT))
SYSTEMCTL = os.environ.get("REMOTE_SYSTEMCTL", "systemctl")
SUDO = os.environ.get("REMOTE_SUDO", "sudo")


def sh(args, timeout=8, check=False):
    try:
        result = subprocess.run(
            args,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
            check=check,
        )
        return result.returncode, result.stdout.strip()
    except FileNotFoundError:
        return 127, f"{args[0]} not found"
    except subprocess.TimeoutExpired:
        return 124, "command timed out"


def read_token():
    if TOKEN_FILE.exists():
        return TOKEN_FILE.read_text().strip()
    token = secrets.token_urlsafe(32)
    TOKEN_FILE.parent.mkdir(parents=True, exist_ok=True)
    TOKEN_FILE.write_text(token + "\n")
    TOKEN_FILE.chmod(0o600)
    return token


TOKEN = read_token()


def tailscale_ip(fallback="127.0.0.1"):
    code, out = sh(["tailscale", "ip", "-4"], timeout=3)
    if code == 0 and out:
        return out.splitlines()[0].strip()
    return fallback


def bind_address():
    configured = os.environ.get("REMOTE_BIND")
    if configured:
        return configured

    wait_seconds = int(os.environ.get("REMOTE_TAILSCALE_WAIT_SECONDS", "0"))
    deadline = time.monotonic() + wait_seconds
    while True:
        ip = tailscale_ip(fallback="")
        if ip:
            return ip
        if time.monotonic() >= deadline:
            return "127.0.0.1"
        time.sleep(1)


def home_dir() -> Path:
    return Path(os.environ.get("HOME", str(Path.home()))).expanduser()


def file_mtime(path: Path) -> float:
    try:
        return path.stat().st_mtime
    except OSError:
        return 0


def jellyfin_leveldb_files() -> list[Path]:
    home = home_dir()
    profile_globs = [
        ".local/share/jellyfin-desktop/profiles/*/QtWebEngine/Local Storage/leveldb/*",
        ".local/share/jellyfinmediaplayer/profiles/*/QtWebEngine/Local Storage/leveldb/*",
        ".local/share/jellyfin-media-player/profiles/*/QtWebEngine/Local Storage/leveldb/*",
        ".local/share/Jellyfin Media Player/profiles/*/QtWebEngine/Local Storage/leveldb/*",
        ".var/app/com.github.iwalton3.jellyfin-media-player/data/jellyfinmediaplayer/profiles/*/QtWebEngine/Local Storage/leveldb/*",
    ]
    files = []
    for pattern in profile_globs:
        files.extend(path for path in home.glob(pattern) if path.suffix in {".log", ".ldb"})
    return sorted(files, key=file_mtime, reverse=True)


def last_match(patterns: list[str], data: str) -> str | None:
    for pattern in patterns:
        matches = re.findall(pattern, data)
        if matches:
            return matches[-1]
    return None


def extract_jellyfin_context() -> tuple[str | None, str | None, str | None]:
    token = None
    user_id = None
    source = None
    token_patterns = [
        r'AccessToken\\?":\\?"([^"\\]+)',
        r'AccessToken":"([^"]+)',
    ]
    user_id_patterns = [
        r'UserId\\?":\\?"([0-9a-fA-F-]+)',
        r'UserId":"([0-9a-fA-F-]+)',
    ]

    for path in jellyfin_leveldb_files():
        try:
            data = path.read_bytes().decode("utf-8", errors="ignore")
        except OSError:
            continue

        discovered_token = last_match(token_patterns, data)
        discovered_user_id = last_match(user_id_patterns, data)
        if discovered_token and not token:
            token = discovered_token
            source = str(path)
        if discovered_user_id and not user_id:
            user_id = discovered_user_id
            source = source or str(path)
        if token and user_id:
            return token, user_id, source
    return None, None, None


def read_jellyfin_auth_cache() -> tuple[str | None, str | None]:
    try:
        cached = json.loads(JELLYFIN_AUTH_CACHE.read_text())
    except (OSError, json.JSONDecodeError):
        return None, None
    token = cached.get("token")
    user_id = cached.get("user_id")
    if isinstance(token, str) and isinstance(user_id, str):
        return token, user_id
    return None, None


def write_jellyfin_auth_cache(url: str, token: str, user_id: str, source: str | None) -> None:
    payload = {
        "server_url": url,
        "token": token,
        "user_id": user_id,
        "source": source,
        "updated_at": time.time(),
    }
    try:
        JELLYFIN_AUTH_CACHE.parent.mkdir(parents=True, exist_ok=True)
        JELLYFIN_AUTH_CACHE.write_text(json.dumps(payload, indent=2) + "\n")
        JELLYFIN_AUTH_CACHE.chmod(0o600)
    except OSError:
        pass


def get_jellyfin_context() -> tuple[str, str | None, str | None]:
    token = os.environ.get("JELLYFIN_TOKEN")
    user_id = os.environ.get("JELLYFIN_USER_ID")
    url = os.environ.get("JELLYFIN_URL", "http://sietch:8096")
    if token and user_id:
        return url, token, user_id

    if token and not user_id:
        _cached_token, cached_user_id = read_jellyfin_auth_cache()
        if cached_user_id:
            return url, token, cached_user_id

    discovered_token, discovered_user_id, source = extract_jellyfin_context()
    token = token or discovered_token
    user_id = user_id or discovered_user_id
    if token and user_id:
        write_jellyfin_auth_cache(url, token, user_id, source)
        return url, token, user_id

    cached_token, cached_user_id = read_jellyfin_auth_cache()
    return url, token or cached_token, user_id or cached_user_id


def jellyfin_api(path, method="GET", body=None):
    url, token, _user_id = get_jellyfin_context()
    if not token:
        return 1, "Jellyfin token not found"
    args = ["curl", "-fsS", "-H", f"X-Emby-Token: {token}"]
    if method == "POST":
        args += ["-X", "POST"]
    if body is not None:
        args += ["-H", "Content-Type: application/json", "-d", json.dumps(body)]
    args.append(url + path)
    return sh(args, timeout=8)


def jellyfin_json(path):
    code, out = jellyfin_api(path)
    if code != 0:
        return None, out
    try:
        return json.loads(out), None
    except json.JSONDecodeError as exc:
        return None, str(exc)


def jellyfin_user_id():
    _url, _token, user_id = get_jellyfin_context()
    return user_id


def play_item(session_id, item_id):
    return jellyfin_api(
        f"/Sessions/{session_id}/Playing?playCommand=PlayNow&itemIds={item_id}&startPositionTicks=0",
        method="POST",
        body={"ItemIds": [item_id], "PlayCommand": "PlayNow", "StartPositionTicks": 0},
    )


def item_summary(item):
    return {
        "id": item.get("Id"),
        "name": item.get("Name"),
        "type": item.get("Type"),
        "seriesName": item.get("SeriesName"),
        "seasonName": item.get("SeasonName"),
        "indexNumber": item.get("IndexNumber"),
        "parentIndexNumber": item.get("ParentIndexNumber"),
        "productionYear": item.get("ProductionYear"),
        "isFolder": item.get("IsFolder"),
    }


def jellyfin_items(params):
    user_id = jellyfin_user_id()
    if not user_id:
        return None, "Jellyfin user id not found"
    query = urlencode(params, doseq=True)
    payload, error = jellyfin_json(f"/Users/{user_id}/Items?{query}")
    if error:
        return None, error
    return [item_summary(item) for item in payload.get("Items", [])], None


def adjacent_episode(session, direction):
    item = session.get("NowPlayingItem") or {}
    current_id = item.get("Id")
    season_id = item.get("SeasonId") or item.get("ParentId")
    if not current_id or not season_id:
        return None, "No current episode with a season id"
    items, error = jellyfin_items({
        "ParentId": season_id,
        "IncludeItemTypes": "Episode",
        "SortBy": "IndexNumber,SortName",
        "SortOrder": "Ascending",
    })
    if error:
        return None, error
    ids = [episode["id"] for episode in items]
    if current_id not in ids:
        return None, "Current episode was not found in its season"
    next_index = ids.index(current_id) + direction
    if next_index < 0 or next_index >= len(items):
        return None, "No adjacent episode in this season"
    return items[next_index], None


def jellyfin_session():
    code, out = jellyfin_api("/Sessions")
    if code != 0:
        return None
    try:
        sessions = json.loads(out)
    except json.JSONDecodeError:
        return None
    remote = [s for s in sessions if s.get("SupportsRemoteControl")]
    remote.sort(key=lambda s: (s.get("NowPlayingItem") is not None, s.get("IsActive") is True), reverse=True)
    return remote[0] if remote else None


def service_active(service: str) -> bool:
    code, _out = sh([SYSTEMCTL, "is-active", "--quiet", service], timeout=4)
    return code == 0


def display_payload() -> dict[str, object]:
    airplay = service_active("uxplay.service")
    jellyfin = service_active("greetd.service")
    mode = "idle"
    if airplay and jellyfin:
        mode = "conflict"
    elif airplay:
        mode = "airplay"
    elif jellyfin:
        mode = "jellyfin"
    return {
        "mode": mode,
        "airplay": airplay,
        "jellyfin": jellyfin,
    }


def switch_display(mode: str) -> tuple[bool, str]:
    commands = {
        "airplay": [
            [SUDO, SYSTEMCTL, "stop", "greetd.service"],
            [SUDO, SYSTEMCTL, "start", "uxplay.service"],
        ],
        "jellyfin": [
            [SUDO, SYSTEMCTL, "stop", "uxplay.service"],
            [SUDO, SYSTEMCTL, "start", "greetd.service"],
        ],
        "off": [
            [SUDO, SYSTEMCTL, "stop", "uxplay.service"],
            [SUDO, SYSTEMCTL, "stop", "greetd.service"],
        ],
    }.get(mode)
    if commands is None:
        return False, "unknown display mode"

    messages = []
    for command in commands:
        code, out = sh(command, timeout=12)
        if out:
            messages.append(out)
        if code != 0:
            return False, "\n".join(messages) or f"{' '.join(command)} failed"

    expected = "idle" if mode == "off" else mode
    deadline = time.monotonic() + 12
    current = display_payload()["mode"]
    while current != expected and time.monotonic() < deadline:
        time.sleep(1)
        current = display_payload()["mode"]
    if current != expected:
        detail = "\n".join(messages)
        if detail:
            return False, f"Requested {mode}, but display is {current}.\n{detail}"
        return False, f"Requested {mode}, but display is {current}"
    return True, f"Display switched to {mode}"


def status_payload():
    code, audio = sh(["wpctl", "status"], timeout=4)
    session = jellyfin_session()
    jobs = []
    RUNS.mkdir(exist_ok=True)
    for path in sorted(RUNS.glob("*.json"), reverse=True)[:8]:
        try:
            jobs.append(json.loads(path.read_text()))
        except json.JSONDecodeError:
            pass
    return {
        "host": os.uname().nodename,
        "tailscaleIp": tailscale_ip(),
        "port": PORT,
        "audio": audio if code == 0 else "",
        "jellyfin": {
            "sessionId": session.get("Id") if session else None,
            "client": session.get("Client") if session else None,
            "device": session.get("DeviceName") if session else None,
            "item": session.get("NowPlayingItem") if session else None,
            "playState": session.get("PlayState") if session else None,
        } if session else None,
        "display": display_payload(),
        "jobs": jobs,
    }


def switch_hdmi():
    code, out = sh(["wpctl", "status"], timeout=4)
    if code != 0:
        return False, out
    sink_id = None
    for line in out.splitlines():
        if "Digital Stereo (HDMI)" in line:
            parts = line.replace("*", " ").split()
            for part in parts:
                if part.rstrip(".").isdigit():
                    sink_id = part.rstrip(".")
                    break
    if not sink_id:
        return False, "HDMI sink not found"
    messages = []
    for cmd in (
        ["wpctl", "set-default", sink_id],
        ["wpctl", "set-volume", sink_id, "1.0"],
        ["wpctl", "set-mute", sink_id, "0"],
    ):
        c, o = sh(cmd, timeout=4)
        messages.append(o)
        if c != 0:
            return False, "\n".join(messages)
    return True, f"Audio switched to HDMI sink {sink_id}"


def start_codex(prompt):
    RUNS.mkdir(exist_ok=True)
    job_id = time.strftime("%Y%m%d-%H%M%S")
    meta_path = RUNS / f"{job_id}.json"
    out_path = RUNS / f"{job_id}.log"
    meta = {"id": job_id, "prompt": prompt, "status": "running", "createdAt": time.time()}
    meta_path.write_text(json.dumps(meta, indent=2))

    def run():
        cmd = [
            "codex",
            "exec",
            "--skip-git-repo-check",
            "-C",
            WORKSPACE,
            "--dangerously-bypass-approvals-and-sandbox",
            prompt,
        ]
        with out_path.open("w") as output:
            proc = subprocess.run(cmd, text=True, stdout=output, stderr=subprocess.STDOUT)
        meta["status"] = "done" if proc.returncode == 0 else "failed"
        meta["returnCode"] = proc.returncode
        meta["finishedAt"] = time.time()
        meta["output"] = out_path.read_text(errors="replace")[-8000:]
        meta_path.write_text(json.dumps(meta, indent=2))

    threading.Thread(target=run, daemon=True).start()
    return meta


class Handler(BaseHTTPRequestHandler):
    server_version = "CodexRemote/0.1"

    def log_message(self, fmt, *args):
        message = fmt % args
        message = re.sub(r"\?token=[^ ]+", "?token=<redacted>", message)
        print("%s - %s" % (self.address_string(), message))

    def authed(self):
        parsed = urlparse(self.path)
        query_token = parse_qs(parsed.query).get("token", [""])[0]
        header = self.headers.get("Authorization", "")
        bearer = header.removeprefix("Bearer ").strip() if header.startswith("Bearer ") else ""
        return secrets.compare_digest(query_token or bearer, TOKEN)

    def send_json(self, data, status=200):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def read_json(self):
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length else b"{}"
        return json.loads(raw.decode() or "{}")

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/":
            return self.index()
        if not self.authed():
            return self.send_json({"error": "unauthorized"}, HTTPStatus.UNAUTHORIZED)
        if parsed.path == "/api/status":
            return self.send_json(status_payload())
        if parsed.path == "/api/jellyfin/views":
            return self.jellyfin_views()
        if parsed.path == "/api/jellyfin/items":
            return self.jellyfin_items(parsed)
        if parsed.path == "/api/jellyfin/search":
            return self.jellyfin_search(parsed)
        return self.send_error(HTTPStatus.NOT_FOUND)

    def do_POST(self):
        if not self.authed():
            return self.send_json({"error": "unauthorized"}, HTTPStatus.UNAUTHORIZED)
        try:
            data = self.read_json()
        except json.JSONDecodeError:
            return self.send_json({"error": "invalid json"}, HTTPStatus.BAD_REQUEST)
        parsed = urlparse(self.path)
        if parsed.path == "/api/audio/hdmi":
            ok, message = switch_hdmi()
            return self.send_json({"ok": ok, "message": message}, 200 if ok else 500)
        if parsed.path == "/api/display":
            mode = str(data.get("mode", "")).strip()
            ok, message = switch_display(mode)
            payload = {"ok": ok, "message": message, "display": display_payload()}
            return self.send_json(payload, 200 if ok else 500)
        if parsed.path == "/api/jellyfin":
            return self.jellyfin(data)
        if parsed.path == "/api/codex":
            prompt = str(data.get("prompt", "")).strip()
            if not prompt:
                return self.send_json({"error": "prompt required"}, HTTPStatus.BAD_REQUEST)
            return self.send_json(start_codex(prompt))
        return self.send_error(HTTPStatus.NOT_FOUND)

    def jellyfin(self, data):
        action = data.get("action")
        session = jellyfin_session()
        if not session:
            return self.send_json({"error": "no remote-control Jellyfin session"}, 500)
        sid = session["Id"]
        command_map = {
            "pause": f"/Sessions/{sid}/Playing/Pause",
            "unpause": f"/Sessions/{sid}/Playing/Unpause",
            "stop": f"/Sessions/{sid}/Playing/Stop",
        }
        if action in command_map:
            code, out = jellyfin_api(command_map[action], method="POST")
            return self.send_json({"ok": code == 0, "output": out}, 200 if code == 0 else 500)
        if action in ("volumeUp", "volumeDown", "mute"):
            name = {"volumeUp": "VolumeUp", "volumeDown": "VolumeDown", "mute": "ToggleMute"}[action]
            code, out = jellyfin_api(f"/Sessions/{sid}/Command", method="POST", body={"Name": name})
            return self.send_json({"ok": code == 0, "output": out}, 200 if code == 0 else 500)
        if action == "seek":
            seconds = int(data.get("seconds", 0))
            play_state = session.get("PlayState") or {}
            current = int(play_state.get("PositionTicks") or 0)
            target = max(0, current + seconds * 10_000_000)
            item = session.get("NowPlayingItem") or {}
            runtime = int(item.get("RunTimeTicks") or 0)
            if runtime:
                target = min(target, runtime - 1)
            code, out = jellyfin_api(
                f"/Sessions/{sid}/Playing/Seek?seekPositionTicks={target}",
                method="POST",
            )
            return self.send_json({"ok": code == 0, "output": out, "targetTicks": target}, 200 if code == 0 else 500)
        if action in ("nextEpisode", "previousEpisode"):
            direction = 1 if action == "nextEpisode" else -1
            episode, error = adjacent_episode(session, direction)
            if error:
                return self.send_json({"error": error}, 500)
            code, out = play_item(sid, episode["id"])
            return self.send_json({"ok": code == 0, "output": out, "episode": episode}, 200 if code == 0 else 500)
        if action == "playItem":
            item_id = str(data.get("itemId", "")).strip()
            if not item_id:
                return self.send_json({"error": "itemId required"}, HTTPStatus.BAD_REQUEST)
            code, out = play_item(sid, item_id)
            return self.send_json({"ok": code == 0, "output": out}, 200 if code == 0 else 500)
        if action == "durararaStart":
            item_id = "931a05b85cacde0abff8cd3bf5918137"
            code, out = play_item(sid, item_id)
            return self.send_json({"ok": code == 0, "output": out}, 200 if code == 0 else 500)
        return self.send_json({"error": "unknown action"}, HTTPStatus.BAD_REQUEST)

    def jellyfin_views(self):
        user_id = jellyfin_user_id()
        if not user_id:
            return self.send_json({"error": "Jellyfin user id not found"}, 500)
        payload, error = jellyfin_json(f"/Users/{user_id}/Views")
        if error:
            return self.send_json({"error": error}, 500)
        items = [
            {
                "id": item.get("Id"),
                "name": item.get("Name"),
                "type": item.get("Type"),
                "collectionType": item.get("CollectionType"),
            }
            for item in payload.get("Items", [])
        ]
        return self.send_json({"items": items})

    def jellyfin_items(self, parsed):
        qs = parse_qs(parsed.query)
        parent_id = qs.get("parentId", [""])[0]
        if not parent_id:
            return self.send_json({"error": "parentId required"}, HTTPStatus.BAD_REQUEST)
        items, error = jellyfin_items({
            "ParentId": parent_id,
            "Recursive": "false",
            "SortBy": "SortName",
            "SortOrder": "Ascending",
            "Limit": "200",
        })
        if error:
            return self.send_json({"error": error}, 500)
        return self.send_json({"items": items})

    def jellyfin_search(self, parsed):
        qs = parse_qs(parsed.query)
        term = qs.get("q", [""])[0].strip()
        if not term:
            return self.send_json({"items": []})
        items, error = jellyfin_items({
            "SearchTerm": term,
            "Recursive": "true",
            "IncludeItemTypes": "Movie,Episode,Series,Season",
            "Limit": "50",
        })
        if error:
            return self.send_json({"error": error}, 500)
        return self.send_json({"items": items})

    def index(self):
        query_token = parse_qs(urlparse(self.path).query).get("token", [""])[0]
        token = html.escape(query_token or TOKEN)
        body = INDEX_HTML.replace("__TOKEN__", token).encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


INDEX_HTML = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Tleilax Control Center</title>
<style>
  :root{
    color-scheme:dark;
    --bg:#0b0c0f; --card:#15171d; --card-2:#1b1e26; --raise:#23272f;
    --line:rgba(255,255,255,.06); --line-2:rgba(255,255,255,.12);
    --text:#eceef2; --muted:#888f9c; --faint:#5b626e;
    --accent:#4cc6ac; --accent-ink:#04130f; --accent-dim:rgba(76,198,172,.14);
    --warn:#ffb86c; --danger:#ff6b6b; --ok:#7bd88f;
    --r:14px; --r-sm:10px;
  }
  *{box-sizing:border-box}
  html,body{height:100%}
  body{
    margin:0; color:var(--text);
    font-family:ui-sans-serif,system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;
    background:
      radial-gradient(1200px 620px at 50% -12%, rgba(76,198,172,.10), transparent 60%),
      radial-gradient(900px 500px at 100% 0%, rgba(90,120,255,.06), transparent 55%),
      var(--bg);
    background-attachment:fixed;
    -webkit-font-smoothing:antialiased;
  }
  .mono{font-family:ui-monospace,SFMono-Regular,Menlo,monospace}
  [hidden]{display:none!important}
  svg{fill:none; stroke:currentColor; stroke-width:2; stroke-linecap:round; stroke-linejoin:round}
  .app{max-width:680px; margin:0 auto; padding:0 14px calc(40px + env(safe-area-inset-bottom));}

  /* top bar */
  .topbar{position:sticky; top:0; z-index:5; display:flex; align-items:center; justify-content:space-between; gap:12px;
    padding:14px 4px 12px; margin-bottom:6px;
    background:linear-gradient(var(--bg) 55%, rgba(11,12,15,.55)); backdrop-filter:blur(12px);}
  .brand{display:flex; align-items:center; gap:10px}
  .logo{display:grid; place-items:center; width:34px; height:34px; border-radius:10px; color:var(--accent);
    background:var(--accent-dim); border:1px solid rgba(76,198,172,.3)}
  .logo svg{width:19px; height:19px}
  h1{font-size:18px; font-weight:700; margin:0; letter-spacing:-.01em}
  .topbar-right{display:flex; align-items:center; gap:8px}
  .status{display:inline-flex; align-items:center; gap:7px; font-size:12.5px; color:var(--muted);
    border:1px solid var(--line-2); padding:6px 11px; border-radius:999px; font-variant-numeric:tabular-nums}
  .status .dot{width:7px; height:7px; border-radius:50%; background:var(--faint)}
  .status.online{color:var(--text)}
  .status.online .dot{background:var(--accent); animation:pulse 2.4s infinite}
  @keyframes pulse{0%{box-shadow:0 0 0 0 rgba(76,198,172,.45)}70%{box-shadow:0 0 0 6px rgba(76,198,172,0)}100%{box-shadow:0 0 0 0 rgba(76,198,172,0)}}

  /* cards */
  .card{background:linear-gradient(180deg,var(--card-2),var(--card)); border:1px solid var(--line);
    border-radius:var(--r); padding:16px; margin-bottom:12px;
    box-shadow:0 1px 0 rgba(255,255,255,.02) inset, 0 10px 26px -20px rgba(0,0,0,.9)}
  .card-head{display:flex; align-items:center; justify-content:space-between; gap:10px; margin-bottom:13px}
  .eyebrow{font-size:11px; font-weight:700; letter-spacing:.13em; text-transform:uppercase; color:var(--muted)}
  .group-label{font-size:10.5px; font-weight:700; letter-spacing:.09em; text-transform:uppercase; color:var(--faint); margin:15px 2px 8px}

  /* buttons */
  button{font:inherit; color:var(--text); cursor:pointer; -webkit-tap-highlight-color:transparent; border:0; background:none}
  .btn{display:inline-flex; align-items:center; justify-content:center; gap:8px; width:100%; min-height:46px; padding:0 14px;
    border:1px solid var(--line-2); border-radius:var(--r-sm); background:var(--raise); font-size:14.5px; font-weight:600;
    transition:transform .05s, background .15s, border-color .15s, color .15s}
  .btn:hover{background:#2a2f39}
  .btn:active{transform:scale(.97)}
  .btn.primary{background:linear-gradient(180deg,#56d4b8,var(--accent)); color:var(--accent-ink); border-color:transparent; font-weight:700}
  .btn.primary:hover{filter:brightness(1.06)}
  .btn.warn{color:var(--warn)} .btn.danger{color:var(--danger)}
  .btn.active{border-color:var(--accent); color:var(--accent); background:var(--accent-dim)}
  .icon-btn{display:grid; place-items:center; width:38px; height:38px; border-radius:10px; border:1px solid var(--line-2);
    background:var(--raise); color:var(--muted)}
  .icon-btn:hover{color:var(--text)}
  .btn svg,.icon-btn svg{width:17px; height:17px; flex:0 0 auto}

  /* layout helpers */
  .row{display:flex; gap:9px; align-items:center}
  .row input{flex:1}
  .grid{display:grid; gap:9px}
  .g2{grid-template-columns:1fr 1fr}
  .g3{grid-template-columns:repeat(3,1fr)}
  .g4{grid-template-columns:repeat(4,1fr)}

  /* inputs */
  input,textarea{width:100%; color:var(--text); background:var(--bg); border:1px solid var(--line-2);
    border-radius:var(--r-sm); padding:12px; font:inherit; transition:border-color .15s, box-shadow .15s}
  input:focus,textarea:focus{outline:none; border-color:var(--accent); box-shadow:0 0 0 3px var(--accent-dim)}
  textarea{min-height:96px; resize:vertical; line-height:1.5}
  ::placeholder{color:var(--faint)}
  .field-label{display:block; font-size:12px; color:var(--muted); margin-bottom:7px}

  /* now playing */
  .now-title{font-size:18px; font-weight:700; letter-spacing:-.01em; line-height:1.25; margin-top:2px}
  .now-sub{color:var(--muted); font-size:13.5px; margin-top:4px; min-height:1em}
  .chips{display:flex; gap:6px; flex-wrap:wrap; margin-top:11px}
  .chip{display:inline-flex; align-items:center; gap:6px; font-size:11.5px; font-weight:600; color:var(--muted);
    background:var(--bg); border:1px solid var(--line-2); padding:4px 9px; border-radius:999px}
  .chip.live{color:var(--accent); border-color:rgba(76,198,172,.4)}
  .chip .cdot{width:6px; height:6px; border-radius:50%; background:currentColor}
  .progress{height:6px; border-radius:999px; background:rgba(255,255,255,.08); overflow:hidden; margin-top:15px}
  .progress-bar{height:100%; width:0; border-radius:999px; background:linear-gradient(90deg,#56d4b8,var(--accent)); transition:width .4s}
  .time-row{display:flex; justify-content:space-between; font-size:11.5px; color:var(--faint); font-variant-numeric:tabular-nums; margin-top:6px}

  /* transport */
  .transport{display:flex; align-items:center; justify-content:center; gap:12px; margin-top:16px}
  .t-btn{flex:1; display:grid; place-items:center; gap:3px; min-height:56px; border-radius:12px; border:1px solid var(--line-2);
    background:var(--raise); color:var(--text); font-size:11px; font-weight:600; transition:transform .05s, background .15s}
  .t-btn svg{width:20px; height:20px}
  .t-btn:hover{background:#2a2f39}
  .t-btn:active{transform:scale(.95)}
  .t-btn.lg{flex:0 0 auto; width:66px; height:66px; border-radius:50%; border:none;
    background:linear-gradient(180deg,#56d4b8,var(--accent)); color:var(--accent-ink); box-shadow:0 8px 22px -10px rgba(76,198,172,.7)}
  .t-btn.lg svg{width:27px; height:27px}

  /* browser list */
  .list{display:grid; gap:7px}
  .hint{color:var(--muted); font-size:13px; padding:8px 2px}
  .item{display:flex; align-items:center; gap:11px; text-align:left; width:100%; min-height:54px; padding:9px 12px;
    border:1px solid var(--line); border-radius:var(--r-sm); background:var(--bg); transition:background .12s, border-color .12s}
  .item:hover{background:var(--card-2); border-color:var(--line-2)}
  .item .ico{flex:0 0 auto; display:grid; place-items:center; width:34px; height:34px; border-radius:9px; background:var(--accent-dim); color:var(--accent)}
  .item .ico svg{width:17px; height:17px}
  .item .meta{min-width:0; flex:1}
  .item .nm{font-size:14px; font-weight:600; overflow:hidden; text-overflow:ellipsis; white-space:nowrap}
  .item .sub{display:block; color:var(--muted); font-size:12px; font-weight:500; margin-top:2px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap}
  .item .chev{flex:0 0 auto; color:var(--faint)}
  .item .chev svg{width:16px; height:16px; display:block}

  /* jobs */
  .job{border:1px solid var(--line); border-radius:var(--r-sm); padding:12px; background:var(--bg); margin-bottom:9px}
  .job:last-child{margin-bottom:0}
  .job-head{display:flex; align-items:center; gap:9px; font-size:12.5px}
  .badge{font-size:10.5px; font-weight:700; letter-spacing:.04em; text-transform:uppercase; padding:3px 8px; border-radius:999px}
  .badge.running{color:var(--accent); background:var(--accent-dim)}
  .badge.done{color:var(--ok); background:rgba(123,216,143,.14)}
  .badge.failed{color:var(--danger); background:rgba(255,107,107,.14)}
  .job-time{color:var(--faint); font-variant-numeric:tabular-nums}
  .job-prompt{margin-top:8px; color:var(--text); font-size:13px; overflow-wrap:anywhere}
  pre{white-space:pre-wrap; overflow-wrap:anywhere; background:#090a0d; border:1px solid var(--line); border-radius:var(--r-sm);
    padding:11px; margin:9px 0 0; font-size:12px; line-height:1.5; max-height:300px; overflow:auto; color:var(--muted)}
</style>
</head>
<body>
<svg width="0" height="0" style="position:absolute" aria-hidden="true">
  <defs>
    <g fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <symbol id="i-logo" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="2.5" fill="currentColor"/></symbol>
      <symbol id="i-gear" viewBox="0 0 24 24"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.6 1.6 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.6 1.6 0 0 0-2.7 1.1V21a2 2 0 1 1-4 0v-.1A1.6 1.6 0 0 0 7 19.4l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.6 1.6 0 0 0-1.1-2.7H3a2 2 0 1 1 0-4h.1A1.6 1.6 0 0 0 4.6 7l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.6 1.6 0 0 0 1.8.3H9a1.6 1.6 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.6 1.6 0 0 0 2.7 1.1l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.6 1.6 0 0 0-.3 1.8V9a1.6 1.6 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.6 1.6 0 0 0-1.5 1z"/></symbol>
      <symbol id="i-play" viewBox="0 0 24 24"><path d="M7 5l12 7-12 7z" fill="currentColor" stroke="none"/></symbol>
      <symbol id="i-pause" viewBox="0 0 24 24"><path d="M9 5v14M15 5v14"/></symbol>
      <symbol id="i-stop" viewBox="0 0 24 24"><rect x="6" y="6" width="12" height="12" rx="2"/></symbol>
      <symbol id="i-prev" viewBox="0 0 24 24"><path d="M18 5v14M16 12L6 5v14z" fill="currentColor"/></symbol>
      <symbol id="i-next" viewBox="0 0 24 24"><path d="M6 5v14M8 12l10-7v14z" fill="currentColor"/></symbol>
      <symbol id="i-vup" viewBox="0 0 24 24"><path d="M4 9v6h4l5 4V5L8 9zM16 9a3 3 0 0 1 0 6M19 7a7 7 0 0 1 0 10"/></symbol>
      <symbol id="i-vdown" viewBox="0 0 24 24"><path d="M4 9v6h4l5 4V5L8 9zM16 9a3 3 0 0 1 0 6"/></symbol>
      <symbol id="i-mute" viewBox="0 0 24 24"><path d="M4 9v6h4l5 4V5L8 9zM21 9l-6 6M15 9l6 6"/></symbol>
      <symbol id="i-back15" viewBox="0 0 24 24"><path d="M11 5L5 9l6 4V5z" fill="currentColor"/><path d="M7 9a8 8 0 1 1-2 5"/></symbol>
      <symbol id="i-fwd15" viewBox="0 0 24 24"><path d="M13 5l6 4-6 4V5z" fill="currentColor"/><path d="M17 9a8 8 0 1 0 2 5"/></symbol>
      <symbol id="i-bolt" viewBox="0 0 24 24"><path d="M13 2L4 14h7l-1 8 9-12h-7z" fill="currentColor"/></symbol>
      <symbol id="i-search" viewBox="0 0 24 24"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4-4"/></symbol>
      <symbol id="i-folder" viewBox="0 0 24 24"><path d="M3 7a2 2 0 0 1 2-2h4l2 2h6a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/></symbol>
      <symbol id="i-film" viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="16" rx="2"/><path d="M7 4v16M17 4v16M3 9h4M3 15h4M17 9h4M17 15h4"/></symbol>
      <symbol id="i-chev" viewBox="0 0 24 24"><path d="M9 6l6 6-6 6"/></symbol>
      <symbol id="i-back" viewBox="0 0 24 24"><path d="M15 6l-6 6 6 6"/></symbol>
      <symbol id="i-hdmi" viewBox="0 0 24 24"><path d="M4 9h16l-2 4H6zM8 13v3M16 13v3M10 16h4"/></symbol>
      <symbol id="i-screen" viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="13" rx="2"/><path d="M8 21h8M12 17v4"/></symbol>
      <symbol id="i-run" viewBox="0 0 24 24"><path d="M5 4l14 8-14 8z" fill="currentColor" stroke="none"/></symbol>
    </g>
  </defs>
</svg>

<main class="app">
  <header class="topbar">
    <div class="brand">
      <span class="logo"><svg><use href="#i-logo"/></svg></span>
      <h1>Tleilax Control Center</h1>
    </div>
    <div class="topbar-right">
      <span class="status" id="host"><span class="dot"></span>offline</span>
      <button class="icon-btn" id="settingsBtn" aria-label="Settings"><svg><use href="#i-gear"/></svg></button>
    </div>
  </header>

  <section class="card" id="settings" hidden>
    <label class="field-label" for="token">Access token</label>
    <div class="row">
      <input id="token" type="password" placeholder="Token" value="__TOKEN__">
      <button id="saveToken" class="btn" style="width:auto; padding:0 18px">Save</button>
    </div>
  </section>

  <section class="card">
    <div class="card-head">
      <span class="eyebrow">Now Playing</span>
      <div class="chips" id="nowChips" style="margin-top:0"></div>
    </div>
    <div class="now-title" id="nowTitle">Loading…</div>
    <div class="now-sub" id="nowSub"></div>
    <div class="progress"><div class="progress-bar" id="nowProgress"></div></div>
    <div class="time-row"><span id="nowPos">0:00</span><span id="nowDur">0:00</span></div>

    <div class="transport">
      <button class="t-btn" data-jellyfin="previousEpisode"><svg><use href="#i-prev"/></svg>Prev Ep</button>
      <button class="t-btn" data-seek="-15"><svg><use href="#i-back15"/></svg>-15s</button>
      <button class="t-btn lg" id="playPause" data-jellyfin="unpause"><svg><use href="#i-play"/></svg></button>
      <button class="t-btn" data-seek="15"><svg><use href="#i-fwd15"/></svg>+15s</button>
      <button class="t-btn" data-jellyfin="nextEpisode"><svg><use href="#i-next"/></svg>Next Ep</button>
    </div>

    <div class="group-label">Volume</div>
    <div class="grid g3">
      <button class="btn" data-jellyfin="volumeDown"><svg><use href="#i-vdown"/></svg>Down</button>
      <button class="btn" data-jellyfin="mute"><svg><use href="#i-mute"/></svg>Mute</button>
      <button class="btn" data-jellyfin="volumeUp"><svg><use href="#i-vup"/></svg>Up</button>
    </div>

    <div class="group-label">Seek</div>
    <div class="grid g4">
      <button class="btn" data-seek="-60">-60s</button>
      <button class="btn" data-seek="-15">-15s</button>
      <button class="btn" data-seek="15">+15s</button>
      <button class="btn" data-seek="60">+60s</button>
    </div>

    <div class="group-label">Quick</div>
    <div class="grid g2">
      <button class="btn danger" data-jellyfin="stop"><svg><use href="#i-stop"/></svg>Stop</button>
      <button class="btn primary" data-jellyfin="durararaStart"><svg><use href="#i-bolt"/></svg>Durarara!! E1</button>
    </div>
  </section>

  <section class="card">
    <div class="card-head"><span class="eyebrow">Library</span></div>
    <div class="row">
      <input id="search" placeholder="Search Jellyfin">
      <button id="searchBtn" class="btn" style="width:auto; padding:0 16px"><svg><use href="#i-search"/></svg></button>
    </div>
    <div class="grid g2" style="margin-top:9px">
      <button id="collectionsBtn" class="btn"><svg><use href="#i-folder"/></svg>Collections</button>
      <button id="backBtn" class="btn"><svg><use href="#i-back"/></svg>Back</button>
    </div>
    <div id="browser" class="list" style="margin-top:11px"><div class="hint">Open collections or search.</div></div>
  </section>

  <section class="card">
    <div class="card-head"><span class="eyebrow">System</span><span class="chip" id="displayState">—</span></div>
    <div class="group-label" style="margin-top:0">Display Output</div>
    <div class="grid g3">
      <button class="btn" data-display="airplay"><svg><use href="#i-screen"/></svg>AirPlay</button>
      <button class="btn" data-display="jellyfin"><svg><use href="#i-film"/></svg>Jellyfin</button>
      <button class="btn warn" data-display="off">Off</button>
    </div>
    <div class="group-label">Pi Audio</div>
    <button id="hdmi" class="btn"><svg><use href="#i-hdmi"/></svg>Route Audio To HDMI</button>
  </section>

  <section class="card">
    <div class="card-head"><span class="eyebrow">Ask Codex</span></div>
    <textarea id="prompt" placeholder="Tell Codex what to do on this Pi…"></textarea>
    <button id="runCodex" class="btn primary" style="margin-top:9px"><svg><use href="#i-run"/></svg>Run Task</button>
  </section>

  <section class="card">
    <div class="card-head"><span class="eyebrow">Jobs</span></div>
    <div id="jobs"><div class="hint">No jobs yet.</div></div>
  </section>
</main>

<script>
const $ = id => document.getElementById(id);
const tokenEl = $('token');
if (!tokenEl.value) tokenEl.value = localStorage.getItem('remoteToken') || '';
$('saveToken').onclick = () => {
  localStorage.setItem('remoteToken', tokenEl.value.trim());
  $('settings').hidden = true;
  refresh();
};
$('settingsBtn').onclick = () => { $('settings').hidden = !$('settings').hidden; };
function token() { return tokenEl.value.trim(); }
function icon(name) { return '<svg aria-hidden="true"><use href="#i-' + name + '"/></svg>'; }
function fmt(t) {
  if (!t || t < 0) return '0:00';
  t = Math.floor(t);
  const h = Math.floor(t / 3600), m = Math.floor((t % 3600) / 60), s = t % 60;
  const mm = h ? String(m).padStart(2, '0') : m;
  return (h ? h + ':' : '') + mm + ':' + String(s).padStart(2, '0');
}
async function api(path, options = {}) {
  const sep = path.includes('?') ? '&' : '?';
  const res = await fetch(path + sep + 'token=' + encodeURIComponent(token()), {
    ...options,
    headers: {'Content-Type': 'application/json', ...(options.headers || {})}
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || data.message || res.statusText);
  return data;
}
async function post(path, body) {
  return api(path, {method:'POST', body:JSON.stringify(body || {})});
}
function itemLabel(item) {
  const bits = [];
  if (item.seriesName) bits.push(item.seriesName);
  if (item.parentIndexNumber || item.indexNumber) bits.push(`S${item.parentIndexNumber || '?'}E${item.indexNumber || '?'}`);
  if (item.productionYear) bits.push(item.productionYear);
  return bits.join(' - ') || item.type || '';
}
function setNowChips(chips) { $('nowChips').innerHTML = chips.join(''); }
async function refresh() {
  const host = $('host');
  try {
    const s = await api('/api/status');
    host.innerHTML = '<span class="dot"></span>' + escapeHtml(s.host + ' : ' + s.port);
    host.classList.add('online');

    const item = s.jellyfin && s.jellyfin.item;
    const play = (s.jellyfin && s.jellyfin.playState) || {};
    const playPause = $('playPause');
    if (item) {
      const se = (item.ParentIndexNumber || item.IndexNumber)
        ? `S${item.ParentIndexNumber || '?'} · E${item.IndexNumber || '?'}` : '';
      const series = item.SeriesName;
      $('nowTitle').textContent = series || item.Name || 'Unknown';
      $('nowSub').textContent = series ? [se, item.Name].filter(Boolean).join('  —  ') : se;
      const pos = Number(play.PositionTicks || 0) / 1e7, dur = Number(item.RunTimeTicks || 0) / 1e7;
      $('nowProgress').style.width = dur ? Math.min(100, pos / dur * 100) + '%' : '0%';
      $('nowPos').textContent = fmt(pos);
      $('nowDur').textContent = fmt(dur);
      const paused = !!play.IsPaused;
      const chips = [paused
        ? '<span class="chip">Paused</span>'
        : '<span class="chip live"><span class="cdot"></span>Playing</span>'];
      if (play.VolumeLevel != null) chips.push(`<span class="chip">Vol ${play.VolumeLevel}</span>`);
      if (play.IsMuted) chips.push('<span class="chip">Muted</span>');
      setNowChips(chips);
      playPause.dataset.jellyfin = paused ? 'unpause' : 'pause';
      playPause.innerHTML = icon(paused ? 'play' : 'pause');
    } else {
      $('nowTitle').textContent = 'Nothing playing';
      $('nowSub').textContent = '';
      $('nowProgress').style.width = '0%';
      $('nowPos').textContent = $('nowDur').textContent = '0:00';
      setNowChips(['<span class="chip">Idle</span>']);
      playPause.dataset.jellyfin = 'unpause';
      playPause.innerHTML = icon('play');
    }

    const display = s.display || {};
    $('displayState').textContent = display.mode || 'unknown';
    document.querySelectorAll('[data-display]').forEach(btn => {
      const m = btn.dataset.display;
      btn.classList.toggle('active', m === display.mode || (m === 'off' && display.mode === 'idle'));
    });

    const jobs = s.jobs || [];
    $('jobs').innerHTML = jobs.length ? jobs.map(j => `
      <div class="job">
        <div class="job-head">
          <span class="badge ${escapeHtml(j.status)}">${escapeHtml(j.status)}</span>
          <span class="job-time">${new Date(j.createdAt * 1000).toLocaleTimeString()}</span>
        </div>
        <div class="job-prompt">${escapeHtml(j.prompt || '')}</div>
        ${j.output ? `<pre>${escapeHtml(j.output)}</pre>` : ''}
      </div>`).join('') : '<div class="hint">No jobs yet.</div>';
  } catch (e) {
    host.classList.remove('online');
    host.innerHTML = '<span class="dot"></span>offline';
    $('nowTitle').textContent = e.message;
  }
}
function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
}
document.querySelectorAll('[data-jellyfin]').forEach(btn => {
  btn.onclick = async () => { await post('/api/jellyfin', {action: btn.dataset.jellyfin}); await refresh(); };
});
document.querySelectorAll('[data-seek]').forEach(btn => {
  btn.onclick = async () => { await post('/api/jellyfin', {action:'seek', seconds:Number(btn.dataset.seek)}); await refresh(); };
});
document.querySelectorAll('[data-display]').forEach(btn => {
  btn.onclick = async () => { alert((await post('/api/display', {mode: btn.dataset.display})).message); await refresh(); };
});
$('hdmi').onclick = async () => { alert((await post('/api/audio/hdmi')).message); await refresh(); };
$('runCodex').onclick = async () => {
  const prompt = $('prompt').value.trim();
  if (!prompt) return;
  await post('/api/codex', {prompt});
  $('prompt').value = '';
  await refresh();
};
const stack = [];
async function loadCollections() {
  stack.length = 0;
  const data = await api('/api/jellyfin/views');
  renderItems(data.items, 'views');
}
async function loadChildren(parentId, title, push = true) {
  if (push) stack.push({parentId, title});
  const data = await api('/api/jellyfin/items?parentId=' + encodeURIComponent(parentId));
  renderItems(data.items, 'items');
}
function renderItems(items) {
  const el = $('browser');
  if (!items.length) {
    el.innerHTML = '<div class="hint">No results.</div>';
    return;
  }
  el.innerHTML = items.map(item => {
    const playable = item.type === 'Episode' || item.type === 'Movie';
    const sub = itemLabel(item);
    return `
    <button class="item" data-id="${escapeHtml(item.id)}" data-type="${escapeHtml(item.type || '')}">
      <span class="ico">${icon(playable ? 'film' : 'folder')}</span>
      <span class="meta">
        <span class="nm">${escapeHtml(item.name || 'Untitled')}</span>
        ${sub ? `<span class="sub">${escapeHtml(sub)}</span>` : ''}
      </span>
      <span class="chev">${icon(playable ? 'play' : 'chev')}</span>
    </button>`;
  }).join('');
  el.querySelectorAll('.item').forEach((btn, index) => {
    const item = items[index];
    btn.onclick = async () => {
      if (item.type === 'Episode' || item.type === 'Movie') {
        await post('/api/jellyfin', {action:'playItem', itemId:item.id});
        await refresh();
      } else {
        await loadChildren(item.id, item.name);
      }
    };
  });
}
$('collectionsBtn').onclick = loadCollections;
$('searchBtn').onclick = async () => {
  const q = $('search').value.trim();
  const data = await api('/api/jellyfin/search?q=' + encodeURIComponent(q));
  renderItems(data.items, 'search');
};
$('search').addEventListener('keydown', event => {
  if (event.key === 'Enter') $('searchBtn').click();
});
$('backBtn').onclick = async () => {
  stack.pop();
  const previous = stack[stack.length - 1];
  if (!previous) return loadCollections();
  await loadChildren(previous.parentId, previous.title, false);
};
setInterval(refresh, 5000);
refresh();
</script>
</body>
</html>
"""


def main():
    ip = bind_address()
    httpd = ThreadingHTTPServer((ip, PORT), Handler)
    if os.environ.get("REMOTE_PRINT_TOKEN", "1") == "1":
        url = f"http://{ip}:{PORT}/?token={TOKEN}"
    else:
        url = f"http://{ip}:{PORT}/"
    print(f"Tleilax Control Center listening on {url}", flush=True)
    httpd.serve_forever()


if __name__ == "__main__":
    main()
