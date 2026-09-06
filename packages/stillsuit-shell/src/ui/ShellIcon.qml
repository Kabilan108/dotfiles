// SPDX-License-Identifier: MIT

import QtQuick
import QtQuick.Effects

Item {
    id: root

    required property var theme
    property string name: "circle"
    property string role: "primary"
    property string sizeRole: "medium"
    property string accessibleName: ""
    property color color: _roleColor(role)
    property real pixelSize: _iconSize(sizeRole)
    readonly property url source: _source(name)
    readonly property bool ready: image.status === Image.Ready

    implicitWidth: pixelSize
    implicitHeight: pixelSize
    Accessible.name: accessibleName !== "" ? accessibleName : name.replace(/-/g, " ")

    Image {
        id: image
        anchors.fill: parent
        source: root.source
        sourceSize.width: Math.ceil(width)
        sourceSize.height: Math.ceil(height)
        fillMode: Image.PreserveAspectFit
        smooth: true
        layer.enabled: true
        layer.effect: MultiEffect {
            colorization: 1.0
            colorizationColor: root.color
        }
    }

    function _source(iconName) {
        var known = _catalog()
        var key = known.indexOf(iconName) >= 0 ? iconName : "circle"
        return Qt.resolvedUrl("icons/" + key + ".svg")
    }

    function _catalog() {
        return [
            "add", "agent", "audio", "battery", "battery-alert", "battery-charging",
            "battery-level-0", "battery-level-1", "battery-level-2", "battery-level-3",
            "battery-level-4", "battery-level-5", "battery-level-6", "battery-level-full",
            "battery-question", "bluetooth", "brightness", "check", "chevron-left",
            "chevron-right", "circle", "close", "copy", "cpu", "danger", "delete", "edit",
            "ethernet", "expand-less", "expand-more", "folder", "forward-10", "headphones",
            "info", "lock", "memory", "microphone", "more", "network", "notifications",
            "pause", "play", "power", "record", "refresh", "replay-10", "repeat", "search",
            "settings", "shuffle", "skip-next", "skip-previous", "success", "unlock",
            "volume-down", "volume-mute", "volume-up", "vpn", "warning", "wifi", "wifi-off"
        ]
    }

    function _roleColor(name) {
        if (theme.semantic.content[name] !== undefined)
            return theme.semantic.content[name]
        if (theme.semantic.status[name] !== undefined)
            return theme.semantic.status[name]
        if (theme.semantic.signal[name] !== undefined)
            return theme.semantic.signal[name]
        if (name === "accent")
            return theme.semantic.accent.primary
        if (name === "on-accent")
            return theme.semantic.accent.onAccent
        return theme.semantic.content.primary
    }

    function _iconSize(name) {
        if (name === "small")
            return theme.metrics.iconSmall
        if (name === "large")
            return theme.metrics.iconLarge
        return theme.metrics.iconMedium
    }
}
