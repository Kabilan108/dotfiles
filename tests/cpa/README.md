# CPA tests

These tests run the CPA gateway that the current checkout builds for sietch. They cover the unit's preStart, the two nginx fronts, the management API, logging and the unit's sandbox. CPA is CLIProxyAPI, packaged in `packages/cliproxyapi.nix` and configured in `modules/nixos/selfhost/cliproxyapi.nix`.

```bash
tests/cpa/run.sh             # every check except the browser one
tests/cpa/run.sh --browser   # also log into the dashboard with agent-browser
tests/cpa/run.sh --keep      # keep the temp directory after a pass
```

The script exits 0 only when every check passes. It prints `PASS` or `FAIL` per check, a count per section and a final `RESULT` line. After a failure it keeps its temp directory and prints the path. Each section's logs are in `out/` there: CPA's stdout, nginx, the probes, the user unit's journal and the browser screenshots.

Run it on sietch or jacurutu as a normal user, with Nix and a running systemd user manager. It needs no sudo, no secrets and no rebuild.

## What it runs

`resolve.nix` is applied to `nixosConfigurations.sietch` in this checkout. It returns the CPA binary, the management panel, the `cliproxyapi` unit's preStart and unit text, nginx and the generated `nginx.conf`. It also returns yq and a Python with `websockets`. `run.sh` then builds those derivations, so a branch that bumps CPA compiles and tests its own build. Before any test runs, the script prints the store paths it resolved.

Each run uses fresh loopback ports, a temp state directory and dummy keys. It never touches `/var/lib/cliproxyapi`, the running `cliproxyapi` or `nginx` services, real keys or real auth files. A small Python server on loopback plays the upstream provider. It lists one model and streams four chunks one second apart.

## Checks

**preStart on a missing config.** preStart writes a fresh config with `allow-remote: false`, file logging off and round-robin routing. The script reads CPA's port from this config. It then checks that the fronts proxy to that port.

**preStart on a legacy config.** The test config has the live file's legacy layout, with `management: null` and `logging-to-file: true`. A control run first starts CPA on it without preStart and checks that CPA writes `main.log`. That proves the logging check below can fail. preStart then has to write the `.pre-v8` backup, set `management.allow-remote: false`, drop the top-level `logging-to-file` and turn off `observability.logs.logging-to-file`.

**CPA direct.** These checks talk to CPA on its own port, the way sera does. A forwarded tailnet client gets 403 from `allow-remote: false`. The test config trusts loopback proxies so a request can pose as one. Loopback management calls and `/management.html` get 200.

**nginx fronts.** The script copies the generated `nginx.conf` and changes only its listen ports, the `proxy_pass` port, the pid file and the temp paths. `nginx -t` has to accept the copy. The script fails if a `listen` is not a loopback port it can remap.

**Models front, 8320 on sietch.** It passes `/healthz`, `/v1/models`, count_tokens, `/v1beta/models`, chat completions and `/backend-api/codex/responses`. OpenAI and Claude SSE streams have to arrive spread out, not buffered. Codex Responses websockets on `/v1/responses` and `/backend-api/codex/responses` have to upgrade with 101 and stream a whole turn. The front refuses 24 management and callback paths, including encoded, doubled-slash and dot-segment traversals, and never returns management data for them.

**Admin front, 8321 on sietch.** `/` returns a relative 302 to `/management.html`. The served panel matches the pinned file byte for byte. The management API works on `/v8/management` and `/v0/management`, reads and writes. A missing key and a wrong key each get 401. `GET /v1/models` passes for the dashboard's model list. Other methods on it get 403 or 405. nginx itself refuses 16 inference and other paths. The check looks for nginx's own 404 page, because CPA also 404s a GET on its POST routes. A websocket upgrade on `/v1/responses` gets 404.

**Per-credential websockets flag.** It uploads a dummy Codex auth file and sends `PATCH /v8/management/credentials/fields` with `websockets: true`. The flag has to show in the credential listing and in the auth file on disk.

**Logging.** CPA's own log lines, such as `responses websocket: client connected`, go to stdout. No `main.log` appears in `logs/` or `auth/logs/`. CPA writes to `./logs` when that directory exists and is writable, and to `<auth-dir>/logs` otherwise. Any other file in those directories fails the check, except CPA's per-request error logs, described below.

**Sandboxed user unit.** The script runs preStart and CPA with `systemd-run --user`. It passes every `[Service]` line of the generated `cliproxyapi.service`, so new sandbox settings are tested without editing the script. It drops `User`, `Group`, `EnvironmentFile`, `Restart` and `RestartSec`. It replaces `ExecStart`, `StateDirectory`, `WorkingDirectory` and `CLIPROXY_CONFIG` with test values. `ProtectHome=true` becomes `ProtectHome=tmpfs` plus `BindPaths=` on the state directory. A user unit's state directory lives under home, and `true` would hide it. Under the sandbox, the unit has to start, preStart has to fix the config and CPA has to write its config and auth files. A websocket turn has to complete. The journal has to show CPA's log lines and no denials, and no `main.log` may appear.

**Dashboard, with `--browser`.** agent-browser opens the admin front's `/` in its own session and logs in with the dummy key. Management Center Info has to list `test-model` under Available Models. Auth Files has to list the dummy Codex credential. Screenshots go to `out/`.

## Known CPA behavior

With request logging off, CPA still writes `error-*.log` to its logs directory for every request on its API routes that fails with 400 or above. Each file holds the request body, the headers with the key partly masked, and the response. No config key turns this off. `error-logs-max-files` caps the count, 10 by default. In the tests, the forwarded `HEAD /v1/models` 404 writes one. On sietch these files land in `/var/lib/cliproxyapi/logs`. The logging check allows them and prints their paths.

## What it cannot check

- Real logins. OAuth flows and real provider credentials are out of scope. The upstream is a local dummy.
- The real upstream websocket to OpenAI. The test turn goes through CPA's translation to the dummy chat upstream. The `websockets: true` flag is checked as stored, not as a live upstream socket.
- Tailscale Serve. TLS, the `svc:cliproxyapi` and `svc:cpa-admin` services and their hostnames are not involved. The fronts are hit on loopback.
- The tailnet policy. Which devices can reach which service lives in the Tailscale admin console.
- The system unit as `User=cliproxyapi`, `ProtectHome=true` exactly, the agenix environment file, and `StateDirectory` taking over an existing tree. The user unit stands in for these.
- Other vhosts in the generated `nginx.conf`. They run on spare ports and no test calls them.
