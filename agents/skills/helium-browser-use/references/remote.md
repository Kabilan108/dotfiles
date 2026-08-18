# Remote Helium Browser Use

Use this when the agent is running on a remote host, such as `sietch`, and the visible Helium browser is running on the user's local machine.

## Mental Model

CDP is forwarded from the browser-host machine to the remote agent host. The browser still runs locally, so page URLs are resolved from the browser-host machine's network view.

For dev servers running on `sietch`, prefer Tailscale-reachable URLs, such as:

```bash
http://sietch:<port>
http://<sietch-tailscale-ip>:<port>
```

Do not assume `http://127.0.0.1:<port>` means the remote host. In the browser, loopback means the browser-host machine unless a separate application tunnel is also set up.

## From The Remote Agent Host

First check whether the forwarded CDP endpoint already exists:

```bash
remote_port="${HELIUM_REMOTE_CDP_PORT:-9223}"
curl -fsS "http://127.0.0.1:${remote_port}/json/version"
agent-browser --cdp "$remote_port" get cdp-url --json
```

If this succeeds, use the normal `helium-browser-use` tab discipline with `agent-browser --cdp "$remote_port" ...`.

If this fails, do not try to launch Helium on the remote host. Ask the browser-host machine to start or repair the reverse tunnel.

For mid-session failures, distinguish "no listener" from "stale listener":

```bash
curl -m 5 -fsS "http://127.0.0.1:${remote_port}/json/version"
ss -ltnp | rg ":${remote_port}\b" || true
```

If the port is listening but `/json/version` hangs or times out, the reverse tunnel or browser-side CDP endpoint is stale. Stop long-running browser/profiling work, ask the user to rerun `helium-browser-tunnel sietch` on the browser-host machine, then re-verify with `/json/version` and `agent-browser --cdp "$remote_port" get cdp-url --json` before continuing.

## From The Browser-Host Machine

Confirm local Helium CDP is reachable:

```bash
local_port="${HELIUM_AGENTS_CDP_PORT:-9222}"
curl -fsS "http://127.0.0.1:${local_port}/json/version"
```

Start or repair the reverse SSH tunnel:

```bash
helium-browser-tunnel sietch
```

The helper keeps a stable tmux target:

```text
helium-browser-use:sietch
```

It forwards remote `127.0.0.1:9223` on `sietch` to local `127.0.0.1:9222`.

## Manual Tunnel

If the helper is unavailable, start the tunnel manually from the browser-host machine:

```bash
tmux new-session -d -s helium-browser-use -n sietch \
  'ssh -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -R 127.0.0.1:9223:127.0.0.1:9222 sietch'
```

Then verify from `sietch`:

```bash
curl -fsS http://127.0.0.1:9223/json/version
agent-browser --cdp 9223 get cdp-url --json
```

## Safety

Keep the forwarded CDP endpoint bound to remote loopback. Do not use `0.0.0.0` or expose CDP on a public interface.

Do not close the tunnel while another agent is actively using the remote browser. Check the tmux pane and active agent work first.
