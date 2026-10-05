// SPDX-License-Identifier: MIT

import QtQuick
import Quickshell

Item {
    id: root

    required property var theme
    // A freedesktop icon name ("org.gnome.Nautilus") or an absolute path.
    property string icon: ""
    // Shown as a monogram when the icon cannot be resolved; the catalog
    // glyph is used when this is empty.
    property string fallbackLabel: ""
    property string fallbackIconName: "circle"
    property string sizeRole: "large"
    property real pixelSize: _iconSize(sizeRole)
    readonly property url resolvedSource: _resolve(icon)
    readonly property bool ready: image.status === Image.Ready

    implicitWidth: pixelSize
    implicitHeight: pixelSize

    Image {
        id: image
        anchors.fill: parent
        source: root.resolvedSource
        asynchronous: true
        sourceSize.width: Math.ceil(width)
        sourceSize.height: Math.ceil(height)
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Rectangle {
        anchors.fill: parent
        visible: !root.ready && root.fallbackLabel !== ""
        radius: root.theme.metrics.radiusSmall
        color: root.theme.semantic.accent.subtle
        ShellText {
            anchors.centerIn: parent
            theme: root.theme
            text: root.fallbackLabel.charAt(0).toUpperCase()
            role: "accent"
            sizeRole: "label"
            font.pixelSize: Math.max(8, Math.round(root.pixelSize * 0.5))
        }
    }

    ShellIcon {
        anchors.fill: parent
        visible: !root.ready && root.fallbackLabel === ""
        theme: root.theme
        name: root.fallbackIconName
        role: "muted"
        pixelSize: root.pixelSize
    }

    function _resolve(value) {
        var name = String(value || "")
        if (name === "")
            return ""
        if (name.charAt(0) === "/")
            return "file://" + name.split("/").map(encodeURIComponent).join("/")
        return Quickshell.iconPath(name, true)
    }

    function _iconSize(name) {
        if (name === "small")
            return theme.metrics.iconSmall
        if (name === "medium")
            return theme.metrics.iconMedium
        return theme.metrics.iconLarge
    }
}
