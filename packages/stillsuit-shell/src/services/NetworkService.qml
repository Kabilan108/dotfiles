import QtQuick
import Quickshell.Io

QtObject {
    id: root

    required property var context
    property var model: null
    property bool forceUnavailable: false
    property var snapshot: ({
        wifiEnabled: false,
        wiredConnected: false,
        wiredName: "",
        networks: [],
        vpns: [],
        tailscale: ({
            available: false,
            status: "unavailable",
            ip: "",
            hostName: "",
            dnsName: "",
            services: []
        })
    })
    property string operation: "idle"
    property string operationTarget: ""
    property string lastError: ""
    property string lastResult: ""
    property int localRevision: 0

    readonly property string apiVersion: "1"
    readonly property string helperPath: String(context && context.settings
        && context.settings.values ? context.settings.values.networkHelperPath || "" : "")
    readonly property var helperArgv: helperPath !== "" ? [helperPath] : []
    readonly property string lastCommandJson: JSON.stringify(helperArgv)
    readonly property string lastRequestSummary: operation === "idle"
        ? "idle"
        : operation + (operationTarget !== "" ? ":" + operationTarget : "")
    readonly property bool helperReady: model === null && helperPath.charAt(0) === "/"
        && helper.running
    readonly property bool available: !forceUnavailable && (model !== null || helperReady)
    readonly property bool wifiEnabled: model
        ? Boolean(model.wifiEnabled)
        : Boolean(snapshot.wifiEnabled)
    readonly property bool wiredConnected: model
        ? Boolean(model.wiredConnected)
        : Boolean(snapshot.wiredConnected)
    readonly property string wiredName: model
        ? String(model.wiredName || "")
        : String(snapshot.wiredName || "")
    readonly property var networks: model ? model.networks || [] : snapshot.networks || []
    readonly property var vpns: model ? model.vpns || [] : snapshot.vpns || []
    readonly property var tailscale: model ? model.tailscale || ({
        available: false,
        status: "unavailable",
        ip: "",
        hostName: "",
        dnsName: "",
        services: []
    }) : snapshot.tailscale || ({
        available: false,
        status: "unavailable",
        ip: "",
        hostName: "",
        dnsName: "",
        services: []
    })
    readonly property var connectedNetwork: _connected()
    readonly property bool scanning: operation === "scan"
    readonly property bool joining: operation === "join"
    readonly property bool wifiChanging: operation === "wifi-enabled"
    readonly property int revision: (model && model.revision !== undefined
        ? Number(model.revision)
        : 0) + localRevision

    property Process helper: Process {
        command: root.helperArgv
        stdinEnabled: true
        running: !root.forceUnavailable && root.model === null
            && root.helperPath.charAt(0) === "/"
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) { root._handleResponse(line) }
        }
        onStarted: root.refresh()
        onExited: function(exitCode) {
            if (root.model === null && !root.forceUnavailable) {
                root.operation = "idle"
                root.operationTarget = ""
                root.lastError = "Network helper exited with status " + exitCode
                root.localRevision++
            }
        }
    }

    property Timer refreshTimer: Timer {
        interval: 10000
        repeat: true
        running: root.helperReady
        onTriggered: if (root.operation === "idle") root.refresh()
    }

    function _connected() {
        for (var index = 0; index < networks.length; index++) {
            if (networks[index] && networks[index].connected)
                return networks[index]
        }
        return null
    }

    function _networkId(network) {
        if (!network)
            return ""
        return String(network.uuid || network.id || network.name || "")
    }

    function networkKind(network) {
        if (!network)
            return "unsupported"
        if (Boolean(network.hidden))
            return "hidden"
        if (String(network.kind || "") !== "")
            return String(network.kind)
        if (Boolean(network.enterprise))
            return "enterprise"
        if (Boolean(network.known))
            return "saved"
        if (Boolean(network.open) || String(network.security || "").toLowerCase() === "open")
            return "open"
        return "personal"
    }

    function signalPercentage(network) {
        if (!network)
            return 0
        if (network.signal !== undefined)
            return Math.max(0, Math.min(100, Math.round(Number(network.signal))))
        return Math.max(0, Math.min(100,
            Math.round(Number(network.signalStrength || 0) * 100)))
    }

    function statusFor(network) {
        if (!network)
            return "unavailable"
        if (operationTarget === _networkId(network)) {
            if (operation === "join")
                return "joining"
            if (operation === "disconnect")
                return "disconnecting"
        }
        if (network.connected)
            return "connected"
        if (network.known)
            return "saved"
        return networkKind(network)
    }

    function _begin(nextOperation, target) {
        if (forceUnavailable || operation !== "idle")
            return false
        operation = nextOperation
        operationTarget = String(target || "")
        lastError = ""
        lastResult = ""
        localRevision++
        return true
    }

    function _finishModel(result, successLabel) {
        var status = typeof result === "object" && result !== null
            ? String(result.status || (result.ok === false ? "error" : "ok"))
            : String(result || "ok")
        if (status === "error" || status === "failed" || status === "unavailable") {
            lastError = typeof result === "object" && result !== null
                ? String(result.error || status)
                : status
            lastResult = "failed"
        } else {
            lastResult = successLabel
        }
        operation = "idle"
        operationTarget = ""
        localRevision++
        return lastError === "" ? "ok" : "error"
    }

    function _send(request) {
        if (!helperReady) {
            operation = "idle"
            operationTarget = ""
            lastError = "Network helper is unavailable"
            localRevision++
            return "unavailable"
        }
        helper.write(JSON.stringify(request) + "\n")
        if (request.password !== undefined)
            request.password = ""
        return "started"
    }

    function _handleResponse(line) {
        var response
        try {
            response = JSON.parse(String(line || ""))
        } catch (error) {
            lastError = "Network helper returned invalid data"
            operation = "idle"
            operationTarget = ""
            localRevision++
            return
        }
        if (response.snapshot)
            snapshot = response.snapshot
        if (response.operation === "snapshot") {
            localRevision++
            return
        }
        lastError = response.ok ? "" : String(response.error || "Network operation failed")
        lastResult = response.ok
            ? response.handoff ? "handoff" : String(response.operation || "ok")
            : "failed"
        operation = "idle"
        operationTarget = ""
        localRevision++
    }

    function refresh() {
        if (forceUnavailable)
            return "unavailable"
        if (model && typeof model.refresh === "function")
            return model.refresh()
        if (model)
            return "ok"
        if (!helperReady)
            return "unavailable"
        helper.write('{"operation":"snapshot"}\n')
        return "started"
    }

    function scan() {
        if (!_begin("scan", "wifi"))
            return forceUnavailable ? "unavailable" : "busy"
        if (model && typeof model.scan === "function")
            return _finishModel(model.scan(), "scan")
        return _send({ operation: "scan" })
    }

    function setWifiEnabled(enabled) {
        if (!_begin("wifi-enabled", "wifi"))
            return forceUnavailable ? "unavailable" : "busy"
        var requested = Boolean(enabled)
        if (model && typeof model.setWifiEnabled === "function")
            return _finishModel(model.setWifiEnabled(requested), "wifi-enabled")
        return _send({ operation: "wifi-enabled", enabled: requested })
    }

    function activate(network, password) {
        if (!network)
            return "unavailable"
        var kind = networkKind(network)
        if (kind === "enterprise" || kind === "hidden")
            return openEditor(network)
        var action = network.connected ? "disconnect" : "join"
        if (!_begin(action, _networkId(network)))
            return forceUnavailable ? "unavailable" : "busy"
        if (model) {
            if (network.connected && typeof model.disconnect === "function")
                return _finishModel(model.disconnect(network), "disconnect")
            if (typeof model.join === "function")
                return _finishModel(model.join(network, String(password || "")), "join")
            if (typeof model.activate === "function")
                return _finishModel(model.activate(network, String(password || "")), action)
            return _finishModel("unavailable", action)
        }
        if (network.connected)
            return _send({ operation: "disconnect", uuid: _networkId(network) })
        var requestKind = network.known ? "saved" : kind
        var request = {
            operation: "join",
            kind: requestKind,
            name: String(network.name || ""),
            uuid: String(network.uuid || "")
        }
        if (requestKind === "personal")
            request.password = String(password || "")
        return _send(request)
    }

    function openEditor(network) {
        var mode = network && networkKind(network) === "enterprise"
            ? "enterprise"
            : "hidden"
        if (!_begin("open-editor", mode))
            return forceUnavailable ? "unavailable" : "busy"
        if (model && typeof model.openEditor === "function")
            return _finishModel(model.openEditor(mode, network || null), "handoff")
        return _send({
            operation: "open-editor",
            mode: mode,
            uuid: network ? String(network.uuid || "") : ""
        })
    }

    function openHiddenEditor() {
        return openEditor(null)
    }

    function openManager() {
        if (!_begin("open-editor", "manage"))
            return forceUnavailable ? "unavailable" : "busy"
        if (model && typeof model.openEditor === "function")
            return _finishModel(model.openEditor("manage", null), "handoff")
        return _send({ operation: "open-editor", mode: "manage", uuid: "" })
    }

    function copyTailscale(field, serviceName) {
        var requestedField = String(field || "")
        if (requestedField !== "dns" && requestedField !== "ip"
                && requestedField !== "service")
            return "invalid"
        var requestedService = String(serviceName || "")
        if (requestedField === "service" && requestedService === "")
            return "invalid"
        if (!_begin("copy-tailscale", requestedField))
            return forceUnavailable ? "unavailable" : "busy"
        if (model && typeof model.copyTailscale === "function")
            return _finishModel(model.copyTailscale(
                requestedField, requestedService), "copied")
        if (model)
            return _finishModel("ok", "copied")
        return _send({
            operation: "copy-tailscale",
            field: requestedField,
            serviceName: requestedService
        })
    }

    function toggleVpn(vpn) {
        if (!vpn || String(vpn.name || "") !== "MobergAnalytics"
                || vpn.toggleAllowed === false || vpn.readOnly === true)
            return "read-only"
        if (!_begin("vpn-toggle", String(vpn.uuid || vpn.name || "")))
            return forceUnavailable ? "unavailable" : "busy"
        if (model && typeof model.toggleVpn === "function")
            return _finishModel(model.toggleVpn(vpn), "vpn-toggle")
        return _send({ operation: "vpn-toggle", uuid: String(vpn.uuid || "") })
    }
}
