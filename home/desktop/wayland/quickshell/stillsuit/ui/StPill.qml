import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property bool active: false
    property color accentColor: Theme.accent

    signal clicked()

    implicitWidth: row.implicitWidth + 16
    implicitHeight: 28
    radius: Theme.radiusPill
    color: active ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.18)
        : mouse.containsMouse ? Theme.panelSurfaceHover
        : Theme.panelSurface
    border.width: active ? 0 : Theme.borderWidth
    border.color: mouse.containsMouse ? Theme.panelBorderStrong : Theme.panelBorder

    Behavior on color {
        ColorAnimation { duration: Theme.animationFast }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            visible: root.icon !== ""
            text: root.icon
            color: root.active ? root.accentColor : Theme.dimText
            font.family: Theme.iconFamily
            font.variableAxes: ({ "FILL": root.active ? 1 : 0, "wght": 500, "opsz": 20 })
            font.pixelSize: 14
        }

        Text {
            text: root.text
            color: root.active ? root.accentColor : Theme.dimText
            font.family: Theme.bodyFontFamily
            font.pixelSize: 10
            font.bold: true
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
