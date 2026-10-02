import QtQuick
import Quickshell.Io
import Quickshell.Networking

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
    property bool networkingStale: false
    property int staleStrikes: 0
    property var scannerDevices: []

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
    // Networking is only touched when no model is injected, so fixtures and the
    // workbench never instantiate the D-Bus backend.
    readonly property bool networkingBackend: model === null && !forceUnavailable
        && Networking.backend === NetworkBackendType.NetworkManager
    readonly property bool networkingActive: networkingBackend && !networkingStale
    readonly property bool panelOpen: Boolean(context && context.panels
        && context.panels.selectedId === "stillsuit.network")
    readonly property var liveDevices: networkingActive && Networking.devices
        ? Networking.devices.values : []
    readonly property var effectiveSnapshot: networkingActive
        ? liveSnapshot(liveDevices, Networking.wifiEnabled, snapshot)
        : snapshot
    readonly property bool scannerRequested: panelOpen || operation === "scan"
    readonly property bool scannerWanted: networkingActive && scannerRequested
    readonly property string linkSignature: networkingActive
        ? _linkSignature(liveDevices, Networking.wifiEnabled) : ""
    readonly property bool available: !forceUnavailable
        && (model !== null || helperReady || networkingActive)
    readonly property bool wifiEnabled: model
        ? Boolean(model.wifiEnabled)
        : Boolean(effectiveSnapshot.wifiEnabled)
    readonly property bool wiredConnected: model
        ? Boolean(model.wiredConnected)
        : Boolean(effectiveSnapshot.wiredConnected)
    readonly property string wiredName: model
        ? String(model.wiredName || "")
        : String(effectiveSnapshot.wiredName || "")
    readonly property var networks: model
        ? model.networks || [] : effectiveSnapshot.networks || []
    readonly property var wiredConnections: model
        ? model.wiredConnections || [] : effectiveSnapshot.wiredConnections || []
    readonly property var vpns: model ? model.vpns || [] : effectiveSnapshot.vpns || []
    readonly property var tailscale: model ? model.tailscale || ({
        available: false,
        status: "unavailable",
        ip: "",
        hostName: "",
        dnsName: "",
        services: []
    }) : effectiveSnapshot.tailscale || ({
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

    onLinkSignatureChanged: if (networkingActive) linkDebounce.restart()
    // Quickshell lists unsaved networks only while a device's scanner is on, and
    // the scanner keeps requesting scans, so it runs only while it is needed.
    onScannerWantedChanged: applyScanner(_backendDevices(), scannerWanted)
    onLiveDevicesChanged: applyScanner(_backendDevices(), scannerWanted)
    Component.onDestruction: releaseScanners()

    // Helper-only mode polls as before. With the Networking backend the full
    // snapshot (IP addresses, VPNs, Tailscale) is only refreshed while the
    // panel is shown.
    property Timer refreshTimer: Timer {
        interval: 10000
        repeat: true
        running: root.helperReady && (!root.networkingActive || root.panelOpen)
        onTriggered: if (root.operation === "idle") root.refresh()
    }

    property Timer linkDebounce: Timer {
        interval: 2000
        onTriggered: if (root.networkingActive && root.operation === "idle") root.refresh()
    }

    // Quickshell 0.3.1 does not recover after a NetworkManager restart. A cheap
    // one-nmcli summary keeps the VPN chip fresh and, after two consecutive
    // disagreements with the live devices, drops back to helper polling.
    property Timer sanityTimer: Timer {
        interval: root.staleStrikes > 0 ? 5000 : 60000
        repeat: true
        running: root.helperReady && root.networkingActive
        onTriggered: if (root.operation === "idle")
            root.helper.write('{"operation":"summary"}\n')
    }

    function liveSnapshot(devices, liveWifiEnabled, helperSnapshot) {
        var base = helperSnapshot || {}
        var helperWired = base.wiredConnections || []
        var helperNetworks = base.networks || []
        var wired = []
        var wiredDevices = []
        var wifiConnectedCount = 0
        var wifiSsids = []
        var byName = {}
        for (var index = 0; index < (devices ? devices.length : 0); index++) {
            var device = devices[index]
            if (!device)
                continue
            if (device.type === DeviceType.Wired) {
                if (!device.connected)
                    continue
                var deviceName = String(device.name || "")
                wiredDevices.push(deviceName)
                var details = _findBy(helperWired, "device", deviceName)
                wired.push({
                    device: deviceName,
                    name: details ? String(details.name || deviceName) : deviceName,
                    addresses: details ? details.addresses || [] : [],
                    carrier: details ? String(details.carrier || "")
                        : device.hasLink ? "on" : "off"
                })
                continue
            }
            if (device.type !== DeviceType.Wifi)
                continue
            if (device.connected)
                wifiConnectedCount++
            var deviceSsid = ""
            if (!device.networks)
                continue
            var visible = device.networks.values || []
            for (var networkIndex = 0; networkIndex < visible.length; networkIndex++) {
                var candidate = _liveNetwork(visible[networkIndex], helperNetworks)
                if (!candidate)
                    continue
                if (candidate.connected && deviceSsid === "") {
                    deviceSsid = candidate.name
                    wifiSsids.push(deviceSsid)
                }
                if (!liveWifiEnabled)
                    continue
                var previous = byName[candidate.name]
                if (!previous || candidate.connected || candidate.signal > previous.signal)
                    byName[candidate.name] = candidate
            }
        }
        // The helper's last scan fills in SSIDs Quickshell hides while its
        // scanner is off; live rows always win.
        for (var helperIndex = 0; liveWifiEnabled && helperIndex < helperNetworks.length;
                helperIndex++) {
            var scanned = helperNetworks[helperIndex]
            var scannedName = scanned ? String(scanned.name || "") : ""
            if (scannedName === "" || byName[scannedName])
                continue
            var merged = Object.assign({}, scanned)
            merged.connected = false
            byName[scannedName] = merged
        }
        var liveNetworks = Object.keys(byName).map(function(name) { return byName[name] })
        liveNetworks.sort(function(left, right) {
            if (left.connected !== right.connected)
                return left.connected ? -1 : 1
            if (left.known !== right.known)
                return left.known ? -1 : 1
            if (left.signal !== right.signal)
                return right.signal - left.signal
            var leftName = left.name.toLowerCase()
            var rightName = right.name.toLowerCase()
            return leftName < rightName ? -1 : leftName > rightName ? 1 : 0
        })
        return {
            wifiEnabled: Boolean(liveWifiEnabled),
            wifiConnected: wifiConnectedCount > 0,
            wifiConnectedCount: wifiConnectedCount,
            wifiSsids: wifiSsids,
            wifiSsid: wifiSsids.length > 0 ? wifiSsids[0] : "",
            wiredDevices: wiredDevices,
            wiredConnected: wired.length > 0,
            wiredName: wired.length > 0 ? wired[0].name : "",
            wiredConnections: wired,
            networks: liveNetworks,
            vpns: base.vpns || [],
            tailscale: base.tailscale || ({
                available: false,
                status: "unavailable",
                ip: "",
                hostName: "",
                dnsName: "",
                services: []
            })
        }
    }

    function _liveNetwork(network, helperNetworks) {
        if (!network)
            return null
        var name = String(network.name || "")
        if (name === "")
            return null
        var known = Boolean(network.known)
        var saved = known ? _findBy(helperNetworks, "name", name) : null
        var uuid = saved ? String(saved.uuid || "") : ""
        var signal = Math.max(0, Math.min(100,
            Math.round(Number(network.signalStrength || 0) * 100)))
        return {
            id: uuid !== "" ? uuid : name,
            name: name,
            uuid: uuid,
            profileName: saved ? String(saved.profileName || "") : "",
            connected: Boolean(network.connected),
            known: known,
            kind: securityKind(network.security),
            security: WifiSecurityType.toString(network.security),
            signal: signal,
            signalStrength: signal / 100
        }
    }

    function securityKind(security) {
        switch (security) {
        case WifiSecurityType.Open:
        case WifiSecurityType.Owe:
            return "open"
        case WifiSecurityType.Wpa3SuiteB192:
        case WifiSecurityType.Wpa2Eap:
        case WifiSecurityType.WpaEap:
        case WifiSecurityType.Leap:
        case WifiSecurityType.DynamicWep:
            return "enterprise"
        default:
            return "personal"
        }
    }

    function _findBy(rows, key, value) {
        for (var index = 0; index < rows.length; index++) {
            if (rows[index] && String(rows[index][key] || "") === value)
                return rows[index]
        }
        return null
    }

    function _linkSignature(devices, liveWifiEnabled) {
        var parts = [liveWifiEnabled ? "wifi" : "no-wifi"]
        for (var index = 0; index < (devices ? devices.length : 0); index++) {
            if (devices[index])
                parts.push(String(devices[index].name) + ":" + devices[index].state)
        }
        return parts.join("|")
    }

    function _backendDevices() {
        return networkingBackend && Networking.devices ? Networking.devices.values : []
    }

    // Only devices this service switched on are tracked, so a scanner enabled
    // elsewhere is left alone and every one switched on here is switched off on
    // panel close, scan end, fallback or destruction.
    function applyScanner(devices, enabled) {
        if (!enabled) {
            releaseScanners()
            return
        }
        var tracked = scannerDevices.filter(function(device) { return Boolean(device) })
        for (var index = 0; index < (devices ? devices.length : 0); index++) {
            var device = devices[index]
            if (!device || device.type !== DeviceType.Wifi || device.scannerEnabled)
                continue
            device.scannerEnabled = true
            tracked.push(device)
        }
        scannerDevices = tracked
    }

    function releaseScanners() {
        var tracked = scannerDevices
        scannerDevices = []
        for (var index = 0; index < tracked.length; index++) {
            if (tracked[index] && tracked[index].scannerEnabled)
                tracked[index].scannerEnabled = false
        }
    }

    function _sortedNames(names) {
        return (names || []).map(String).sort().join("\n")
    }

    function summaryMatches(summary, live) {
        if (!summary || !live)
            return false
        if (Boolean(summary.wiredActive) !== Boolean(live.wiredConnected)
                || Boolean(summary.wifiActive) !== Boolean(live.wifiConnected))
            return false
        if (typeof summary.wifiEnabled === "boolean"
                && summary.wifiEnabled !== Boolean(live.wifiEnabled))
            return false
        if (Array.isArray(summary.wiredDevices)
                && _sortedNames(summary.wiredDevices) !== _sortedNames(live.wiredDevices))
            return false
        if (!Array.isArray(summary.wifiSsids))
            return true
        if (summary.wifiSsids.length !== Number(live.wifiConnectedCount || 0))
            return false
        // A hidden network has no live SSID, so every live SSID must be active in
        // NetworkManager, but an active one may be missing from the live list.
        var remaining = summary.wifiSsids.map(String)
        var liveSsids = live.wifiSsids || []
        for (var index = 0; index < liveSsids.length; index++) {
            var position = remaining.indexOf(String(liveSsids[index]))
            if (position === -1)
                return false
            remaining.splice(position, 1)
        }
        return true
    }

    function checkBackend(summary, live) {
        if (summaryMatches(summary, live)) {
            staleStrikes = 0
            return false
        }
        staleStrikes++
        if (staleStrikes < 2)
            return false
        staleStrikes = 0
        networkingStale = true
        releaseScanners()
        if (context && context.logger)
            context.logger.warn("Networking backend disagrees with NetworkManager; using helper polling")
        refresh()
        return true
    }

    function _applySummary(summary) {
        var next = Object.assign({}, snapshot)
        next.vpns = summary.vpns || []
        snapshot = next
        if (networkingActive)
            checkBackend(summary, effectiveSnapshot)
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
            if (successLabel === "handoff") _closeForManager()
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
        if (response.operation === "summary") {
            if (response.ok && response.summary)
                _applySummary(response.summary)
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
        if (response.ok && response.handoff) _closeForManager()
        operation = "idle"
        operationTarget = ""
        localRevision++
    }

    function _closeForManager() {
        if (context.actions && typeof context.actions.surfaceClose === "function")
            context.actions.surfaceClose("stillsuit.network")
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
            return _send({
                operation: "disconnect",
                uuid: String(network.uuid || ""),
                name: String(network.name || "")
            })
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
