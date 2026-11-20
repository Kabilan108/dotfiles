# CPA reaches the tailnet only through loopback fronts, and clients use a tailnet-only shared key

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

- CPA (CLIProxyAPI) runs on sietch behind Tailscale Services and serves inference, including an OpenAI-compatible Responses API, and management on one listener, `127.0.0.1:8317`. The tailscale policy limits who reaches it.
- Tailscale Serve proxies from loopback, so CPA sees every tailnet request as local, and `allow-remote: false` alone can't refuse it. Tailscale Serve terminates TLS, so an absolute redirect from nginx would name the wrong scheme and host.
- The management dashboard calls `/v8/management` and probes `/v0/management` for old backends. Its model list card reads `GET /v1/models`. The panel is a separate release asset from the backend.
- SSE streams and Codex's Responses websocket (`GET /v1/responses`) stay open for whole turns. Codex's websocket transport to CPA needs CPA 8.0.46 or later (PR #46), and CPA uses an upstream websocket only for Codex auth files that have `"websockets": true`.
- CPA's `auth-files` response carries raw API keys and personal details, and its `api-call` result includes every upstream response header, cookies included. sera's code can be edited by agents.

## Decision

- Two nginx vhosts listen on loopback. Port 8320 (Tailscale Service `cliproxyapi`) forwards `/healthz` and the inference prefixes `/v1/`, `/v1beta/`, `/openai/v1/` and `/backend-api/codex/`. Port 8321 (`cpa-admin`) forwards `/management.html`, `/v0/management/`, `/v8/management/` and `GET /v1/models` only. Everything else gets 404 from nginx. CPA still checks the management key.
- The fronts pass websocket upgrades, turn buffering and caching off, allow 1 h read and send timeouts and set no body limit. `absolute_redirect` is off.
- Local callers use CPA directly. `cpa-usage-front` holds the management key from the CPA environment file, runs as a dynamic user, listens on `127.0.0.1:8322` with `IPAddressAllow=localhost`, and serves sera's account list and usage lookups, so sera itself never holds the key. From `auth-files` it returns only id, auth_index, provider, disabled and the ChatGPT account id; from `api-call` only the status code and body.
- `passthru.managementPanel` pins `management.html`, and the panel and backend are updated together; the service serves that immutable asset.
- `claude-cpa` and `codex-cpa` use the shared key `claudex-tailnet`, which is not treated as a secret. The wrappers call `~/.local/bin/claude` and `~/.local/bin/codex` by absolute path so they never resolve back to themselves through PATH.
- `agents/codex/config.toml` defines `[model_providers.cpa]` with `supports_websockets = true` but does not make it the default. Only `codex-cpa` uses it: it exports `CPA_API_KEY` and passes `-c 'model_provider="cpa"'` at the root, so it applies to every subcommand, including the `app-server` and `exec` modes T3 and scripts use.

## Consequences

- A new CPA route reaches the tailnet only after it is added to one front. `tests/cpa` checks both fronts, including refused management and traversal paths.
- Access control for inference rests on the tailnet policy, not the key.
- Bumping CPA without the panel, or the reverse, can leave them mismatched. Downgrading CPA below 8.0.46 breaks `codex-cpa`.
- Plain `codex` keeps using OpenAI auth directly. Every Codex auth file added to CPA needs `"websockets": true`, or websocket sessions through CPA fall back or fail.

## Where

- `modules/nixos/selfhost/cliproxyapi.nix` (`inferencePrefixes`, `adminPrefixes`, `cpaProxy`, `loopbackVhost`, `services.nginx`)
- `modules/nixos/selfhost/cpa-usage-front.nix`
- `packages/cpa-usage-front.py` (`accounts`, `usage`)
- `packages/cliproxyapi.nix` (`passthru.managementPanel`)
- `modules/home/cpa-clients.nix` (`claude-cpa`, `codex-cpa`)
- `agents/codex/config.toml` (`[model_providers.cpa]`, `supports_websockets`)
