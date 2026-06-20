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
        interval: Theme.osdHideMs
        onTriggered: root.shouldShow = false
    }

    LazyLoader {
        active: root.shouldShow

        PanelWindow {
            anchors.bottom: true
            margins.bottom: screen.height * 0.02
            exclusiveZone: 0
            implicitWidth: 300
            implicitHeight: 40
            color: "transparent"
            mask: Region {}

            OsdBar {
                anchors.fill: parent
                icon: root.muted ? Theme.icon.volume_off :
                      root.volume > 0.75 ? Theme.icon.volume_up :
                      root.volume > 0.45 ? Theme.icon.volume_down :
                      root.volume > 0.15 ? Theme.icon.volume_down_alt : Theme.icon.volume_mute
                value: root.volume
                accentColor: root.muted ? Theme.mic : Theme.vol
                label: root.muted ? "Mute" : Math.round(root.volume * 100) + "%"
            }
        }
    }
}
