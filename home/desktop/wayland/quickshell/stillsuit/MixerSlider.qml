import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

ColumnLayout {
    id: root

    required property PwNode node
    property bool compact: false
    property bool ready: false
    property var syncNodes: []
    property string appName: node.properties["application.name"]
        ?? (node.description !== "" ? node.description : node.name)
    property int groupCount: syncNodes.length + 1

    PwObjectTracker { objects: [node] }

    Timer {
        interval: 100
        running: true
        onTriggered: root.ready = true
    }

    function setVolume(vol: real): void {
        vol = Math.max(0, Math.min(vol, 1))
        if (root.node.audio) root.node.audio.volume = vol
        for (const n of root.syncNodes) {
            if (n.audio) n.audio.volume = vol
        }
    }

    spacing: 4

    RowLayout {
        spacing: 8

        Text {
            text: root.node.isSink ? (root.node.audio?.muted ? Theme.icon.volume_off : Theme.icon.volume_up)
                                   : (root.node.audio?.muted ? Theme.icon.mic_off : Theme.icon.mic)
            color: root.node.audio?.muted ? Theme.overlay0 : Theme.text
            font.family: Theme.iconFamily
            font.variableAxes: ({ "wght": 500, "opsz": 20 })
            font.pixelSize: 16
            visible: !root.node.isStream
        }

        Text {
            Layout.fillWidth: true
            text: {
                let label = root.appName
                if (root.compact && root.groupCount > 1)
                    label += ` (×${root.groupCount})`
                if (!root.compact) {
                    const media = root.node.properties["media.name"]
                    if (media) label += ` — ${media}`
                }
                return label
            }
            color: root.node.audio?.muted ? Theme.overlay0 : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
        }

        Text {
            text: root.node.audio?.muted ? "Mute"
                : Math.round((root.node.audio?.volume ?? 0) * 100) + "%"
            color: root.node.audio?.muted ? Theme.overlay0 : Theme.dimText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            Layout.preferredWidth: 36
            horizontalAlignment: Text.AlignRight
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 6
        radius: 3
        color: Theme.surface0

        Rectangle {
            id: fill
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: parent.width * Math.min(root.node.audio?.volume ?? 0, 1)
            radius: parent.radius
            color: root.node.audio?.muted ? Theme.overlay0 : Theme.accent

            Behavior on width {
                enabled: root.ready
                SmoothedAnimation { velocity: 600 }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: mouse => root.setVolume(mouse.x / parent.width)
            onPositionChanged: mouse => {
                if (pressed) root.setVolume(mouse.x / parent.width)
            }
        }
    }
}
