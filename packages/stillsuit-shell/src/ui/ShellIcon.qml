// SPDX-License-Identifier: MIT

import QtQuick

Text {
    id: root

    required property var theme
    property string name: "circle"
    property string role: "primary"
    property string sizeRole: "medium"
    property string accessibleName: ""

    text: _glyph(name)
    color: _roleColor(role)
    font.family: theme.typography.iconFamily
    font.pixelSize: _iconSize(sizeRole)
    font.weight: theme.typography.weightRegular
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering

    function _glyph(iconName) {
        var icons = {
            "add": "\ue145",
            "agent": "\uf10d",
            "audio": "\ue050",
            "battery": "\ue1a4",
            "bluetooth": "\ue1a7",
            "brightness": "\ue1ac",
            "check": "\ue5ca",
            "chevron-left": "\ue5cb",
            "chevron-right": "\ue5cc",
            "circle": "\ue061",
            "close": "\ue5cd",
            "copy": "\ue14d",
            "cpu": "\ue322",
            "danger": "\ue002",
            "delete": "\ue872",
            "edit": "\ue3c9",
            "folder": "\ue2c7",
            "headphones": "\uf01f",
            "info": "\ue88e",
            "lock": "\ue897",
            "memory": "\ue322",
            "microphone": "\ue029",
            "more": "\ue5d4",
            "network": "\ue63e",
            "notifications": "\ue7f4",
            "pause": "\ue034",
            "play": "\ue037",
            "power": "\ue8ac",
            "record": "\uf679",
            "refresh": "\ue5d5",
            "repeat": "\ue040",
            "search": "\ue8b6",
            "settings": "\ue8b8",
            "shuffle": "\ue043",
            "skip-next": "\ue044",
            "skip-previous": "\ue045",
            "success": "\ue86c",
            "unlock": "\ue898",
            "volume-down": "\ue04d",
            "volume-mute": "\ue04f",
            "volume-up": "\ue050",
            "vpn": "\ue0da",
            "warning": "\uf083",
            "wifi": "\ue63e",
            "wifi-off": "\ue648"
        }
        return icons[iconName] !== undefined ? icons[iconName] : icons.circle
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
