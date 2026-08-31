import QtQuick
import Quickshell.Networking

QtObject {
    id: root

    required property var context
    property var model: null
    readonly property string apiVersion: "1"
    readonly property var devices: model ? model.devices || [] : (Networking.devices ? Networking.devices.values : [])
    readonly property bool wifiEnabled: model ? Boolean(model.wifiEnabled) : Networking.wifiEnabled
    readonly property var networks: model ? model.networks || [] : _wifiNetworks()
    readonly property var vpns: model ? model.vpns || [] : []
    readonly property bool wiredConnected: model ? Boolean(model.wiredConnected) : _wiredConnected()
    readonly property var connectedNetwork: _connected()
    readonly property bool available: model !== null || devices.length > 0
    readonly property int revision: model && model.revision !== undefined ? Number(model.revision) : 0

    function _wifiNetworks() {
        for (var index = 0; index < devices.length; index++) {
            var device = devices[index]
            if (device && device.type === DeviceType.Wifi)
                return device.networks ? device.networks.values : []
        }
        return []
    }
    function _wiredConnected() {
        for (var index = 0; index < devices.length; index++) {
            var device = devices[index]
            if (device && Boolean(device.connected) && device.type === DeviceType.Wired)
                return true
        }
        return false
    }
    function _connected() {
        for (var index = 0; index < networks.length; index++)
            if (networks[index] && networks[index].connected)
                return networks[index]
        return null
    }
    function scan() { return model && typeof model.scan === "function" ? model.scan() : "unavailable" }
    function setWifiEnabled(enabled) { return model && typeof model.setWifiEnabled === "function" ? model.setWifiEnabled(Boolean(enabled)) : "unavailable" }
    function activate(network) {
        if (model && typeof model.activate === "function") return model.activate(network)
        if (network && network.connected && typeof network.disconnect === "function") { network.disconnect(); return "ok" }
        if (network && typeof network.connect === "function") { network.connect(); return "ok" }
        return "unavailable"
    }
    function toggleVpn(vpn) { return model && typeof model.toggleVpn === "function" ? model.toggleVpn(vpn) : "unavailable" }
}
