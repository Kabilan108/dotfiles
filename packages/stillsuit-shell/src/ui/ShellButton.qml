import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property var theme
    property string label: "Button"
    property string iconName: ""
    property bool active: false
    property bool destructive: false
    property bool compact: false
    property bool ghost: false
    property bool keyboardFocused: false

    signal clicked()

    implicitWidth: contentRow.implicitWidth + (compact ? 18 : 24)
    implicitHeight: compact ? 30 : 36
    radius: theme.metrics.radiusSmall
    color: ghost
        ? active ? theme.component.bar.clusterActive
        : pointer.pressed ? theme.component.control.pressed
        : pointer.containsMouse ? theme.component.control.hover : "transparent"
        : !enabled
        ? theme.component.control.disabled
        : active ? theme.component.control.active
        : pointer.pressed ? theme.component.control.pressed
        : pointer.containsMouse ? theme.component.control.hover
        : theme.component.control.background
    border.width: keyboardFocused ? 2 : ghost ? 0 : 1
    border.color: keyboardFocused
        ? theme.component.control.focus
        : destructive ? theme.semantic.status.danger : theme.component.control.outline
    opacity: enabled ? 1 : 0.74

    Behavior on color {
        ColorAnimation {
            duration: root.theme.motion.fast
        }
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        ShellIcon {
            visible: root.iconName !== ""
            theme: root.theme
            name: root.iconName
            sizeRole: "small"
            color: root.destructive
                ? root.theme.semantic.status.danger
                : root.active ? root.theme.component.control.onActive
                : root.enabled ? root.theme.component.control.text : root.theme.component.control.textDisabled
        }

        ShellText {
            visible: root.label !== ""
            theme: root.theme
            text: root.label
            sizeRole: "label"
            color: root.destructive
                ? root.theme.semantic.status.danger
                : root.active ? root.theme.component.control.onActive
                : root.enabled ? root.theme.component.control.text : root.theme.component.control.textDisabled
        }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
