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
<title>Codex Remote</title>
<style>
  :root { color-scheme: dark; --bg:#101114; --panel:#1a1d22; --line:#313741; --text:#f1f3f5; --muted:#9ba3ad; --accent:#47c2a8; --warn:#ffb86c; }
  * { box-sizing: border-box; }
  body { margin:0; font-family: system-ui, -apple-system, Segoe UI, sans-serif; background:var(--bg); color:var(--text); }
  main { max-width: 760px; margin:0 auto; padding: 18px 14px 28px; }
  header { display:flex; justify-content:space-between; align-items:center; gap:12px; margin-bottom:14px; }
  h1 { font-size:22px; margin:0; letter-spacing:0; }
  .pill { border:1px solid var(--line); color:var(--muted); padding:6px 9px; border-radius:7px; font-size:13px; }
  section { border-top:1px solid var(--line); padding:16px 0; }
  h2 { font-size:15px; margin:0 0 10px; color:var(--muted); font-weight:650; }
  .grid { display:grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap:9px; }
  .grid.two { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  button { min-height:48px; border:1px solid var(--line); border-radius:8px; background:var(--panel); color:var(--text); font-size:15px; font-weight:650; }
  button.primary { background:var(--accent); color:#061411; border-color:var(--accent); }
  button.warn { color:var(--warn); }
  textarea, input { width:100%; border:1px solid var(--line); border-radius:8px; background:#0b0c0f; color:var(--text); padding:12px; font:inherit; }
  textarea { min-height:112px; resize:vertical; }
  .row { display:flex; gap:9px; align-items:center; }
  .row input { flex:1; }
  pre { white-space:pre-wrap; overflow-wrap:anywhere; background:#0b0c0f; border:1px solid var(--line); border-radius:8px; padding:12px; max-height:340px; overflow:auto; }
  .muted { color:var(--muted); }
  .job { border:1px solid var(--line); border-radius:8px; padding:10px; margin-top:9px; background:var(--panel); }
  .list { display:grid; gap:8px; }
  .item { text-align:left; min-height:54px; padding:9px 11px; display:block; width:100%; }
  .item small { display:block; color:var(--muted); font-weight:500; margin-top:3px; overflow-wrap:anywhere; }
</style>
</head>
<body>
<main>
  <header>
    <h1>Codex Remote</h1>
    <span class="pill" id="host">offline</span>
  </header>

  <section>
    <h2>Auth</h2>
    <div class="row">
      <input id="token" placeholder="Token" value="__TOKEN__">
      <button id="saveToken">Save</button>
    </div>
  </section>

  <section>
    <h2>Now Playing</h2>
    <pre id="now">Loading...</pre>
    <div class="grid">
      <button data-jellyfin="pause">Pause</button>
      <button data-jellyfin="unpause">Play</button>
      <button data-jellyfin="stop" class="warn">Stop</button>
      <button data-jellyfin="volumeDown">Vol -</button>
      <button data-jellyfin="mute">Mute</button>
      <button data-jellyfin="volumeUp">Vol +</button>
    </div>
    <div style="height:9px"></div>
    <div class="grid">
      <button data-seek="-60">-60s</button>
      <button data-seek="-15">-15s</button>
      <button data-seek="15">+15s</button>
      <button data-seek="60">+60s</button>
      <button data-jellyfin="previousEpisode">Prev Ep</button>
      <button data-jellyfin="nextEpisode">Next Ep</button>
    </div>
    <div style="height:9px"></div>
    <button class="primary" data-jellyfin="durararaStart" style="width:100%">Durarara!! S1E1 From Start</button>
  </section>

  <section>
    <h2>Library</h2>
    <div class="row">
      <input id="search" placeholder="Search Jellyfin">
      <button id="searchBtn">Search</button>
    </div>
    <div style="height:9px"></div>
    <div class="grid two">
      <button id="collectionsBtn">Collections</button>
      <button id="backBtn">Back</button>
    </div>
    <div style="height:9px"></div>
    <div id="browser" class="list muted">Open collections or search.</div>
  </section>

  <section>
    <h2>Pi Audio</h2>
    <button id="hdmi" class="primary" style="width:100%">Route Audio To HDMI</button>
  </section>

  <section>
    <h2>Ask Codex</h2>
    <textarea id="prompt" placeholder="Tell Codex what to do on this Pi..."></textarea>
    <div style="height:9px"></div>
    <button id="runCodex" class="primary" style="width:100%">Run Task</button>
  </section>

  <section>
    <h2>Jobs</h2>
    <div id="jobs" class="muted">No jobs yet.</div>
  </section>
</main>

<script>
const tokenEl = document.getElementById('token');
if (!tokenEl.value) tokenEl.value = localStorage.getItem('remoteToken') || '';
document.getElementById('saveToken').onclick = () => {
  localStorage.setItem('remoteToken', tokenEl.value.trim());
  refresh();
};
function token() { return tokenEl.value.trim(); }
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
async function refresh() {
  try {
    const s = await api('/api/status');
    document.getElementById('host').textContent = s.host + ' : ' + s.port;
    const item = s.jellyfin && s.jellyfin.item;
    const play = s.jellyfin && s.jellyfin.playState;
    document.getElementById('now').textContent = item
      ? `${item.SeriesName || ''} S${item.ParentIndexNumber || '?'}E${item.IndexNumber || '?'}\n${item.Name}\nPaused: ${play && play.IsPaused ? 'yes' : 'no'}  Volume: ${play && play.VolumeLevel || '?'}`
      : 'Nothing playing';
    document.getElementById('jobs').innerHTML = s.jobs.length ? s.jobs.map(j => `
      <div class="job">
        <strong>${j.status}</strong> ${new Date(j.createdAt * 1000).toLocaleTimeString()}<br>
        <span class="muted">${escapeHtml(j.prompt || '')}</span>
        ${j.output ? `<pre>${escapeHtml(j.output)}</pre>` : ''}
      </div>`).join('') : 'No jobs yet.';
  } catch (e) {
    document.getElementById('now').textContent = e.message;
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
document.getElementById('hdmi').onclick = async () => { alert((await post('/api/audio/hdmi')).message); await refresh(); };
document.getElementById('runCodex').onclick = async () => {
  const prompt = document.getElementById('prompt').value.trim();
  if (!prompt) return;
  await post('/api/codex', {prompt});
  document.getElementById('prompt').value = '';
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
  const el = document.getElementById('browser');
  if (!items.length) {
    el.textContent = 'No results.';
    return;
  }
  el.innerHTML = items.map(item => `
    <button class="item" data-id="${escapeHtml(item.id)}" data-type="${escapeHtml(item.type || '')}">
      ${escapeHtml(item.name || 'Untitled')}
      <small>${escapeHtml(itemLabel(item))}</small>
    </button>
  `).join('');
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
document.getElementById('collectionsBtn').onclick = loadCollections;
document.getElementById('searchBtn').onclick = async () => {
  const q = document.getElementById('search').value.trim();
  const data = await api('/api/jellyfin/search?q=' + encodeURIComponent(q));
  renderItems(data.items, 'search');
};
document.getElementById('search').addEventListener('keydown', event => {
  if (event.key === 'Enter') document.getElementById('searchBtn').click();
});
document.getElementById('backBtn').onclick = async () => {
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
    print(f"Codex Remote listening on {url}", flush=True)
    httpd.serve_forever()


if __name__ == "__main__":
    main()
