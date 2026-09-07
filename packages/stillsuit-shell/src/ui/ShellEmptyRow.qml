// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    required property var theme
    property string iconName: "info"
    property string text: ""
    property bool error: false
    property string iconSizeRole: "small"
    property string textSizeRole: "caption"
    implicitHeight: row.implicitHeight + 12
    implicitWidth: row.implicitWidth
    RowLayout {
        id: row
        anchors.centerIn: parent
        width: Math.min(implicitWidth, parent.width)
        spacing: 8
        ShellIcon {
            theme: root.theme
            name: root.iconName
            sizeRole: root.iconSizeRole
            role: root.error ? "danger" : "muted"
        }
        ShellText {
            Layout.fillWidth: true
            theme: root.theme
            text: root.text
            sizeRole: root.textSizeRole
            role: root.error ? "danger" : "muted"
            wrapMode: Text.Wrap
        }
    }
}
