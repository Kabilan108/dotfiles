// SPDX-License-Identifier: MIT

import QtQuick
import QtQuick.Layouts

ShellAction {
    id: root

    required property var theme
    property string label: "Button"
    property string iconName: ""
    property bool active: false
    property bool destructive: false
    property bool compact: false
    property bool ghost: false
    property bool reducedMotion: false

    readonly property int motionDuration: reducedMotion ? 0 : theme.motion.fast

    signal clicked()

    accessibleFallback: label !== ""
        ? label
        : iconName !== ""
            ? iconName.replace(/-/g, " ")
            : "button"
    implicitWidth: Math.max(compact ? 30 : 36,
        contentRow.implicitWidth + (compact ? 18 : 24))
    implicitHeight: compact ? 30 : 36
    onActivated: clicked()

    Rectangle {
        anchors.fill: parent
        radius: root.theme.metrics.radiusSmall
        color: !root.enabled
            ? root.theme.component.control.disabled
            : root.ghost
                ? root.active
                    ? root.theme.component.bar.clusterActive
                    : root.pressed
                        ? root.theme.component.control.pressed
                        : root.hovered
                            ? root.theme.component.control.hover
                            : "transparent"
                : root.active
                    ? root.theme.component.control.active
                    : root.pressed
                        ? root.theme.component.control.pressed
                        : root.hovered
                            ? root.theme.component.control.hover
                            : root.theme.component.control.background
        border.width: root.ghost ? 0 : 1
        border.color: root.destructive
                ? root.theme.semantic.status.danger
                : root.theme.component.control.outline
        opacity: !root.enabled ? 0.74 : root.busy ? 0.82 : 1

        Behavior on color {
            ColorAnimation {
                duration: root.motionDuration
                easing.type: Easing.OutCubic
            }
        }
    }

    RowLayout {
        id: contentRow

        anchors.centerIn: parent
        spacing: 6

        ShellBusyIndicator {
            visible: root.busy
            theme: root.theme
            reducedMotion: root.reducedMotion
            sizeRole: "small"
            color: root._foregroundColor()
        }

        ShellIcon {
            visible: !root.busy && root.iconName !== ""
            theme: root.theme
            name: root.iconName
            sizeRole: "small"
            color: root._foregroundColor()
        }

        ShellText {
            visible: root.label !== ""
            theme: root.theme
            text: root.label
            sizeRole: "label"
            color: root._foregroundColor()
        }
    }

    function _foregroundColor() {
        if (destructive)
            return theme.semantic.status.danger
        if (active)
            return theme.component.control.onActive
        return enabled
            ? theme.component.control.text
            : theme.component.control.textDisabled
    }
}
