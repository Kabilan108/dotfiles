import QtQuick
import Quickshell.Services.UPower

QtObject {
    id: root

    required property var context
    property var model: null
    property bool forceUnavailable: false
    readonly property string apiVersion: "1"
    readonly property var device: model ? model.device || null : UPower.displayDevice
    readonly property bool present: device !== null && Boolean(device.isPresent !== undefined ? device.isPresent : true)
    readonly property bool available: !forceUnavailable && present
    readonly property int percentage: present ? Math.round(Number(device.percentage || 0) * (Number(device.percentage || 0) <= 1 ? 100 : 1)) : 0
    readonly property string state: model ? String(model.state || "unknown") : _stateName(device ? device.state : null)
    readonly property bool charging: state === "charging"
    readonly property bool discharging: state === "discharging"
    readonly property bool low: present && discharging && percentage <= 20
    readonly property string timeText: _timeText()
    readonly property int revision: model && model.revision !== undefined ? Number(model.revision) : 0
    function _stateName(value) {
        if (value === UPowerDeviceState.Charging) return "charging"
        if (value === UPowerDeviceState.Discharging) return "discharging"
        if (value === UPowerDeviceState.FullyCharged) return "fully-charged"
        if (value === UPowerDeviceState.Empty) return "empty"
        return "unknown"
    }
    function _timeText() {
        if (!present) return ""
        var seconds = Number(device.timeToEmpty || device.timeToFull || 0)
        if (!isFinite(seconds) || seconds <= 0 || seconds >= 86400) return ""
        var minutes = Math.round(seconds / 60)
        return Math.floor(minutes / 60) + "h " + String(minutes % 60).padStart(2, "0") + "m"
    }
}
