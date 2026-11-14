---
name: vms
description: Run a VM for testing — a compositor or desktop shell, an installer, a NixOS system, an Android app. Use when booting, driving, stopping or cleaning up a VM, or deciding where one should run.
metadata:
  fleet-hosts: sietch
---

# VMs

## Where it runs

| Place | Use for | Details |
|---|---|---|
| sietch | everything today | [references/sietch.md](references/sietch.md) |
| boat.dev cloud VMs | not set up yet | — |

NixOS tests that boot VMs inside `nix build` (`tests/*.nix`, `pkgs.testers.runNixOSTest`) need none of this: the Nix daemon runs them in its sandbox.

## Rules for every VM

- **Know what the guest runs.** Your own repo, Tony's config, or work code he asked you to test is fine. Before booting anything else in a VM (an unfamiliar repo, an unofficial ISO or binary, a `curl | bash` setup), ask Tony.
- **Keep credentials out.** No tokens, keys, `.env` files or password-manager data go into a guest or a folder it can read.
- **Share outputs, not repositories.** Give the guest a read-only share, or copy build outputs into a scratch folder it can write. A guest that can write to a repo can plant code that later runs on the host.
- **Bind ports to `127.0.0.1`.** SSH, VNC and QMP stay on loopback or a unix socket. Tony views a VM through `ssh -L`.
- **Clean up.** Done means the VM is stopped and its disk deleted, unless Tony asked to keep it. Tell Tony about any VM you leave running.
