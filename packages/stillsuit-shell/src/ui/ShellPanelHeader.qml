// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property var theme
    property string title: ""
    property string subtitle: ""
    default property alias trailingActions: actions.data
    spacing: 4
    data: [RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            ShellText {
                Layout.fillWidth: true
                theme: root.theme
                text: root.title
                sizeRole: "heading"
                elide: Text.ElideRight
            }
            ShellText {
                visible: root.subtitle !== ""
                Layout.fillWidth: true
                theme: root.theme
                text: root.subtitle
                role: "muted"
                sizeRole: "caption"
                elide: Text.ElideRight
            }
        }
        RowLayout { id: actions; spacing: 4 }
    },
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: root.theme.semantic.outline.subtle
    }]
}
