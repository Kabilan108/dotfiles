# Resources collector measures physical devices and leaves unknowns absent

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

`/proc/diskstats` lists partitions and device-mapper layers alongside whole
disks, and `/proc/net/dev` lists loopback, bridges, container and VPN
interfaces. Devices appear and vanish, and counters reset on reconnect. In
`/proc/stat`, guest and guest_nice time is already included in user and nice.
nvidia-smi reports `N/A` for unsupported fields. A Quickshell `Process` that
fails to start emits no `exited` signal. Lucide icons are stroked SVGs using
`currentColor`, which Qt's image decoder does not resolve.

## Decision

The collector counts only whole disks and network interfaces that have a
`device` entry in sysfs, so I/O is not double counted. Rates only count devices
present in both samples and clamp negative deltas to zero, so removed, new or
reset devices are not activity spikes. GPU fields nvidia-smi reports as `N/A`
stay absent, never zero. The QML CPU parser sums only the first eight
`/proc/stat` fields.

After `start`, the service checks with `Qt.callLater` whether the local
collector is running; normal exits finish first, so a still-refreshing,
not-running collector means it failed to start. `HostIcon` reads the vendored
SVG text, replaces `currentColor` with the theme colour, and passes it as a
data URL, leaving the geometry intact. The widget draws its own two-row
tooltip, so the bar's text tooltip stays empty.

## Consequences

Virtual-only machines report no disk or network rates.

## Where

- `packages/stillsuit-shell/src/plugins/builtin/resources/collect.py` (disk and network filters, `rates`, nvidia-smi parsing)
- `packages/stillsuit-shell/src/plugins/builtin/resources/ResourceService.qml` (local collector start check, CPU parsing)
- `packages/stillsuit-shell/src/plugins/builtin/resources/HostIcon.qml` (`assetFile`, `glyph`)
- `packages/stillsuit-shell/src/plugins/builtin/resources/ResourceWidget.qml` (`tooltipText`)
