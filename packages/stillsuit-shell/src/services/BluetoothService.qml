import QtQuick
import Quickshell.Bluetooth

QtObject {
    id: root

    required property var context
    property var model: null
    property bool forceUnavailable: false
    readonly property string apiVersion: "1"
    readonly property var adapter: model ? null : Bluetooth.defaultAdapter
    readonly property bool enabled: model ? Boolean(model.enabled) : Boolean(adapter && adapter.enabled)
    readonly property var devices: model ? model.devices || [] : (Bluetooth.devices ? Bluetooth.devices.values : [])
    readonly property bool available: !forceUnavailable && (model !== null || adapter !== null)
    readonly property bool connected: devices.some(function(device) { return device && device.connected })
    readonly property int revision: model && model.revision !== undefined ? Number(model.revision) : 0
    function setEnabled(enabled) {
        if (forceUnavailable) return "unavailable"
        if (model && typeof model.setEnabled === "function") return model.setEnabled(Boolean(enabled))
        if (!adapter) return "unavailable"
        adapter.enabled = Boolean(enabled)
        return "ok"
    }
    function scan() {
        if (forceUnavailable) return "unavailable"
        if (model && typeof model.scan === "function") return model.scan()
        if (!adapter) return "unavailable"
        adapter.discovering = !adapter.discovering
        return "ok"
    }
    function toggle(device) {
        if (forceUnavailable) return "unavailable"
        if (model && typeof model.toggle === "function") return model.toggle(device)
        if (!device) return "unavailable"
        device.connected = !device.connected
        return "ok"
    }
}
