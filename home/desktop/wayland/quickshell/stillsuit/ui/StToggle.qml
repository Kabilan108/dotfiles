import QtQuick
import ".."

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property bool on: false
    property color accentColor: Theme.accent

    signal toggled()

    implicitHeight: 38
    radius: Theme.radiusSmall
    color: root.on ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, mouse.pressed ? 0.22 : 0.15)
        : mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06)
        : Qt.rgba(1, 1, 1, 0.03)
    border.width: Theme.borderWidth
    border.color: root.on ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.4)
        : Theme.panelBorder

    Behavior on color {
        ColorAnimation { duration: Theme.animationFast }
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 9

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: root.on ? root.accentColor : Theme.textTertiary
            font.family: Theme.iconFamily
            font.variableAxes: ({ "FILL": root.on ? 1 : 0, "wght": 500, "opsz": 20 })
            font.pixelSize: 17
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: root.on ? Theme.textPrimary : Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeMedium
            font.bold: true
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: root.on ? "On" : "Off"
        color: root.on ? root.accentColor : Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.bold: true
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
