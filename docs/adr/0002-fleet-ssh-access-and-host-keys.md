# lib/fleet.nix drives SSH access, and SSH clients pin identities and host keys per purpose

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

`lib/fleet.nix` is the registry for hosts, devices and keys. Human logins must use the YubiKey `sk` keys. Agents use a passwordless restricted key per host. The desktop ssh-agent can hold both. Fleet hosts set `RequestTTY=yes` for tmux-on-ssh. Agent harness shells see the Nix store through an id-mapped mount where files stat as nobody. A host with boot-time disk unlock presents a different host key from its boot environment than from the running system. Bitbucket publishes its SSH host keys at https://bitbucket.org/site/ssh and their fingerprints at https://support.atlassian.com/bitbucket-cloud/docs/configure-ssh-and-two-step-verification/.

## Decision

- Human keys are hardware only: yk-nfc travels with Tony, yk-nano is the backup in storage. `id_ed25519` is the agenix identity, never a login key.
- Non-SSH devices (phone, NAS, iPad) are in the inventory without entering the access matrix.
- `~/.config/fleet/fleet.json` is a machine-readable registry whose schema is a contract for scripts; bump `version` on breaking changes. Keys are left out.
- Human host aliases set `IdentitiesOnly`, so ssh does not offer the passwordless `agent-<host>` key and bypass the hardware-key requirement.
- Agent aliases share one connection through `cm-agent-%r@%h-%p`, distinct from the login connection's `cm-%r@%h-%p`, so agent-key commands never ride a hardware-key login. Anything that can use the socket can already read the key.
- `NIX_SSHOPTS="-o RequestTTY=no"`: a TTY merges remote stderr into stdout, and `nixos-rebuild --build-host` parsed build progress as the result path. Only Nix reads this variable.
- tracer runs plain `ssh <host>`, so its identity and BatchMode come from the `<host>-agent` alias in `~/.ssh/config`.
- `~/.ssh/config` is a real user-owned file (mode 400) copied from `config_source`, because ssh rejects a store symlink that stats as nobody ("Bad owner or permissions").
- Each reachable host's boot-environment key is pinned under the alias `<host>-initrd` (and `[<host>-initrd]:<port>`), which only the unlock SSH aliases in `modules/home/fleet.nix` use, so it never matches the normal host name.
- The `bitbucket.org ssh.bitbucket.org` alias keeps existing SSH URLs working after the November 2026 Bitbucket hostname migration, and forces IPv4 because IPv6 connections to Bitbucket time out on this network. Bitbucket's ed25519, ECDSA and RSA keys are pinned for `ssh.bitbucket.org`, copied from the published page with fingerprints checked against Atlassian's documentation.

## Consequences

Changes to access go through `lib/fleet.nix` and a rebuild. Scripts must tolerate only additive changes within a `fleet.json` version. Removing `IdentitiesOnly` or sharing the control socket would let agent keys stand in for hardware keys. A rotated Bitbucket key needs the same check against both sources before it is updated.

## Where

- `lib/fleet.nix` (`hosts.*.keys`, `devices`)
- `modules/home/fleet.nix` (`fleetSshSettings`, `agentSshSettings`, `fleetJson`, `home.file.".ssh/config"`, the Bitbucket entry, unlock aliases)
- `modules/nixos/fleet.nix` (`initrdUnlockTargets`, `programs.ssh.knownHosts`)
- `home/shell.nix` (`NIX_SSHOPTS`)
- `home/services/tracer-sync.nix` (`systemd.user.services.tracer-sync`)
