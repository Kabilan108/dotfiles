import QtQuick

Text {
    id: root

    required property var theme
    property string name: "circle"
    property string role: "primary"
    property string sizeRole: "medium"

    text: _glyph(name)
    color: _contentColor(role)
    font.family: theme.typography.iconFamily
    font.pixelSize: _iconSize(sizeRole)
    font.weight: theme.typography.weightRegular
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering

    function _glyph(iconName) {
        var icons = {
            "agent": "\uf10d",
            "audio": "\ue050",
            "battery": "\ue1a4",
            "bluetooth": "\ue1a7",
            "brightness": "\ue1ac",
            "check": "\ue5ca",
            "chevron-right": "\ue5cc",
            "close": "\ue5cd",
            "cpu": "\ue322",
            "danger": "\ue002",
            "info": "\ue88e",
            "memory": "\ue322",
            "microphone": "\ue029",
            "network": "\ue63e",
            "notifications": "\ue7f4",
            "pause": "\ue034",
            "play": "\ue037",
            "power": "\ue8ac",
            "record": "\uf679",
            "refresh": "\ue5d5",
            "search": "\ue8b6",
            "settings": "\ue8b8",
            "success": "\ue86c",
            "warning": "\uf083",
            "wifi": "\ue63e"
        }
        return icons[iconName] !== undefined ? icons[iconName] : "\ue061"
    }

    function _contentColor(name) {
        var content = theme && theme.semantic ? theme.semantic.content : null
        return content && content[name] !== undefined ? content[name] : "#ffffff"
    }

    function _iconSize(name) {
        if (!theme || !theme.metrics)
            return 18
        if (name === "small")
            return theme.metrics.iconSmall
        if (name === "large")
            return theme.metrics.iconLarge
        return theme.metrics.iconMedium
    }
}
