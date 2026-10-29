# AGENTS.md

This is my (Tony's) dotfiles flake. It is a shared configuration for my fleet machines.

Primarily, it declares how my sietch, jacurutu, and tleilax machines should be configured
and set up.

It includes a suite of custom tools, bash scripts, and a custom quickshell desktop

The main branch is `nixos`.

sietch and jacurutu are built from the root `flake.nix`. tleilax is built from the
separate flake in `raspi/`, which has its own `raspi/flake.lock`. Updating the root
flake's inputs does not update tleilax; bump `raspi/flake.lock` too.

## Self-Hosted Services

`sietch` and `tleilax` are my self-hosting boxes. different services are configured
per-machine.

all self-hosted services are managed as tailscale services. refer to the `add-selfhost-service`
skill when setting up a new service.

if you need to update images for self-hosted containers, refer to the `update-image-pins`
skill and `bin/image-pins`.

## Rules

- Give every systemd timer an explicit `RandomizedDelaySec` appropriate to its latency
  requirements to avoid thundering-herd workload spikes.
- Never launch Zen (or another Firefox-based browser) with `--remote-debugging-port` or
  `--marionette` against a real profile. Automation mode can leave test prefs in
  `prefs.js` that disable Safe Browsing and revocation updates. Use a copy of the
  profile or a fresh one.
