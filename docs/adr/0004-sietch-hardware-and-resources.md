# sietch keeps Wi-Fi off, uses the CUDA cache and caps agent VMs

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

sietch uses its wired 2.5 GbE link as the LAN data plane. cache.nixos.org does not cover CUDA builds. sietch has 32 threads and 62 GiB of memory, and agents start VMs on it (vms skill).

## Decision

- The `disable-wifi` unit turns the Wi-Fi radio off on every boot and activation; the hardware stays available for manual recovery.
- cache.nixos-cuda.org is a substituter, and Blender comes from `pkgsCuda.blender` rather than `blender.override`, because that matches the cache's build.
- Every agent VM starts in the `vms` user slice: `CPUQuota=1600%`, `MemoryMax=28G`, no swap. That leaves half the threads and most of the memory for everything else.

## Consequences

Switching Blender to an override would compile CUDA Blender locally. A VM that needs more than the slice must be started outside it deliberately.

## Where

- `machines/sietch/default.nix` (`systemd.services.disable-wifi`, `nix.settings.substituters`, `pkgsCuda.blender`, `systemd.user.slices.vms`)
