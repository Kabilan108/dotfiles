import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property var controller

    signal clicked()

    implicitWidth: indicatorRow.implicitWidth + 10
    implicitHeight: 28
    radius: Theme.radiusSmall
    color: indicatorMouse.pressed
        ? Qt.rgba(stateColor.r, stateColor.g, stateColor.b, 0.16)
        : indicatorMouse.containsMouse
            ? Qt.rgba(stateColor.r, stateColor.g, stateColor.b, 0.10)
            : "transparent"

    readonly property color stateColor: controller.failed
        ? Theme.urgent
        : controller.completed ? Theme.success : Theme.accent
    readonly property string stateIcon: controller.failed
        ? Theme.icon.warning
        : controller.completed ? Theme.icon.check : Theme.icon.wand_stars
    readonly property string stateLabel: controller.label || (controller.completed
        ? "Minutes ready"
        : controller.failed ? "Minutes failed" : "Making minutes")

    Behavior on color {
        ColorAnimation { duration: Theme.animationFast }
    }

    RowLayout {
        id: indicatorRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: root.stateIcon
            color: root.stateColor
            font.family: Theme.iconFamily
            font.pixelSize: 16
            font.variableAxes: ({ "FILL": 1, "wght": 600, "opsz": 18 })

            SequentialAnimation on opacity {
                running: root.controller.active
                loops: Animation.Infinite
                NumberAnimation { to: 0.4; duration: 650; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 1; duration: 650; easing.type: Easing.InOutQuad }
            }
        }

        Text {
            text: root.stateLabel
            color: root.stateColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.bold: true
        }
    }

    MouseArea {
        id: indicatorMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.controller.completed ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
