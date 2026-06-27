import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string icon: Theme.icon.volume_up
    property string title: ""
    property string subtitle: ""
    property bool active: false

    readonly property color accentColor: Theme.accent

    signal clicked()

    Layout.fillWidth: true
    implicitHeight: 40
    radius: Theme.radiusSmall - 1
    color: root.active ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, mouse.pressed ? 0.22 : 0.15)
        : mouse.pressed ? Qt.rgba(1, 1, 1, 0.08)
        : mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05)
        : "transparent"
    border.width: 0

    Behavior on color {
        ColorAnimation { duration: Theme.animationFast }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 10

        Text {
            text: root.icon
            color: root.active ? root.accentColor : Theme.dimText
            font.family: Theme.iconFamily
            font.variableAxes: ({ "FILL": root.active ? 1 : 0, "wght": 500, "opsz": 20 })
            font.pixelSize: 15
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: root.title
                color: root.active ? Theme.text : Theme.dimText
                font.family: Theme.fontFamily
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: root.subtitle
                color: Theme.mutedText
                font.family: Theme.fontFamily
                font.pixelSize: 10
                elide: Text.ElideRight
                visible: text !== ""
            }
        }

        Text {
            text: Theme.icon.check
            color: root.accentColor
            font.family: Theme.iconFamily
            font.variableAxes: ({ "FILL": 1, "wght": 600, "opsz": 20 })
            font.pixelSize: 14
            visible: root.active
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
