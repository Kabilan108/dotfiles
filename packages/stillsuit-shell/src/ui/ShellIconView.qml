// SPDX-License-Identifier: MIT
import QtQuick

Item {
    id: root
    required property var theme
    property string name: "settings"
    property url source: ""
    property color color: theme.component.bar.clusterText
    property string sizeRole: "small"
    implicitWidth: glyph.implicitWidth
    implicitHeight: glyph.implicitHeight

    // A caller-supplied source (plugin assets such as provider marks) renders
    // as-is; the named catalog icon fills in when there is none or it fails.
    Image {
        id: image
        anchors.fill: parent
        source: root.source
        sourceSize.width: Math.ceil(width)
        sourceSize.height: Math.ceil(height)
        fillMode: Image.PreserveAspectFit
        mipmap: true
    }
    ShellIcon {
        id: glyph
        anchors.centerIn: parent
        visible: image.status !== Image.Ready
        theme: root.theme
        name: root.name
        sizeRole: root.sizeRole
        color: root.color
    }
}
