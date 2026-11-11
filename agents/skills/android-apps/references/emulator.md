# Driving the emulator

For delegates verifying an app or recording a demo on sietch's emulator.

## Device tools

In T3 Code, open the emulator with the device tools (`device_list`, then
`device_open`) and run every launch, tap, text entry and screenshot through
the `agent-device` command it returns. Outside T3, use `adb -s emulator-<port>`.

- Tap by coordinates from the rects in `snapshot -i --json`.
- `back` can exit the app. Close the keyboard with `keyboard dismiss`.
- `gesture pan` does not trigger system back. Swipe from the left edge
  instead: `adb shell input swipe 5 1200 500 1200 800`. An immersive screen
  needs two: the first only reveals the system bars.
- `press x y --count N --interval-ms M` sends tap bursts. The real gap is a
  little over M; read it from `adb shell dumpsys input`.
- A cold boot can show "System UI isn't responding". `alert dismiss` clears it.
- `settings airplane on|off` toggles airplane mode for offline checks.

## Parallel agents

Each agent needs its own emulator instance. Either start the shared AVD with
`emulator -avd <name> -read-only -port <even port>`, or give the agent its own
copy: `cp -r ~/.android/avd/<name>.avd` and `<name>.ini` to a new name,
replace the old name in the new `.ini` and in the copy's `hardware-qemu.ini`,
`emu-launch-params.txt` and `snapshots/default_boot/hardware.ini`, and delete
its `multiinstance.lock`. Two Gradle builds in one checkout block each other, so
parallel builds also need separate git worktrees.

## Recording a demo

1. Record one segment per flow: `record start --scope device`, drive the
   flow, `record stop`. Short segments are easier to redo than one long take.
2. Caption each segment with ffmpeg `drawtext`, re-encoding every segment
   with the same codec, size and frame rate.
3. Join them with the concat demuxer (`ffmpeg -f concat -safe 0 -i list.txt -c copy out.mp4`).
4. Watch the result, or pull frames from each segment, before sending it.
   Check that every caption matches what is on screen.
