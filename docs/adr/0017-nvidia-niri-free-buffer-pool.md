# niri gets NVIDIA's free buffer pool limit

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The NVIDIA driver's heap-reuse heuristic keeps about 1 GiB of freed buffers pooled in niri instead of about 100 MiB (https://yalter.github.io/niri/Nvidia.html).

## Decision

An NVIDIA application profile matches the process name `niri` and sets `GLVidHeapReuseRatio` to 0.

## Consequences

The profile matches by process name, so a renamed compositor binary loses it.

## Where

- `modules/nixos/nvidia.nix` (`environment.etc."nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json"`)
