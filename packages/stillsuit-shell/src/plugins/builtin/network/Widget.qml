import QtQuick

Rectangle {
    id: root
    required property var context
    required property var service
    required property string outputId
    implicitWidth: 64
    implicitHeight: context.theme.geometry.barHeight
    radius: context.theme.geometry.radius
    color: mouse.containsMouse ? context.theme.controls.hover.fill : "transparent"
    // Quickshell 0.3 exposes WifiNetwork.signalStrength from 0.0 to 1.0.
    readonly property int signalPercentage: {
        var normalized = service && service.connectedNetwork
            ? Number(service.connectedNetwork.signalStrength) : 0
        if (!isFinite(normalized)) return 0
        return Math.round(Math.max(0, Math.min(1, normalized)) * 100)
    }
    Text { anchors.centerIn: parent; text: !service || !service.available ? "NET --" : service.wiredConnected ? "NET LAN" : service.connectedNetwork ? "NET " + root.signalPercentage + "%" : "NET off"; color: root.context.theme.colors.text.primary; font.family: root.context.theme.typography.monospaceFamily; font.pixelSize: root.context.theme.typography.baseSize }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.context.actions.surfaceToggle("stillsuit.network", "") }
}
