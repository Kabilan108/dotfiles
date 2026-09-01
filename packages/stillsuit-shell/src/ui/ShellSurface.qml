import QtQuick

Rectangle {
    id: root

    required property var theme
    default property alias content: contentItem.data
    property string kind: "panel"
    property bool selected: false
    property real fillOpacity: kind === "raised" ? 1 : theme.effects.surfaceOpacity

    color: _withAlpha(_fillColor(), fillOpacity)
    radius: kind === "bar"
        ? theme.metrics.radiusMedium
        : kind === "raised" ? theme.metrics.radiusSmall : theme.metrics.radiusLarge
    border.width: 1
    border.color: kind === "bar" ? theme.component.bar.border : theme.component.panel.border
    clip: true

    Item {
        id: contentItem
        anchors.fill: parent
    }

    function _fillColor() {
        if (selected)
            return theme.semantic.surface.selected
        if (kind === "bar")
            return theme.component.bar.background
        if (kind === "raised")
            return theme.semantic.surface.raised
        return theme.component.panel.background
    }

    function _withAlpha(value, alpha) {
        var parsed = Qt.color(value)
        return Qt.rgba(parsed.r, parsed.g, parsed.b, Math.max(0, Math.min(1, alpha)))
    }
}
