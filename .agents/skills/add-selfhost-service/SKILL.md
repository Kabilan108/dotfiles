---
name: add-selfhost-service
description: Add a new persistent self-hosted service on sietch, exposed on the tailnet as <name>.sole-pierce.ts.net via Tailscale Services. Use when the user asks to host, self-host, deploy, or expose a new service (web app, API, MCP server, media tool) on sietch or "my server". Covers the nix module, agenix secrets, the tailscale admin-console steps, and verification.
---

# Add a self-hosted service on sietch

Every persistent service on sietch follows one architecture:

- backend runs as a systemd unit (native NixOS module or `oci-containers`), bound to **127.0.0.1 only**
- tailscaled terminates TLS and publishes it as a Tailscale Service: `https://<name>.sole-pierce.ts.net`
- no firewall ports open, no reverse proxy, no manual certs
- secrets come from agenix (`secrets/selfhost/*.age`)

All service definitions live in `modules/nixos/selfhost/` (imported by `machines/sietch/default.nix`). Read `default.nix` there first — it defines `selfhost.tailnetServices` and applies serve config via the tailscale CLI.

## Steps

### 1. Pick backend type and port

- Prefer a **native NixOS module** (`services.<name>`) when nixpkgs has one — better integration, no image drift.
- For your own projects, expose a `nixosModules.default` from the project's flake and consume it as a flake input (see `siren.nix` + the siren repo's flake; updates = `nix flake update <input>`).
- Otherwise use `virtualisation.oci-containers.containers.<name>` (backend is docker on this host; see `executor.nix`). Digest-pin third-party images (`update-image-pins` skill).
- Pick a free localhost port in the 83xx range (`ss -tln | grep 83`). Current allocations: 8096 jellyfin, 8222 vaultwarden, 8301 siren, 8302 executor.

### 2. Secrets (if the service needs any)

Add an entry to `secrets.nix`:

```nix
"secrets/selfhost/<name>-env.age".publicKeys = [ sietch ];
```

Then ask the USER to populate it (never handle plaintext yourself):

```
agenix -e secrets/selfhost/<name>-env.age    # contents: KEY=value lines
```

### 3. Write the module

Create `modules/nixos/selfhost/<name>.nix` and add it to `imports` in `modules/nixos/selfhost/default.nix`. Container template:

```nix
{ config, ... }:
{
  age.secrets.selfhost-<name>-env.file = ../../../secrets/selfhost/<name>-env.age;

  selfhost.tailnetServices.<name>.port = 83XX;

  virtualisation.oci-containers.containers.<name> = {
    image = "docker.io/kabilan108/<name>:latest";
    ports = [ "127.0.0.1:83XX:<container-port>" ];
    # forward secrets by NAME via systemd EnvironmentFile (quote-safe);
    # do NOT use environmentFiles (docker --env-file keeps literal quotes)
    extraOptions = [
      "--env"
      "SOME_API_KEY"
    ];
    # GPU if needed: "--device=nvidia.com/gpu=all" (CDI is enabled)
  };

  systemd.services.docker-<name>.serviceConfig.EnvironmentFile =
    config.age.secrets.selfhost-<name>-env.path;
}
```

For a native module, set its listen address/port to `127.0.0.1:83XX` and point `selfhost.tailnetServices.<name>.port` at it (see `vaultwarden.nix` and `jellyfin.nix`).

Filesystem access for the service user follows the rules in `docs/security-hardening.md` ("Selfhost service permission model"): ownership for the owner, group for peers, tmpfiles `A+` ACLs for the exception (e.g. siren on the shared HF cache).

### 4. Tailscale admin console (USER must do this — not in the repo)

Ask the user to:

1. **Services page**: create a Service named exactly `<name>` (the `tailnetServices` attr name), port `tcp:443`.
2. **Policy file**: add `"svc:<name>": ["tag:server"]` under `autoApprovers.services`, and add `svc:<name>` to the dst list of the relevant `grants` (at minimum the `autogroup:member` grant; `tag:agent` if agents need it).

Without these the advertisement sits pending and connections time out.

### 5. Build, switch, verify

```sh
git add -A            # flake ignores untracked files
nix build .#nixosConfigurations.sietch.config.system.build.toplevel --no-link
```

Then ask the user to run the switch (needs interactive sudo):

```
! sudo nixos-rebuild switch --flake ~/dotfiles#sietch
```

Verify (operator is set, so no sudo needed):

```sh
systemctl is-active docker-<name> tailscale-serve-config
tailscale serve status --json | jq '.Services'   # expect "svc:<name>" with {"443": {"HTTPS": true}}
curl -sS -o /dev/null -w '%{http_code}\n' https://<name>.sole-pierce.ts.net/
```

## Gotchas

- The tailscale services **config file** (`serve set-config`) cannot express TLS termination — that's why `default.nix` drives the `tailscale serve --service` CLI. Don't "simplify" it back to a config file.
- Generated container units use `--pull missing`: locally built/tagged images work as-is, and images are never auto-updated. That's deliberate (supply-chain caution) — updating = pull/build a new image, then `systemctl restart docker-<name>`.
- Removing a service from nix auto-clears its serve config on the next switch, but the admin-console Service definition and policy entries must be removed by the user manually.
- A 502 from the service URL means the backend port is wrong — check what the app actually listens on (`docker exec <name> netstat -tln`), not what old configs claim.
- For root-owned file operations without sudo (state copies, chowns), use a helper container: `docker run --rm -v <vol-or-dir>:/src -v /var/lib/<name>:/dst alpine sh -c 'cp -a /src/. /dst/ && chown -R <uid>:<gid> /dst'`.
- Backups for service state under `/var/lib` are not yet implemented — see github.com/Kabilan108/dotfiles/issues/7 before storing anything irreplaceable.
