# Network service limits the Quickshell scanner and falls back to helper polling

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Quickshell lists unsaved Wi-Fi networks only while a device's scanner is on, and an enabled scanner keeps requesting scans. Quickshell 0.3.1 does not recover after NetworkManager restarts, so its live device list can go stale. A hidden network has no SSID in the live list, but NetworkManager still reports it as active.

## Decision

- The scanner runs only while it is wanted. `applyScanner` tracks only devices this service switched on and switches each off on panel close, scan end, fallback or destruction; a scanner enabled elsewhere is left alone.
- The helper's last scan fills in SSIDs that Quickshell hides while its scanner is off. Live rows win.
- A `sanityTimer` sends the helper a one-`nmcli` `summary` every 60 s, or every 5 s after a disagreement. Two consecutive disagreements with the live devices set `networkingStale` and drop the service back to helper polling.
- The comparison requires every live SSID to be active in NetworkManager but allows active SSIDs missing from the live list.

## Consequences

The sanity check costs one `nmcli` call a minute while the backend is healthy. The fallback can be removed once Quickshell recovers from NetworkManager restarts.

## Where

- `packages/stillsuit-shell/src/services/NetworkService.qml` (`applyScanner`, `releaseScanners`, `sanityTimer`, `staleStrikes`, the helper-network merge, the summary comparison)
