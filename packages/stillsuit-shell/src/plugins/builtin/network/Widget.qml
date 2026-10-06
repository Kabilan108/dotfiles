import QtQuick
import "../../../ui" as Ui

Ui.ShellBarCluster {
    id: root

    required property var context
    required property var service
    required property string outputId

    readonly property int signalPercentage: service && service.connectedNetwork
        ? service.signalPercentage(service.connectedNetwork)
        : 0
    readonly property bool userOperationBusy: Boolean(service)
        && ["join", "disconnect", "wifi-enabled", "vpn-toggle"].indexOf(service.operation) !== -1
    readonly property bool vpnConnected: service ? service.vpns.some(function(vpn) {
        return vpn && vpn.active
    }) : false

    theme: context.theme
    iconName: !service ? "wifi-off"
        : service.wiredConnected ? "ethernet"
        : service.wifiEnabled ? "wifi" : "wifi-off"
    secondaryIconName: vpnConnected ? "vpn" : ""
    selected: context.panels && context.panels.selectedId === "stillsuit.network"
        && context.panels.selectedOutputId === outputId
    busy: userOperationBusy
    accessibleName: (!service || !service.available ? "Network unavailable"
        : service.wiredConnected ? "Wired network connected"
        : service.connectedNetwork
            ? "Connected to " + service.connectedNetwork.name
                + " at " + signalPercentage + " percent signal"
            : service.wifiEnabled ? "Wi-Fi enabled, not connected" : "Wi-Fi disabled")
        + (vpnConnected ? ", VPN connected" : "")
    onClicked: context.actions.surfaceToggle("stillsuit.network", JSON.stringify({outputId: root.outputId}))
}
