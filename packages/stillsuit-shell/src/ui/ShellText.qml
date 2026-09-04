// SPDX-License-Identifier: MIT

import QtQuick

Text {
    id: root

    required property var theme
    property string role: "primary"
    property string sizeRole: "body"
    property bool monospace: false

    color: _roleColor(role)
    font.family: monospace
        ? theme.typography.monoFamily
        : theme.typography.bodyFamily
    font.pixelSize: _fontSize(sizeRole)
    font.weight: sizeRole === "heading"
        ? theme.typography.weightBold
        : sizeRole === "label" || sizeRole === "section"
            ? theme.typography.weightMedium
            : theme.typography.weightRegular
    renderType: Text.NativeRendering

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

    function _fontSize(name) {
        if (name === "caption" || name === "section")
            return theme.typography.captionSize
        if (name === "heading")
            return theme.typography.headingSize
        return theme.typography.baseSize
    }
}
