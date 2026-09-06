// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls as Controls

Flickable {
    id: root
    required property var theme
    property real maximumHeight: 244
    implicitHeight: Math.min(contentHeight, maximumHeight)
    contentWidth: width
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height
    Controls.ScrollBar.vertical: Controls.ScrollBar {
        policy: Controls.ScrollBar.AsNeeded
        width: 3
        contentItem: Rectangle {
            implicitWidth: 3
            radius: 1.5
            color: root.theme.semantic.outline.strong
            opacity: parent.active ? 1 : 0.5
        }
    }
}
