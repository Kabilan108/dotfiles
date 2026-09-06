# Stillsuit follow-up deployment and QA

Source-only changes are not running yet. No second reviewer pass is planned.
This checklist is for a separately approved, coordinated rollout.

## Before the switch

1. Save work in ordinary terminals and keep a recovery terminal available.
   Do not restart the shared Ghostty service while relying on its windows.
2. Review/stage the intended source files, including new files. A Git-backed
   flake ignores untracked new files. Exclude unrelated agent configuration
   and skill todos; do not use a blanket `git add .`.
3. At the cutover, apply `docs/plans/stillsuit-shared-ghostty-niri.patch` and
   run `niri validate`. The checkout-backed Niri config can reload immediately
   when edited, so this patch is deliberately still unapplied.
4. Rebuild only after the helper, service, core and Niri changes are all ready.
   Prefer a fresh graphical login after the switch to start the resident normal
   Ghostty cleanly and avoid retaining the old private agent process. Save work
   first; persistence across panel hide/reopen is not a logout/reboot guarantee.
5. Keep the previous NixOS generation and the pre-change source revision. If a
   rollback is needed, restore the matching Niri patch and plugin source too.
   Mutable checkout plugins do not roll back with the system generation.

Do not use `stillctl reload`, which targets the legacy shell. Future plugin-only
edits need no rebuild; this batch changes the core and therefore does.

## Startup checks

```sh
systemctl --user is-active stillsuit-shell.service
systemctl --user is-active app-com.mitchellh.ghostty.service
systemctl --user is-active waybar.service
quickshell list --all
stillsuit-plugins validate
```

Expect Stillsuit and normal Ghostty active, Waybar inactive, one production shell
and no legacy shell. A nonzero `is-active`
result for inactive Waybar is expected. If validation fails, retain its errors
and stop before plugin experiments.

## Interaction checks

| Area | Try | Expected |
|---|---|---|
| Panels | Switch Wi-Fi -> Bluetooth -> audio -> battery repeatedly, on both outputs | One click; no two selected chips; no flash of an empty host |
| Dismissal | Click outside, click the empty bar background or gap below it, scroll outside, press Escape | Panel closes; clicks on blank space inside do not close it |
| Outputs | Open the same panel from the other output; unplug an external output while its panel is open | One visible panel on the chosen/surviving output |
| Toasts | Send a test notification while a non-notification panel is open | Banner dismisses the panel on its output, not the other output |
| Notification center | Leave center open, then send another notification; enable DND | New history row without a banner over the center; DND hides visible banners |
| Tooltips | Hover CPU/MEM and agent usage for half a second, then leave or open panel | Plain-text tooltip; no focus theft; tooltip disappears |
| Ethernet | Connect, expand details, disconnect | Section only while connected; readable name, addresses and interface/link details |
| Managers | Launch settings from network, audio and Bluetooth | Panel closes after launch; ordinary manager window remains usable |
| Bluetooth | Show a long device list | Capped height, scroll works, header/actions remain reachable |
| Audio | No media, paused media, disabled transport controls | Compact empty row and legible disabled play button |
| Battery | Compare charging and unplugged state | State text does not squeeze graphic; charging icon and percentage match; chip background means panel selected only |
| Agent usage | Check default Claude and Codex accounts | Each available provider has its own remaining percentage |
| Ghostty | Mod+Return several times; Mod+Grave, hide, reopen | Ordinary windows remain normal; agent floats at 60% x 60%; same tmux session survives hide/reopen |
| Recording | Make a short disposable recording, pause/resume, finish, copy path | Transport works, path copies, completion closes after five seconds; no default meetings chip/history viewer |

Use a harmless test banner, after deployment:

```sh
notify-send 'Stillsuit QA' 'Toast and panel interaction test'
```

Do not deliberately drain the battery or manufacture failed meeting jobs just
for QA. Those policy/error states have isolated fixtures; check real instances
when available. Test terminate only with a disposable agent session because it
intentionally ends that exact tmux session.

## Plugin lifecycle check

Use a disposable experimental widget, not a critical real plugin. Edit its
label, disable it, enable it, temporarily invalidate its manifest, then restore
it. Each change should take effect within about a second without restarting the
shell. Disabled/invalid widgets must disappear, including their click target.
The IPC rescan response `watching` means automatic discovery is already active,
not that an immediate rescan was dispatched.

## Logs and handoff

Capture recent logs immediately if anything fails:

```sh
journalctl --user -u stillsuit-shell.service -b --since '30 minutes ago' --no-pager
journalctl --user -u app-com.mitchellh.ghostty.service -b --since '30 minutes ago' --no-pager
```

Report the exact click/key sequence, output, expected/actual behavior and a
screenshot when visual. Keep logs local until inspected for private content.
Before starting the later soak, agree its start time and log-export destination;
current journald rotation alone is not a promise of retention through the soak.

## Retained shell logs

The service sends color-free informational Quickshell output to journald.
The shared journal limits in `configuration.nix` are 14 days, 1 GiB persistent
storage and 256 MiB runtime storage. Rotation and disk pressure may shorten
history. Logs survive shell restarts without a separate file copy.

```sh
journalctl --user -u stillsuit-shell.service --since '14 days ago'
```

The new logging arguments take effect after the service configuration is
rebuilt and the shell next starts. Activation and soak remain manual checks.
