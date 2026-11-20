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

## Notes and decisions

Code carries no comments ([ADR 0001](docs/adr/0001-ban-code-comments.md)). The reasons
code can't show live in two places:

- Notes: an `AGENTS.md` in the subsystem's directory, one rule per bullet with its
  reason. Before editing a file, read every `AGENTS.md` from its directory up to this
  one. When a change makes a note false, edit or delete the note in the same commit.
  Add a note only for what a name, a constant, an assertion or a test can't hold.
- Decisions: `docs/adr/`, for choices that are hard to reverse, surprising, and the
  result of a real trade-off. Each lists the paths it governs in `paths:`, so grep
  `docs/adr` for the area you are changing. If a change would contradict an ADR, stop
  and ask Tony, naming the ADR. If he agrees, the same commit adds a new ADR whose
  first line says which one it replaces and why, deletes the old one, and the PR
  body says "Decisions changed: NNNN → MMMM".

`scripts/notes-check` fails a commit when a note or ADR names a repo path that is gone.

### Root files

- Keep ghostty on `inputs.nixpkgs.follows` and atuin off it in `flake.nix`. ghostty's own nixpkgs shipped brotli 1.2.0 (CVE-2026-111497) and it needs the system glibc and Mesa ABI; atuin must build with its own nixpkgs and toolchain to match atuin.cachix.org, and its pin stays on a release tag that Atuin's CI has cached, or it compiles locally.
- Bring pagebin in through its overlay, not its flake package. `bun build --compile` embeds the bun that builds it, so the overlay makes it use this overlay set's bun.
- `permittedInsecurePackages` in `flake.nix` allows `firefox-esr-140-bin-unwrapped-140.17.0esr` for Zotero 10, which bundles Firefox 140 ESR (end of life 2026-10-13). Drop the permit once nixpkgs' Zotero moves to a supported ESR.
- Keep the two agenix copies of `secrets/nix-access-tokens.age` in `user.nix` and reach them through links included with `!include`. Root's Nix must read a root-owned copy, because a kabilan-owned file included from the system Nix config could be rewritten to load plugins into root's Nix. The links exist because the Codex sandbox hides the agenix runtime directory: Nix ignores its whole config when an include path sits in a hidden directory, but skips an unreadable link.
- Keep jacurutu's key on the sietch-only Android secrets in `secrets.nix` (the Hark release keystore and signing properties, and the personal keystore). It is the second way to recover them, and losing them means re-signing every app on Tony's phone.

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
