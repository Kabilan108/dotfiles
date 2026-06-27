import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root

    property string label: "scan"
    property string icon: Theme.icon.refresh
    property bool busy: false

    signal clicked()

    implicitWidth: row.implicitWidth + 18
    implicitHeight: 24
    radius: Theme.radiusSmall - 1
    color: mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.04)
    border.width: Theme.borderWidth
    border.color: Theme.panelBorder

    Behavior on color {
        ColorAnimation { duration: Theme.animationFast }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            id: glyph
            text: root.icon
            color: Theme.accent
            font.family: Theme.iconFamily
            font.variableAxes: ({ "wght": 500, "opsz": 20 })
            font.pixelSize: 13

            RotationAnimator {
                target: glyph
                running: root.busy
                from: 0
                to: 360
                duration: 1000
                loops: Animation.Infinite
            }
        }

        Text {
            text: root.label
            color: root.busy ? Theme.accent : Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
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
