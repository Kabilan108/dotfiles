// SPDX-License-Identifier: MIT

import QtQuick

Rectangle {
    id: root

    required property var theme
    default property alias content: contentItem.data
    property string kind: "panel"
    property bool selected: false
    property bool danger: false
    property bool bordered: kind !== "raised"
    property real fillOpacity: selected || danger || kind === "raised" || kind === "osd"
        ? 1
        : theme.effects.surfaceOpacity

    color: _withAlpha(_fillColor(), fillOpacity)
    radius: kind === "bar" || kind === "osd"
        ? theme.metrics.radiusMedium
        : kind === "raised"
            ? theme.metrics.radiusSmall
            : theme.metrics.radiusLarge
    border.width: bordered && !selected && !danger ? 1 : 0
    border.color: kind === "bar"
        ? theme.component.bar.border
        : kind === "osd"
            ? theme.component.osd.border
            : kind === "notification"
                ? theme.component.notification.border
                : theme.component.panel.border
    clip: true

    Item {
        id: contentItem

        anchors.fill: parent
    }

    function _fillColor() {
        if (danger)
            return theme.component.panel.rowDanger
        if (selected)
            return theme.component.panel.rowSelected
        if (kind === "bar")
            return theme.component.bar.background
        if (kind === "osd")
            return theme.semantic.surface.panel
        if (kind === "notification")
            return theme.component.notification.background
        if (kind === "raised")
            return theme.component.panel.section
        return theme.component.panel.background
    }

    function _withAlpha(value, alpha) {
        var parsed = Qt.color(value)
        return Qt.rgba(parsed.r, parsed.g, parsed.b,
            Math.max(0, Math.min(1, alpha)))
    }
}
