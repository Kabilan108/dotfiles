import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var theme
    property string label: "Toggle"
    property string description: ""
    property bool checked: false

    signal toggled(bool checked)

    implicitWidth: 260
    implicitHeight: Math.max(textColumn.implicitHeight, track.height)

    ColumnLayout {
        id: textColumn
        anchors {
            left: parent.left
            right: track.left
            rightMargin: 12
            verticalCenter: parent.verticalCenter
        }
        spacing: 2

        ShellText {
            theme: root.theme
            text: root.label
            sizeRole: "label"
        }

        ShellText {
            visible: root.description !== ""
            theme: root.theme
            text: root.description
            role: "muted"
            sizeRole: "caption"
        }
    }

    Rectangle {
        id: track
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        width: 38
        height: 22
        radius: 11
        color: root.checked ? root.theme.component.control.active : root.theme.component.control.background
        border.width: 1
        border.color: root.checked ? root.theme.component.control.active : root.theme.component.control.outline

        Behavior on color {
            ColorAnimation {
                duration: root.theme.motion.fast
            }
        }

        Rectangle {
            width: 16
            height: 16
            radius: 8
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 3 : 3
            color: root.checked ? root.theme.component.control.onActive : root.theme.semantic.content.secondary

            Behavior on x {
                NumberAnimation {
                    duration: root.theme.motion.normal
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.checked = !root.checked
            root.toggled(root.checked)
        }
    }
}
