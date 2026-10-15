import QtQuick
import Quickshell.Io

Item {
    id: root
    required property var theme
    property bool desktop: false
    property bool server: false
    property color color: theme.semantic.content.secondary
    readonly property url assetSource: Qt.resolvedUrl(server || desktop ? "assets/server.svg" : "assets/laptop.svg")
    readonly property bool ready: glyph.status === Image.Ready
    implicitWidth: theme.metrics.iconMedium
    implicitHeight: theme.metrics.iconMedium

    // Lucide uses stroked currentColor SVGs; resolve the theme color before Qt
    // decodes them. Keep the vendored geometry intact.
    property FileView assetFile: FileView {
        path: root.assetSource
        preload: false
        blockLoading: true
        blockAllReads: true
        printErrors: false
    }

    Image {
        id: glyph
        anchors.fill: parent
        source: "data:image/svg+xml;utf8," + encodeURIComponent(
            root.assetFile.text().replace(/currentColor/g, String(root.color)))
        sourceSize.width: Math.ceil(width)
        sourceSize.height: Math.ceil(height)
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
}
