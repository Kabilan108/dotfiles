// SPDX-License-Identifier: MIT

import QtQuick
import QtQuick.Layouts

ShellAction {
    id: root

    required property var theme
    property string label: "Toggle"
    property string description: ""
    property bool checked: false
    property bool reducedMotion: false

    readonly property int fastMotionDuration: reducedMotion ? 0 : theme.motion.fast
    readonly property int normalMotionDuration: reducedMotion ? 0 : theme.motion.normal

    // Owner-controlled by design: the component proposes the next state and
    // does not change checked until the owner accepts and publishes it.
    signal toggled(bool requestedChecked)

    accessibleFallback: label
    implicitWidth: 260
    implicitHeight: Math.max(textColumn.implicitHeight, track.height)
    onActivated: toggled(!checked)

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
            role: root.enabled ? "primary" : "disabled"
        }

        ShellText {
            visible: root.description !== ""
            theme: root.theme
            text: root.description
            role: root.enabled ? "muted" : "disabled"
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
        radius: height / 2
        color: !root.enabled
            ? root.theme.component.control.disabled
            : root.checked
                ? root.theme.component.control.active
                : root.theme.component.control.background
        border.width: root.focusVisible ? 2 : 1
        border.color: root.focusVisible
            ? root.theme.component.control.focus
            : root.checked
                ? root.theme.component.control.active
                : root.theme.component.control.outline
        opacity: root.busy ? 0.82 : 1

        Behavior on color {
            ColorAnimation {
                duration: root.fastMotionDuration
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            visible: !root.busy
            width: 16
            height: 16
            radius: height / 2
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 3 : 3
            color: root.checked
                ? root.theme.component.control.onActive
                : root.theme.semantic.content.secondary

            Behavior on x {
                NumberAnimation {
                    duration: root.normalMotionDuration
                    easing.type: Easing.OutCubic
                }
            }
        }

        ShellBusyIndicator {
            visible: root.busy
            anchors.centerIn: parent
            theme: root.theme
            reducedMotion: root.reducedMotion
            sizeRole: "small"
            color: root.checked
                ? root.theme.component.control.onActive
                : root.theme.component.control.textDisabled
        }
    }
}
