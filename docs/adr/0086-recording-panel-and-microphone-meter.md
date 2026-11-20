# Recording panel and microphone meter

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The host owns the recording panel's visibility, so its children report an
effective `visible` of false and fixtures cannot read it. Region and window
captures hand the screen to a selector. A recording can be stopped outside
the panel, from the omarecord overlay toolbar. The recorder captures
PipeWire's default input, and `PwNodePeakMonitor` reports the cube root of the
sample peak. Resizing a small circle snaps its position to whole pixels.

## Decision

The panel exposes the bindings its setup and completed views use
(`annotateToggleVisible`, `exportButtonsEnabled` and similar) as flags for
fixtures. Monitor captures keep the configured audio defaults; region and
window captures are silent unless the user opts in for that recording. For
region and window captures the panel closes before the helper answers, and a
cancelled selector leaves the recorder idle. A stop from outside the panel
still presents the completed view, but only on the recorded output
(`ownsRecording`).

The meter reads the same default input node, and only while a recording that
includes the microphone is running and unpaused. `_levelFromPeak` cubes the
reported peak before converting to dB. The recording dot is a fixed-size
circle scaled about its centre so it grows evenly on every side.

## Consequences

If Quickshell changes `PwNodePeakMonitor` to report the raw peak, drop the
cube.

## Where

- `packages/stillsuit-shell/src/plugins/builtin/recording/RecordingPanel.qml` (fixture flags, `applyAudioDefaults`, start handling, `presentCompletion`, `ownsRecording`)
- `packages/stillsuit-shell/src/plugins/builtin/recording/Service.qml` (`_levelFromPeak`, microphone gating)
- `packages/stillsuit-shell/src/plugins/builtin/recording/RecordingWidget.qml` (recording dot)
