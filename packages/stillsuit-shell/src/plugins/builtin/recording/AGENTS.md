# Recording plugin notes

- Keep the cube in `_levelFromPeak` in `Service.qml`. Quickshell's PwNodePeakMonitor reports the cube root of the sample peak, so the value is cubed before the dB conversion. Drop the cube if Quickshell changes the monitor to report the raw peak.
- Read panel state in fixtures through the flag properties on `RecordingPanel.qml` (`annotateToggleVisible`, `exportButtonsEnabled` and the rest), not through the children's visible. The host owns the panel's visibility, so children report an effective visible of false.
- Keep the recording dot in `RecordingWidget.qml` a fixed-size circle that scales about its centre. Resizing a small circle snaps its position to whole pixels, so it would not grow evenly on every side.
