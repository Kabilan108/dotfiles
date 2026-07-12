import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property var controller

    signal clicked()

    implicitWidth: indicatorRow.implicitWidth + 8
    implicitHeight: 28
    radius: Theme.radiusSmall
    color: indicatorMouse.pressed
        ? Qt.rgba(stateColor.r, stateColor.g, stateColor.b, 0.16)
        : indicatorMouse.containsMouse
            ? Qt.rgba(stateColor.r, stateColor.g, stateColor.b, 0.10)
            : "transparent"
    border.width: 0

    readonly property color stateColor: controller.paused ? Theme.warning : Theme.urgent

    Behavior on color {
        ColorAnimation { duration: Theme.animationFast }
    }

    RowLayout {
        id: indicatorRow
        anchors.centerIn: parent
        spacing: 6

        Item {
            implicitWidth: 13
            implicitHeight: 13

            Rectangle {
                anchors.centerIn: parent
                width: 8
                height: 8
                radius: 4
                color: root.stateColor

                SequentialAnimation on scale {
                    running: root.controller.phase === "recording"
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.55; duration: 700; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutQuad }
                }
            }

            Text {
                visible: root.controller.paused
                anchors.centerIn: parent
                text: Theme.icon.pause
                color: root.stateColor
                font.family: Theme.iconFamily
                font.pixelSize: 13
                font.variableAxes: ({ "FILL": 1, "wght": 650, "opsz": 16 })
            }
        }

        Text {
            text: root.controller.elapsedText
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
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
