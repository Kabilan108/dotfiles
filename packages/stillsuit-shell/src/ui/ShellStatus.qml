// SPDX-License-Identifier: MIT

import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property var theme
    property string status: "info"
    property string label: ""
    property string iconName: ""
    property string accessibleName: ""
    property bool compact: false
    property bool showIcon: true

    readonly property string effectiveAccessibleName: accessibleName !== ""
        ? accessibleName
        : label

    implicitWidth: statusRow.implicitWidth + (compact ? 12 : 16)
    implicitHeight: compact ? 22 : 28
    radius: theme.metrics.radiusSmall
    color: status === "danger"
        ? theme.component.panel.rowDanger
        : theme.component.panel.section
    border.width: 0

    RowLayout {
        id: statusRow

        anchors.centerIn: parent
        spacing: 5

        ShellIcon {
            visible: root.showIcon
            theme: root.theme
            name: root.iconName !== "" ? root.iconName : root._defaultIcon()
            sizeRole: "small"
            role: root._colorRole()
        }

        ShellText {
            visible: root.label !== ""
            theme: root.theme
            text: root.label
            sizeRole: "caption"
            role: root._colorRole()
        }
    }

    function _colorRole() {
        return status === "muted" || status === "neutral" ? "muted" : status
    }

    function _defaultIcon() {
        if (status === "success")
            return "success"
        if (status === "warning")
            return "warning"
        if (status === "danger")
            return "danger"
        return "info"
    }
}
