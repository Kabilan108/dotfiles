import QtQuick
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire

QtObject {
    id: root

    required property var context
    property var model: null
    property bool forceUnavailable: false
    property string operation: "idle"
    property string operationTarget: ""
    property var pendingDevice: null
    property var failures: ({})
    property string lastError: ""
    property string lastResult: ""
    property int localRevision: 0
    property int audioAttempts: 0

    readonly property string apiVersion: "1"
    readonly property var adapter: model ? null : Bluetooth.defaultAdapter
    readonly property bool enabled: model ? Boolean(model.enabled) : Boolean(adapter && adapter.enabled)
    readonly property var devices: model ? model.devices || [] : (Bluetooth.devices ? Bluetooth.devices.values : [])
    readonly property bool available: !forceUnavailable && (model !== null || adapter !== null)
    readonly property bool connected: devices.some(function(device) { return device && device.connected })
    readonly property bool scanning: model
        ? Boolean(model.scanning)
        : Boolean(adapter && adapter.discovering)
    readonly property var connectedDevices: devices.filter(function(device) {
        return device && Boolean(device.connected)
    })
    readonly property var pairedDevices: devices.filter(function(device) {
        return device && !device.connected && Boolean(device.paired || device.bonded)
    })
    readonly property var availableDevices: devices.filter(function(device) {
        return device && !device.connected && !device.paired && !device.bonded
    })
    readonly property var pipewireNodes: model ? []
        : Pipewire.nodes ? Pipewire.nodes.values : []
    readonly property int revision: (model && model.revision !== undefined
        ? Number(model.revision)
        : 0) + localRevision

    property PwObjectTracker pipewireTracker: PwObjectTracker {
        objects: root.pipewireNodes
    }

    property Connections pendingDeviceConnections: Connections {
        target: root.pendingDevice
        ignoreUnknownSignals: true
        function onTargetChanged() {
            if (!target && root.operation === "forget")
                root._complete("forgotten")
        }
        function onConnectedChanged() { root._observePending() }
        function onStateChanged() { root._observePending() }
        function onPairedChanged() { root._observePending() }
        function onBondedChanged() { root._observePending() }
    }

    property Timer operationTimeout: Timer {
        interval: 20000
        repeat: false
        onTriggered: root._fail("Bluetooth operation timed out")
    }

    property Timer scanTimeout: Timer {
        interval: 12000
        repeat: false
        onTriggered: {
            if (!root.model && root.adapter)
                root.adapter.discovering = false
        }
    }

    property Timer audioRetry: Timer {
        interval: 300
        repeat: true
        onTriggered: root._tryAudioDefault()
    }

    function setEnabled(enabled) {
        if (forceUnavailable || operation !== "idle")
            return forceUnavailable ? "unavailable" : "busy"
        var requested = Boolean(enabled)
        lastError = ""
        if (model && typeof model.setEnabled === "function") {
            var modelResult = model.setEnabled(requested)
            return _finishImmediate(modelResult, "adapter")
        }
        if (!adapter)
            return "unavailable"
        operation = "adapter"
        operationTarget = "adapter"
        adapter.enabled = Boolean(enabled)
        operation = "idle"
        operationTarget = ""
        lastResult = "adapter"
        localRevision++
        return "ok"
    }

    function scan() {
        if (forceUnavailable)
            return "unavailable"
        lastError = ""
        if (model && typeof model.scan === "function")
            return _finishImmediate(model.scan(), "scan")
        if (!adapter || !enabled)
            return "unavailable"
        adapter.discovering = true
        scanTimeout.restart()
        lastResult = "scan"
        localRevision++
        return "ok"
    }

    function stopScan() {
        if (model && typeof model.stopScan === "function")
            return _finishImmediate(model.stopScan(), "scan-stopped")
        if (!adapter)
            return "unavailable"
        adapter.discovering = false
        scanTimeout.stop()
        localRevision++
        return "ok"
    }

    function toggle(device) {
        return device && device.connected ? disconnectDevice(device) : connectDevice(device)
    }

    function deviceId(device) {
        return device ? String(device.address || device.id || device.name || "") : ""
    }

    function deviceName(device) {
        if (!device)
            return "Unknown device"
        return String(device.name || device.deviceName || device.address || "Unknown device")
    }

    function batteryText(device) {
        if (!device || !device.batteryAvailable)
            return ""
        return Math.max(0, Math.min(100,
            Math.round(Number(device.battery || 0) * 100))) + "% battery"
    }

    function failureFor(device) {
        return String(failures[deviceId(device)] || "")
    }

    function statusFor(device) {
        if (!device)
            return "unavailable"
        var identifier = deviceId(device)
        if (operationTarget === identifier) {
            if (operation === "pair-connect")
                return "pairing"
            if (operation === "connect")
                return "connecting"
            if (operation === "disconnect")
                return "disconnecting"
            if (operation.indexOf("forget") === 0)
                return "forgetting"
            if (operation === "audio-default")
                return "selecting audio"
        }
        var state = String(device.state || "").toLowerCase()
        if (device.pairing)
            return "pairing"
        if (device.state === BluetoothDeviceState.Connecting
                || state.indexOf("connecting") !== -1)
            return "connecting"
        if (device.state === BluetoothDeviceState.Disconnecting
                || state.indexOf("disconnecting") !== -1)
            return "disconnecting"
        if (device.connected)
            return "connected"
        if (device.paired || device.bonded)
            return "paired"
        return "available"
    }

    function connectDevice(device) {
        if (!_begin("connect", device))
            return forceUnavailable ? "unavailable" : "busy"
        if (model) {
            var result = typeof model.connectDevice === "function"
                ? model.connectDevice(device)
                : typeof model.connect === "function"
                    ? model.connect(device)
                    : "unavailable"
            if (!_modelAccepted(result))
                return _fail(_modelError(result))
            _observePending()
            return lastError === "" ? "ok" : "error"
        }
        if (!device.paired && !device.bonded) {
            operation = "pair-connect"
            device.trusted = true
            device.pair()
        } else {
            device.trusted = true
            device.connect()
        }
        return "started"
    }

    function disconnectDevice(device) {
        if (!_begin("disconnect", device))
            return forceUnavailable ? "unavailable" : "busy"
        if (model) {
            var result = typeof model.disconnectDevice === "function"
                ? model.disconnectDevice(device)
                : typeof model.disconnect === "function"
                    ? model.disconnect(device)
                    : "unavailable"
            if (!_modelAccepted(result))
                return _fail(_modelError(result))
            _observePending()
            return lastError === "" ? "ok" : "error"
        }
        device.disconnect()
        return "started"
    }

    function forgetDevice(device) {
        if (!_begin(device && device.connected ? "forget-disconnect" : "forget", device))
            return forceUnavailable ? "unavailable" : "busy"
        if (model) {
            var result = typeof model.forgetDevice === "function"
                ? model.forgetDevice(device)
                : typeof model.forget === "function"
                    ? model.forget(device)
                    : "unavailable"
            if (!_modelAccepted(result))
                return _fail(_modelError(result))
            _observePending()
            return lastError === "" ? "ok" : "error"
        }
        if (device.connected)
            device.disconnect()
        else
            device.forget()
        return "started"
    }

    function _begin(nextOperation, device) {
        if (forceUnavailable || !device || operation !== "idle")
            return false
        operation = nextOperation
        operationTarget = deviceId(device)
        pendingDevice = device
        lastError = ""
        lastResult = ""
        _setFailure(operationTarget, "")
        operationTimeout.restart()
        localRevision++
        return true
    }

    function _observePending() {
        var device = pendingDevice
        if (!device)
            return
        if (operation === "pair-connect" && (device.paired || device.bonded)) {
            operation = "connect"
            device.trusted = true
            if (!model)
                device.connect()
        }
        if (operation === "connect" && device.connected) {
            _connectedSucceeded(device)
            return
        }
        if (operation === "disconnect" && !device.connected) {
            _complete("disconnected")
            return
        }
        if (operation === "forget-disconnect" && !device.connected) {
            operation = "forget"
            if (!model)
                device.forget()
        }
        if (operation === "forget" && !device.connected
                && !device.paired && !device.bonded)
            _complete("forgotten")
    }

    function _connectedSucceeded(device) {
        operation = "audio-default"
        operationTimeout.stop()
        audioAttempts = 0
        if (model) {
            var result = typeof model.makeDefaultAudio === "function"
                ? model.makeDefaultAudio(device)
                : "ok"
            if (_modelAccepted(result))
                _complete("connected")
            else
                _fail("Connected, but the audio output could not be selected: "
                    + _modelError(result))
            return
        }
        if (!_tryAudioDefault())
            audioRetry.start()
    }

    function _tryAudioDefault() {
        if (operation !== "audio-default" || !pendingDevice) {
            audioRetry.stop()
            return false
        }
        var address = _normalizeAddress(pendingDevice.address || "")
        for (var index = 0; index < pipewireNodes.length; index++) {
            var node = pipewireNodes[index]
            if (!node || !node.isSink)
                continue
            var properties = node.properties || ({})
            var candidates = [
                properties["api.bluez5.address"],
                properties["device.string"],
                properties["device.name"],
                node.name
            ]
            for (var candidateIndex = 0; candidateIndex < candidates.length;
                    candidateIndex++) {
                if (address !== "" && _normalizeAddress(candidates[candidateIndex])
                        .indexOf(address) !== -1) {
                    Pipewire.preferredDefaultAudioSink = node
                    audioRetry.stop()
                    _complete("connected")
                    return true
                }
            }
        }
        audioAttempts++
        if (audioAttempts >= 27) {
            audioRetry.stop()
            _fail("Connected, but no Bluetooth audio output appeared")
        }
        return false
    }

    function _normalizeAddress(value) {
        return String(value || "").toLowerCase().replace(/[^0-9a-f]/g, "")
    }

    function _complete(result) {
        operationTimeout.stop()
        audioRetry.stop()
        lastResult = result
        operation = "idle"
        operationTarget = ""
        pendingDevice = null
        localRevision++
        return "ok"
    }

    function _fail(message) {
        var identifier = operationTarget
        operationTimeout.stop()
        audioRetry.stop()
        lastError = String(message || "Bluetooth operation failed")
        lastResult = "failed"
        _setFailure(identifier, lastError)
        operation = "idle"
        operationTarget = ""
        pendingDevice = null
        localRevision++
        return "error"
    }

    function _setFailure(identifier, message) {
        var next = ({})
        for (var key in failures)
            next[key] = failures[key]
        if (message === "")
            delete next[identifier]
        else
            next[identifier] = message
        failures = next
    }

    function _modelAccepted(result) {
        if (typeof result === "object" && result !== null)
            return result.ok !== false && String(result.status || "ok") !== "error"
        return ["error", "failed", "unavailable"].indexOf(String(result || "ok")) === -1
    }

    function _modelError(result) {
        return typeof result === "object" && result !== null
            ? String(result.error || result.status || "operation failed")
            : String(result || "operation failed")
    }

    function _finishImmediate(result, label) {
        if (!_modelAccepted(result)) {
            lastError = _modelError(result)
            localRevision++
            return "error"
        }
        lastResult = label
        localRevision++
        return "ok"
    }
}
