import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property var context
    required property string icon
    required property real value
    required property color accentColor
    property string label: ""

    implicitWidth: 300
    implicitHeight: 48
    radius: context.theme.geometry.radius * 2
    color: context.theme.colors.surface.raised
    border.width: 1
    border.color: context.theme.colors.border.normal

    RowLayout {
        anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
        spacing: 13
        Text {
            text: root.icon
            color: root.accentColor
            font.family: root.context.theme.typography.monospaceFamily
            font.pixelSize: root.context.theme.typography.baseSize * 1.5
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 6
            radius: height / 2
            color: root.context.theme.colors.border.subtle
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * Math.min(Math.max(root.value, 0), 1)
                radius: parent.radius
                color: root.accentColor
                Behavior on width { NumberAnimation { duration: root.context.theme.motion.medium; easing.type: Easing.OutCubic } }
            }
        }
        Text {
            visible: root.label !== ""
            text: root.label
            color: root.context.theme.colors.text.secondary
            font.family: root.context.theme.typography.monospaceFamily
            font.pixelSize: root.context.theme.typography.baseSize * 0.85
        }
    }
}
