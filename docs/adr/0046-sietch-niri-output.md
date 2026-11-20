# Pin sietch's ultrawide to 180 Hz with a max-bpc fallback

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

sietch drives an AOC CU34G2XP ultrawide (3440x1440) from an RTX 3090 on DP-1. Without a refresh rate in the mode, niri picks the highest rate the panel offers, which is 180 Hz. The mode was set with a known risk: 180 Hz may come up black or flicker.

## Decision

`hosts/sietch.kdl` sets `mode "3440x1440@180.000"` on DP-1 at scale 1. If the output comes up black or flickers, the first fallback is `max-bpc 8` on the output; the second is a lower refresh rate taken from `niri msg outputs`.

## Consequences

The 180 Hz mode stays only while it displays cleanly. A monitor, cable or driver change that breaks it should be handled with `max-bpc 8` before lowering the rate.

## Where

- `home/desktop/wayland/compositors/niri/hosts/sietch.kdl` (`output "DP-1"`)
