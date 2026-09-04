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
    property bool wrap: false
    property int maximumLines: 3

    readonly property string effectiveAccessibleName: accessibleName !== ""
        ? accessibleName
        : label

    implicitWidth: statusRow.implicitWidth + (compact ? 12 : 16)
    implicitHeight: compact ? 22 : Math.max(28, statusRow.implicitHeight + 12)
    radius: theme.metrics.radiusSmall
    color: status === "danger"
        ? theme.component.panel.rowDanger
        : theme.component.panel.section
    border.width: 0

    RowLayout {
        id: statusRow

        anchors.fill: parent
        anchors.margins: root.compact ? 6 : 8
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
            Layout.fillWidth: true
            theme: root.theme
            text: root.label
            sizeRole: "caption"
            role: root._colorRole()
            wrapMode: root.wrap ? Text.Wrap : Text.NoWrap
            maximumLineCount: root.wrap ? root.maximumLines : 1
            elide: Text.ElideRight
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
