import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Scope {
    id: root

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    property real volume: Pipewire.defaultAudioSink?.audio.volume ?? 0
    property bool muted: Pipewire.defaultAudioSink?.audio.muted ?? false
    property bool shouldShow: false
    property bool ready: false

    Timer {
        interval: 500
        running: true
        onTriggered: root.ready = true
    }

    Connections {
        target: Pipewire.defaultAudioSink?.audio ?? null

        function onVolumeChanged() {
            if (!root.ready) return
            root.shouldShow = true
            hideTimer.restart()
        }

        function onMutedChanged() {
            if (!root.ready) return
            root.shouldShow = true
            hideTimer.restart()
        }
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.shouldShow = false
    }

    LazyLoader {
        active: root.shouldShow

        PanelWindow {
            anchors.bottom: true
            margins.bottom: screen.height * 0.02
            exclusiveZone: 0
            implicitWidth: 280
            implicitHeight: 44
            color: "transparent"
            mask: Region {}

            OsdBar {
                anchors.fill: parent
                icon: root.muted ? "󰖁" :
                      root.volume > 0.66 ? "󰕾" :
                      root.volume > 0.33 ? "󰖀" : "󰕿"
                value: root.muted ? 0 : root.volume
                accentColor: root.muted ? Theme.red : Theme.accent
                label: root.muted ? "Mute" : Math.round(root.volume * 100) + "%"
            }
        }
    }
}
