import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property bool active: false
    property bool danger: false
    property bool subtle: false
    property int horizontalPadding: 10
    property int verticalPadding: 6
    property color accentColor: danger ? Theme.urgent : Theme.accent

    signal clicked()

    implicitWidth: row.implicitWidth + horizontalPadding * 2
    implicitHeight: Math.max(28, row.implicitHeight + verticalPadding * 2)
    radius: Theme.radiusSmall
    color: root.danger
        ? (mouse.pressed ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.28)
            : mouse.containsMouse ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.18)
            : "transparent")
        : mouse.pressed ? Theme.panelSurfaceActive
        : mouse.containsMouse ? Theme.panelSurfaceHover
        : active ? Theme.panelSurfaceActive
        : subtle ? "transparent"
        : Theme.panelSurface
    border.width: root.danger ? 0 : Theme.borderWidth
    border.color: active ? accentColor
        : mouse.containsMouse ? Theme.panelBorderStrong
        : subtle ? "transparent"
        : Theme.panelBorder

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
            color: root.active || root.danger ? root.accentColor : Theme.dimText
            font.family: Theme.iconFamily
            font.variableAxes: ({ "FILL": root.active ? 1 : 0, "wght": 500, "opsz": 20 })
            font.pixelSize: 15
        }

        Text {
            visible: root.text !== ""
            text: root.text
            color: root.active || root.danger ? root.accentColor : Theme.text
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.bold: root.active
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
