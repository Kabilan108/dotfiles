// SPDX-License-Identifier: MIT

import QtQuick
import QtQuick.Layouts

ShellAction {
    id: root

    required property var theme
    default property alias trailingContent: trailingSlot.data
    property string label: ""
    property string description: ""
    property string iconName: ""
    property string trailingIconName: ""
    property string trailingText: ""
    property bool reserveIconColumn: true
    property bool selected: false
    property bool danger: false
    property bool reducedMotion: false

    readonly property int motionDuration: reducedMotion ? 0 : theme.motion.fast
    readonly property int visualBorderWidth: background.border.width

    signal clicked()

    accessibleFallback: label
    implicitWidth: 300
    implicitHeight: Math.max(theme.metrics.rowHeight, rowContent.implicitHeight)
    onActivated: clicked()

    Rectangle {
        id: background

        anchors.fill: parent
        radius: root.theme.metrics.radiusSmall
        color: root.danger
            ? root.theme.component.panel.rowDanger
            : root.selected
                ? root.theme.component.panel.rowSelected
                : root.pressed
                    ? root.theme.semantic.surface.pressed
                    : root.hovered && root.interactive
                        ? root.theme.component.panel.rowHover
                        : "transparent"
        border.width: 0
        opacity: !root.enabled ? 0.64 : root.busy ? 0.76 : 1

        Behavior on color {
            ColorAnimation {
                duration: root.motionDuration
                easing.type: Easing.OutCubic
            }
        }
    }

    RowLayout {
        id: rowContent

        anchors {
            fill: parent
            leftMargin: 10
            rightMargin: 10
        }
        spacing: 8

        Item {
            visible: root.reserveIconColumn || root.iconName !== ""
            Layout.preferredWidth: root.theme.metrics.iconMedium
            Layout.preferredHeight: root.theme.metrics.iconMedium

            ShellIcon {
                visible: root.iconName !== ""
                anchors.centerIn: parent
                theme: root.theme
                name: root.iconName
                sizeRole: "small"
                role: root.danger ? "danger" : root.selected ? "accent" : "secondary"
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            ShellText {
                Layout.fillWidth: true
                theme: root.theme
                text: root.label
                sizeRole: "label"
                role: !root.enabled
                    ? "disabled"
                    : root.danger
                        ? "danger"
                        : "primary"
                elide: Text.ElideRight
            }

            ShellText {
                visible: root.description !== ""
                Layout.fillWidth: true
                theme: root.theme
                text: root.description
                sizeRole: "caption"
                role: root.enabled ? "muted" : "disabled"
                elide: Text.ElideRight
            }
        }

        ShellText {
            visible: root.trailingText !== ""
            theme: root.theme
            text: root.trailingText
            sizeRole: "caption"
            monospace: true
            role: root.danger ? "danger" : "secondary"
        }

        ShellBusyIndicator {
            visible: root.busy
            theme: root.theme
            reducedMotion: root.reducedMotion
            sizeRole: "small"
            role: root.danger ? "danger" : "accent"
        }

        ShellIcon {
            visible: !root.busy && root.trailingIconName !== ""
            theme: root.theme
            name: root.trailingIconName
            sizeRole: "small"
            role: root.danger ? "danger" : root.selected ? "accent" : "secondary"
        }

        RowLayout {
            id: trailingSlot

            visible: children.length > 0
            spacing: 6
        }
    }
}
