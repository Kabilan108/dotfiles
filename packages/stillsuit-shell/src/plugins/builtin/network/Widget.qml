import QtQuick

Rectangle {
    id: root
    required property var context
    readonly property var network: context.services.get("stillsuit.network")
    implicitWidth: 64
    implicitHeight: context.theme.geometry.barHeight
    radius: context.theme.geometry.radius
    color: mouse.containsMouse ? context.theme.controls.hover.fill : "transparent"
    Text { anchors.centerIn: parent; text: !network || !network.available ? "NET --" : network.wiredConnected ? "NET LAN" : network.connectedNetwork ? "NET " + Math.round(Number(network.connectedNetwork.signalStrength || 0) * 100) + "%" : "NET off"; color: root.context.theme.colors.text.primary; font.family: root.context.theme.typography.monospaceFamily; font.pixelSize: root.context.theme.typography.baseSize }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.context.actions.surfaceToggle("stillsuit.network", "") }
}
