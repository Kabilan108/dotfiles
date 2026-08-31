import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// The sole observer for volume and backlight state. Per-output overlays receive
// this object from SurfaceRouter as their `service` construction property.
Scope {
    id: root

    required property var context

    readonly property string apiVersion: "1"
    readonly property var settings: context.settings ? context.settings.values : ({})
    readonly property string brightnessMaxPath: String(settings.brightnessMaxPath || "")
    readonly property string brightnessPath: String(settings.brightnessPath || "")
    readonly property real volume: Pipewire.defaultAudioSink?.audio.volume ?? 0
    readonly property bool muted: Pipewire.defaultAudioSink?.audio.muted ?? false

    property real brightness: -1
    property int maxBrightness: 255
    property bool volumeVisible: false
    property bool brightnessVisible: false

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    Timer { id: audioReady; interval: 500; running: true; onTriggered: running = false }
    Connections {
        target: Pipewire.defaultAudioSink?.audio ?? null
        function onVolumeChanged() { if (!audioReady.running) { root.volumeVisible = true; volumeHide.restart() } }
        function onMutedChanged() { if (!audioReady.running) { root.volumeVisible = true; volumeHide.restart() } }
    }
    Timer {
        id: volumeHide
        interval: root.context.theme.motion.slow * 12
        onTriggered: root.volumeVisible = false
    }
    Timer {
        id: brightnessHide
        interval: root.context.theme.motion.slow * 12
        onTriggered: root.brightnessVisible = false
    }
    FileView {
        path: root.brightnessMaxPath
        onLoaded: {
            var value = Number(text())
            if (isFinite(value) && value > 0) root.maxBrightness = value
        }
    }
    FileView {
        path: root.brightnessPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            var value = Number(text()) / root.maxBrightness
            if (!isFinite(value)) return
            if (root.brightness >= 0 && Math.abs(value - root.brightness) > 0.005) {
                root.brightnessVisible = true
                brightnessHide.restart()
            }
            root.brightness = value
        }
    }
}
