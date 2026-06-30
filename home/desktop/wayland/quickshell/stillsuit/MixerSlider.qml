import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

ColumnLayout {
    id: root

    required property PwNode node
    property bool compact: false
    property bool framed: true
    property bool ready: false
    property var syncNodes: []
    property string title: ""
    property string subtitle: ""
    property string appName: node.properties["application.name"]
        ?? (node.description !== "" ? node.description : node.name)
    property int groupCount: syncNodes.length + 1
    property color accentColor: root.node.isSink ? Theme.vol : Theme.mic
    property string iconText: {
        const volume = root.node.audio?.volume ?? 0
        if (root.node.isSink) {
            if (root.node.audio?.muted || volume <= 0.001) return Theme.icon.volume_off
            if (volume < 0.34) return Theme.icon.volume_down
            if (volume < 0.68) return Theme.icon.volume_down_alt
            return Theme.icon.volume_up
        }
        return root.node.audio?.muted ? Theme.icon.mic_off : Theme.icon.mic
    }
    readonly property string primaryText: root.title !== "" ? root.title : root.appName
    readonly property string secondaryText: {
        if (root.subtitle !== "") return root.subtitle
        if (root.compact && root.groupCount > 1) return `Linked streams ×${root.groupCount}`
        if (!root.compact) {
            const media = root.node.properties["media.name"]
            if (media) return media
        }
        return ""
    }

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

    spacing: 0

    Rectangle {
        Layout.fillWidth: true
        radius: Theme.radiusSmall
        color: root.framed && !root.compact ? Theme.panelSurface : "transparent"
        border.width: root.framed && !root.compact ? Theme.borderWidth : 0
        border.color: root.framed && !root.compact ? Theme.panelBorder : "transparent"
        implicitHeight: inner.implicitHeight + (root.framed && !root.compact ? 20 : 0)

        ColumnLayout {
            id: inner
            anchors.fill: parent
            anchors.margins: root.framed && !root.compact ? 10 : 0
            spacing: root.framed && !root.compact ? 8 : 5

            RowLayout {
                spacing: 10

                Item {
                    Layout.preferredWidth: root.framed && !root.compact ? 24 : 24
                    Layout.fillHeight: true
                    visible: !root.node.isStream || !root.compact

                    Text {
                        anchors {
                            verticalCenter: parent.verticalCenter
                            horizontalCenter: parent.horizontalCenter
                        }
                        text: root.iconText
                        color: root.node.audio?.muted ? Theme.textMuted : root.accentColor
                        font.family: Theme.iconFamily
                        font.variableAxes: ({ "FILL": 0, "wght": 500, "opsz": 20 })
                        font.pixelSize: root.compact || !root.framed ? 20 : 19
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: root.framed && !root.compact ? 8 : 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: root.primaryText
                                color: root.node.audio?.muted ? Theme.textMuted : Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: root.compact || !root.framed ? 12 : Theme.fontSizeLarge
                                font.bold: root.framed && !root.compact
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.secondaryText
                                color: root.node.audio?.muted ? Theme.textMuted : Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                elide: Text.ElideRight
                                visible: text !== ""
                            }
                        }

                        Text {
                            text: root.node.audio?.muted ? "Mute"
                                : Math.round((root.node.audio?.volume ?? 0) * 100) + "%"
                            color: root.node.audio?.muted ? Theme.textMuted : Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: root.compact || !root.framed ? Theme.fontSizeSmall : Theme.fontSizeMedium
                            font.bold: root.framed && !root.compact
                            Layout.preferredWidth: root.compact ? 40 : 44
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 6
                        radius: 999
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
                            color: root.node.audio?.muted ? Theme.textMuted : root.accentColor

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
            }
        }
    }
}
