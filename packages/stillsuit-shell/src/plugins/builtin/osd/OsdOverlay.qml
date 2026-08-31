import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland

// Per-output presentation only. The workflow service, recorder state, and
// Dictator socket stay global in stillsuit.workflows.
Scope {
    id: root

    required property var context
    required property var screen

    property var workflows: context.services.get("stillsuit.workflows")
    property var dictator: workflows ? workflows.dictator : null
    property real volume: Pipewire.defaultAudioSink?.audio.volume ?? 0
    property bool muted: Pipewire.defaultAudioSink?.audio.muted ?? false
    property real brightness: -1
    property int maxBrightness: 255
    property bool volumeVisible: false
    property bool brightnessVisible: false
    readonly property bool dictatorVisible: dictator && dictator.visible
    readonly property bool visible: volumeVisible || brightnessVisible || dictatorVisible

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    Timer { id: audioReady; interval: 500; running: true; onTriggered: running = false }
    Connections {
        target: Pipewire.defaultAudioSink?.audio ?? null
        function onVolumeChanged() { if (!audioReady.running) { root.volumeVisible = true; volumeHide.restart() } }
        function onMutedChanged() { if (!audioReady.running) { root.volumeVisible = true; volumeHide.restart() } }
    }
    Timer { id: volumeHide; interval: root.context.theme.motion.slow * 12; onTriggered: root.volumeVisible = false }
    Timer { id: brightnessHide; interval: root.context.theme.motion.slow * 12; onTriggered: root.brightnessVisible = false }
    FileView {
        path: String(root.context.settings.values.brightnessMaxPath || "")
        onLoaded: { var value = Number(text()); if (isFinite(value) && value > 0) root.maxBrightness = value }
    }
    FileView {
        path: String(root.context.settings.values.brightnessPath || "")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            var value = Number(text()) / root.maxBrightness
            if (!isFinite(value)) return
            if (root.brightness >= 0 && Math.abs(value - root.brightness) > 0.005) { root.brightnessVisible = true; brightnessHide.restart() }
            root.brightness = value
        }
    }
    PanelWindow {
        screen: root.screen
        visible: root.visible
        anchors.bottom: true
        margins.bottom: root.screen.height * 0.02
        exclusiveZone: 0
        aboveWindows: true
        focusable: false
        color: "transparent"
        implicitWidth: column.implicitWidth
        implicitHeight: column.implicitHeight
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "stillsuit-osd"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        ColumnLayout {
            id: column
            spacing: root.context.theme.geometry.panelGap
            OsdBar {
                visible: root.volumeVisible
                context: root.context
                icon: root.muted ? "󰝟" : "󰕾"
                value: root.volume
                accentColor: root.muted ? root.context.theme.colors.status.danger : root.context.theme.colors.status.info
                label: root.muted ? "Mute" : Math.round(root.volume * 100) + "%"
            }
            OsdBar {
                visible: root.brightnessVisible
                context: root.context
                icon: "󰃠"
                value: root.brightness
                accentColor: root.context.theme.colors.status.warning
                label: Math.round(Math.max(0, root.brightness) * 100) + "%"
            }
            DictationPill {
                visible: root.dictatorVisible
                context: root.context
                dictator: root.dictator
            }
        }
    }
}
