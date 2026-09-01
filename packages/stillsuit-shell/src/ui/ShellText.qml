import QtQuick

Text {
    id: root

    required property var theme
    property string role: "primary"
    property string sizeRole: "body"
    property bool monospace: false

    color: _contentColor(role)
    font.family: monospace ? theme.typography.monoFamily : theme.typography.bodyFamily
    font.pixelSize: _fontSize(sizeRole)
    font.weight: sizeRole === "heading"
        ? theme.typography.weightBold
        : sizeRole === "label" ? theme.typography.weightMedium : theme.typography.weightRegular
    renderType: Text.NativeRendering

    function _contentColor(name) {
        var content = theme && theme.semantic ? theme.semantic.content : null
        return content && content[name] !== undefined ? content[name] : "#ffffff"
    }

    function _fontSize(name) {
        if (!theme || !theme.typography)
            return 13
        if (name === "caption")
            return theme.typography.captionSize
        if (name === "heading")
            return theme.typography.headingSize
        if (name === "label")
            return theme.typography.baseSize
        return theme.typography.baseSize
    }
}
