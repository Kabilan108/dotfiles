import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property var theme
    property string iconName: "settings"
    property string label: ""
    property bool active: false

    signal clicked()

    implicitWidth: clusterRow.implicitWidth + 14
    implicitHeight: Math.max(22, theme.metrics.barHeight - 6)
    radius: theme.metrics.radiusSmall
    color: active
        ? theme.component.bar.clusterActive
        : pointer.containsMouse ? theme.component.bar.clusterHover : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: root.theme.motion.fast
        }
    }

    RowLayout {
        id: clusterRow
        anchors.centerIn: parent
        spacing: 5

        ShellIcon {
            theme: root.theme
            name: root.iconName
            sizeRole: "small"
            color: root.active ? root.theme.component.bar.clusterActiveText : root.theme.component.bar.clusterText
        }

        ShellText {
            visible: root.label !== ""
            theme: root.theme
            text: root.label
            sizeRole: "caption"
            monospace: true
            color: root.active ? root.theme.component.bar.clusterActiveText : root.theme.component.bar.clusterText
        }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
