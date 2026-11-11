# AGENTS.md

This is my (Tony's) dotfiles flake. It is a shared configuration for my fleet machines.

Primarily, it declares how my sietch, jacurutu, and tleilax machines should be configured
and set up.

It includes a suite of custom tools, bash scripts, and a custom quickshell desktop

The main branch is `nixos`.

All three machines build from the root `flake.nix` and its one `flake.lock`: sietch
and jacurutu through `makeSystem`, tleilax (an aarch64 Raspberry Pi) from
`machines/tleilax`. tleilax is a locked-down box for credential services; its install
and recovery runbook is `docs/tleilax-install.md`.

## Self-Hosted Services

`sietch` and `tleilax` are my self-hosting boxes. different services are configured
per-machine.

all self-hosted services are managed as tailscale services. refer to the `add-selfhost-service`
skill when setting up a new service.

if you need to update images for self-hosted containers, refer to the `update-image-pins`
skill and `bin/image-pins`.

## Temporary security overrides

When the pinned nixpkgs lacks a vulnerability fix, put temporary package overrides
in `packages/security-overrides.nix` and import that overlay in both the shared
`overlays` list in `flake.nix` and tleilax's separate `nixpkgs.overlays`.

- Record the CVE, upstream fix, pinned source or patch hash, and removal condition.
  Use `prev.<package>.overrideAttrs` so the override does not recurse through itself.
- For a version bump, guard it with
  `if prev.lib.versionAtLeast prev.<package>.version fixedVersion then throw "Remove the obsolete security override for <package>" else ...`.
  For a backported patch, use an upstream-fix condition appropriate to that patch.
- Build the affected packages on the appropriate hosts and check that applications
  use the patched dependency. Report validation separately from activation.
- Once nixpkgs includes the fix, remove the override. When the overlay becomes
  empty, remove its file and both imports. For an obsolete override during an
  automated update, follow [the flake-update runbook](docs/flake-update.md).

## Commit checks and Stillsuit tests

Run project checks through `direnv exec "$PWD"`. Commit hooks check formatting and
lint selected files without rewriting them, and run Stillsuit's pure model/schema
tests for relevant changes. Setup and manual commands are in
[docs/testing.md](docs/testing.md).

Before committing Stillsuit behavior changes, run the affected feature's runtime
fixture too. For shared core, UI or bar changes, expand coverage as described in
the testing guide. Report skipped or unavailable runtime checks and their reasons;
passing the fast hook alone does not establish runtime behavior.

## Rules

- Give every systemd timer an explicit `RandomizedDelaySec` appropriate to its latency
  requirements to avoid thundering-herd workload spikes.
- Never launch Zen (or another Firefox-based browser) with `--remote-debugging-port` or
  `--marionette` against a real profile. Automation mode can leave test prefs in
  `prefs.js` that disable Safe Browsing and revocation updates. Use a copy of the
  profile or a fresh one.
- Never evaluate or build sietch's config (`nixosConfigurations.sietch`, any attribute) on
  jacurutu. It saturates the laptop's disk I/O while I'm using it. Check sietch changes on
  sietch, or report them as unverified.
