import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property int maxBrightness: 255
    property real brightness: -1
    property bool shouldShow: false
    property int stackOffset: 0

    FileView {
        path: "/sys/class/backlight/amdgpu_bl1/max_brightness"
        onLoaded: {
            const val = parseInt(text())
            if (!isNaN(val) && val > 0) root.maxBrightness = val
        }
    }

    FileView {
        path: "/sys/class/backlight/amdgpu_bl1/brightness"
        watchChanges: true

        onFileChanged: reload()

        onLoaded: {
            const raw = parseInt(text())
            if (isNaN(raw)) return
            const val = raw / root.maxBrightness
            if (root.brightness < 0) {
                root.brightness = val
                return
            }
            if (Math.abs(val - root.brightness) > 0.005) {
                root.brightness = val
                root.shouldShow = true
                hideTimer.restart()
            }
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
            margins.bottom: screen.height * 0.02 + root.stackOffset
            exclusiveZone: 0
            implicitWidth: 280
            implicitHeight: 44
            color: "transparent"
            mask: Region {}

            OsdBar {
                anchors.fill: parent
                icon: root.brightness > 0.66 ? "󰃠" :
                      root.brightness > 0.33 ? "󰃟" : "󰃞"
                value: root.brightness
                accentColor: "#f9e2af"
                label: Math.round(root.brightness * 100) + "%"
            }
        }
    }
}
