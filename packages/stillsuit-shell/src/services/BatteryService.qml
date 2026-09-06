import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower

QtObject {
    id: root

    required property var context
    property var model: null
    property bool forceUnavailable: false
    readonly property string apiVersion: "1"
    readonly property var device: model ? model.device || null : UPower.displayDevice
    readonly property var physicalDevice: model && model.detailDevice
        ? model.detailDevice
        : _physicalBattery()
    readonly property bool present: device !== null
        && Boolean(device.isPresent !== undefined ? device.isPresent : true)
    readonly property bool available: !forceUnavailable && present
    // Quickshell 0.3 converts UPower's 0-100 D-Bus value to a 0.0-1.0 value.
    readonly property int percentage: present ? _percentage(device.percentage) : 0
    readonly property string state: model
        ? String(model.state || "unknown")
        : _stateName(device ? device.state : null)
    readonly property string stateLabel: _stateLabel(state)
    readonly property bool charging: state === "charging"
    readonly property bool discharging: state === "discharging"
    readonly property bool pending: state === "pending-charge"
        || state === "pending-discharge"
    readonly property bool low: present && discharging && percentage <= 20
    readonly property string timeText: _timeText()
    readonly property var normalizedDetails: _normalizeDetails(
        model && model.details !== undefined ? model.details : details)
    readonly property var healthPercent: normalizedDetails.healthPercent
    readonly property var capacityWh: normalizedDetails.capacityWh
    readonly property var designCapacityWh: normalizedDetails.designCapacityWh
    readonly property var cycleCount: normalizedDetails.cycleCount
    readonly property var powerDrawWatts: _livePowerDraw()
    readonly property var chargeStartThreshold: normalizedDetails.chargeStartThreshold
    readonly property var chargeEndThreshold: normalizedDetails.chargeEndThreshold
    readonly property bool chargeThresholdSupported:
        normalizedDetails.chargeThresholdSupported
        || chargeStartThreshold !== null
        || chargeEndThreshold !== null
    readonly property int revision: model && model.revision !== undefined
        ? Number(model.revision)
        : detailRevision
    readonly property var detailHelperArgv: ["upower", "--dump"]

    property var details: ({})
    property int detailRevision: 0
    property string detailError: ""

    property Process detailProcess: Process {
        id: detailProcess

        command: root.detailHelperArgv
        stdout: StdioCollector {
            id: detailOutput
            waitForEnd: true
        }
        onExited: function(exitCode) {
            root._finishDetailsRefresh(exitCode, detailOutput.text)
        }
    }

    property Timer detailTimer: Timer {
        interval: 30000
        running: root.model === null
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshDetails()
    }

    function refreshDetails() {
        if (model || detailProcess.running)
            return
        detailProcess.running = true
    }

    function _finishDetailsRefresh(exitCode, text) {
        if (Number(exitCode) !== 0) {
            detailError = "Battery details are unavailable."
            return
        }
        var parsed = _parseDetails(text)
        if (Object.keys(parsed).length === 0) {
            detailError = "Battery details are unavailable."
            return
        }
        details = parsed
        detailError = ""
        detailRevision++
    }

    function _percentage(value) {
        var normalized = Number(value)
        if (!isFinite(normalized))
            return 0
        return Math.round(Math.max(0, Math.min(1, normalized)) * 100)
    }

    function _stateName(value) {
        if (value === UPowerDeviceState.Charging)
            return "charging"
        if (value === UPowerDeviceState.Discharging)
            return "discharging"
        if (value === UPowerDeviceState.FullyCharged)
            return "fully-charged"
        if (value === UPowerDeviceState.Empty)
            return "empty"
        if (value === UPowerDeviceState.PendingCharge)
            return "pending-charge"
        if (value === UPowerDeviceState.PendingDischarge)
            return "pending-discharge"
        return "unknown"
    }

    function _stateLabel(value) {
        if (value === "charging")
            return "Charging"
        if (value === "discharging")
            return "On battery"
        if (value === "fully-charged")
            return "Fully charged"
        if (value === "empty")
            return "Empty"
        if (value === "pending-charge")
            return "Waiting to charge"
        if (value === "pending-discharge")
            return "Waiting to discharge"
        return present ? "State unavailable" : "No battery"
    }

    function _timeText() {
        if (!present)
            return ""
        var seconds = 0
        if (state === "discharging")
            seconds = Number(device.timeToEmpty || 0)
        else if (state === "charging")
            seconds = Number(device.timeToFull || 0)
        if (!isFinite(seconds) || seconds <= 0 || seconds >= 86400)
            return ""
        var minutes = Math.round(seconds / 60)
        if (minutes < 60)
            return minutes + "m"
        return Math.floor(minutes / 60) + "h "
            + String(minutes % 60).padStart(2, "0") + "m"
    }

    function _physicalBattery() {
        var devices = UPower.devices && UPower.devices.values
            ? UPower.devices.values
            : []
        for (var index = 0; index < devices.length; index++) {
            var candidate = devices[index]
            if (candidate && candidate.isLaptopBattery)
                return candidate
        }
        return device
    }

    function _livePowerDraw() {
        if (physicalDevice && physicalDevice.changeRate !== undefined) {
            var live = Number(physicalDevice.changeRate)
            if (isFinite(live) && live >= 0)
                return Math.round(live * 10) / 10
        }
        return normalizedDetails.powerDrawWatts
    }

    function _parseDetails(raw) {
        var text = String(raw || "")
        var blocks = text.split(/\n(?=Device:\s)/)
        var batteryBlock = ""
        for (var index = 0; index < blocks.length; index++) {
            if (/^Device:\s+.*\/battery_/m.test(blocks[index])) {
                batteryBlock = blocks[index]
                break
            }
        }
        if (batteryBlock === "" && text.indexOf("Device:") === -1)
            batteryBlock = text
        if (batteryBlock === "")
            return ({})
        return {
            healthPercent: _field(batteryBlock, "capacity"),
            capacityWh: _field(batteryBlock, "energy-full"),
            designCapacityWh: _field(batteryBlock, "energy-full-design"),
            cycleCount: _field(batteryBlock, "charge-cycles"),
            powerDrawWatts: _field(batteryBlock, "energy-rate"),
            chargeStartThreshold: _field(batteryBlock, "charge-start-threshold"),
            chargeEndThreshold: _field(batteryBlock, "charge-end-threshold"),
            chargeThresholdSupported: _field(
                batteryBlock, "charge-threshold-supported")
        }
    }

    function _field(text, key) {
        var lines = String(text || "").split("\n")
        var prefix = key + ":"
        for (var index = 0; index < lines.length; index++) {
            var line = lines[index].trim()
            if (line.slice(0, prefix.length) === prefix)
                return line.slice(prefix.length).trim()
        }
        return null
    }

    function _normalizeDetails(raw) {
        var source = raw || ({})
        return {
            healthPercent: _number(source.healthPercent, true, 0, 100),
            capacityWh: _number(source.capacityWh, false, 0, null),
            designCapacityWh: _number(
                source.designCapacityWh, false, 0, null),
            cycleCount: _integer(source.cycleCount, 0),
            powerDrawWatts: _number(source.powerDrawWatts, false, 0, null),
            chargeStartThreshold: _number(
                source.chargeStartThreshold, true, 0, 100),
            chargeEndThreshold: _number(
                source.chargeEndThreshold, true, 0, 100),
            chargeThresholdSupported: _boolean(
                source.chargeThresholdSupported)
        }
    }

    function _number(value, percent, minimum, maximum) {
        if (value === undefined || value === null || value === "")
            return null
        var text = String(value).trim()
        if (text === "" || text.toLowerCase() === "n/a")
            return null
        var parsed = Number.parseFloat(text)
        if (!isFinite(parsed))
            return null
        if (percent && text.indexOf("%") === -1 && parsed >= 0 && parsed <= 1)
            parsed *= 100
        parsed = Math.max(minimum, parsed)
        if (maximum !== null)
            parsed = Math.min(maximum, parsed)
        return Math.round(parsed * 10) / 10
    }

    function _integer(value, minimum) {
        var parsed = _number(value, false, minimum, null)
        return parsed === null ? null : Math.round(parsed)
    }

    function _boolean(value) {
        if (value === true || value === false)
            return value
        var text = String(value || "").trim().toLowerCase()
        return text === "yes" || text === "true" || text === "1"
    }
}
