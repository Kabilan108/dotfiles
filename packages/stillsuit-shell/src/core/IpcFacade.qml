import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property QtObject catalog: null
    property QtObject serviceRegistry: null
    property QtObject surfaceRouter: null
    property QtObject fallbackContext: null
    property var theme: ({})
    property string configId: "stillsuit"
    property string instanceId: ""
    property bool ready: false
    property string profileHelperPath: Quickshell.env("STILLSUIT_PLUGIN_HELPER")
    property string profileRuntimeConfigPath: Quickshell.env("STILLSUIT_PLUGIN_RUNTIME_CONFIG")
    property string requestedProfile: ""
    property string profileState: "ready"
    property string profileError: ""
    property int requestedProfileBaselineRevision: 0
    property int observedProfileRevision: 0
    property string agentPanelHelper: Quickshell.env("STILLSUIT_AGENT_PANEL_HELPER")
        || "stillsuit-agent-panel"
    property string agentPanelLastAction: ""
    property var agentPanelLastResult: null

    property Process agentPanelProcess: Process {
        stdout: StdioCollector {
            id: agentPanelStdout
        }
        stderr: StdioCollector {
            id: agentPanelStderr
        }

        onExited: function(exitCode, exitStatus) {
            var output = agentPanelStdout.text.trim()
            var diagnostic = agentPanelStderr.text.trim()
            if (exitCode === 0) {
                try {
                    root.agentPanelLastResult = JSON.parse(output)
                } catch (error) {
                    root.agentPanelLastResult = {
                        ok: false,
                        error: "helper returned invalid JSON"
                    }
                }
            } else {
                root.agentPanelLastResult = {
                    ok: false,
                    exitCode: exitCode,
                    error: diagnostic || "helper failed"
                }
            }
        }
    }

    property Process profileProcess: Process {
        stdout: StdioCollector {
            id: profileStdout
        }
        stderr: StdioCollector {
            id: profileStderr
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root._setProfileError(profileStderr.text.trim()
                    || profileStdout.text.trim()
                    || "profile helper failed")
                return
            }
            root._syncProfileState()
        }
    }

    property Timer profileTimeout: Timer {
        interval: 10000
        repeat: false
        onTriggered: {
            if (root.profileState !== "switching") return
            root._setProfileError("profile catalog update timed out")
        }
    }

    property Connections profileCatalogConnections: Connections {
        target: root.catalog
        ignoreUnknownSignals: true

        function onReconciliationFinished(changedIds, addedIds, removedIds) {
            Qt.callLater(root._syncProfileState)
        }

        function onActiveProfileChanged() {
            root._syncProfileState()
        }

        function onProfileRevisionChanged() {
            root._syncProfileState()
        }

        function onPluginContained(pluginId, kind, message) {
            root._queueSettledProfileRefresh()
        }
    }

    property Connections profileServiceConnections: Connections {
        target: root.serviceRegistry
        ignoreUnknownSignals: true

        function onRevisionChanged() {
            root._queueSettledProfileRefresh()
        }
    }

    property Connections profileSurfaceConnections: Connections {
        target: root.surfaceRouter
        ignoreUnknownSignals: true

        function onRevisionChanged() {
            root._queueSettledProfileRefresh()
        }
    }

    property IpcHandler shellHandler: IpcHandler {
        target: "stillsuit"

        function ping(): string {
            return root.shellPing()
        }

        function status(): string {
            return root.shellStatus()
        }

        function theme(): string {
            return root.themeQuery()
        }
    }

    property IpcHandler surfaceHandler: IpcHandler {
        target: "stillsuit-surface"

        function open(pluginId: string, payloadJson: string): string {
            return root.surfaceOpen(pluginId, payloadJson)
        }

        function close(pluginId: string): string {
            return root.surfaceClose(pluginId)
        }

        function toggle(pluginId: string, payloadJson: string): string {
            return root.surfaceToggle(pluginId, payloadJson)
        }
    }

    property IpcHandler pluginHandler: IpcHandler {
        target: "stillsuit-plugin"

        function unload(pluginId: string): string {
            return root.pluginUnload(pluginId)
        }

        function reload(pluginId: string): string {
            return root.pluginReload(pluginId)
        }

        function rescan(): string {
            return root.pluginRescan()
        }
    }

    property IpcHandler profileHandler: IpcHandler {
        target: "stillsuit-profile"

        function list(): string {
            return root.profileList()
        }

        function current(): string {
            return root.profileCurrent()
        }

        function activate(profileId: string): string {
            return root.profileActivate(profileId)
        }
    }

    property IpcHandler agentPanelHandler: IpcHandler {
        target: "stillsuit-agent-panel"

        function open(): string {
            return root.agentPanelOpen()
        }

        function hide(): string {
            return root.agentPanelHide()
        }

        function toggle(): string {
            return root.agentPanelToggle()
        }

        function status(): string {
            return root.agentPanelStatus()
        }

        function terminate(): string {
            return root.agentPanelTerminate()
        }
    }

    function shellPing() {
        return ready ? "ok" : "not-ready"
    }

    function shellStatus() {
        var pluginRecords = catalog ? catalog.statusRecords() : {}
        var surfaceRecords = surfaceRouter ? surfaceRouter.statusRecords() : {}
        for (var pluginId in pluginRecords) {
            if (pluginRecords[pluginId].state === "error")
                continue
            pluginRecords[pluginId].state = _pluginState(pluginId)
            if (serviceRegistry && serviceRegistry.state(pluginId) !== "unloaded")
                pluginRecords[pluginId].service = {
                    state: serviceRegistry.state(pluginId),
                    error: serviceRegistry.error(pluginId)
                }
            if (surfaceRecords[pluginId] !== undefined)
                pluginRecords[pluginId].surface = surfaceRecords[pluginId]
        }

        return JSON.stringify({
            configId: configId,
            instanceId: instanceId,
            ready: ready,
            catalogRevision: catalog ? catalog.revision : 0,
            catalogError: catalog ? catalog.loadError : "catalog unavailable",
            profile: {
                active: catalog ? catalog.activeProfile : "default",
                requested: requestedProfile,
                revision: catalog ? catalog.profileRevision : 0,
                available: catalog ? catalog.availableProfiles : [],
                state: profileState,
                error: profileError
            },
            bar: catalog ? {
                selectedId: catalog.selectedBarId,
                activeId: catalog.activeBarId,
                fallback: catalog.fallbackActive,
                state: catalog.barState,
                error: catalog.barError
            } : {},
            serviceObjectCount: serviceRegistry ? serviceRegistry.objectCount : 0,
            surfaceObjectCount: surfaceRouter ? surfaceRouter.objectCount : 0,
            screenCount: surfaceRouter ? surfaceRouter.screenCount : 0,
            fallbackShadowMode: fallbackContext
                ? fallbackContext.settings.values.shadowMode === true
                : false,
            agentPanel: {
                running: agentPanelProcess.running,
                lastAction: agentPanelLastAction,
                lastResult: agentPanelLastResult
            },
            plugins: pluginRecords
        })
    }

    function themeQuery() {
        return JSON.stringify(theme || {})
    }

    function surfaceOpen(pluginId, payloadJson) {
        return surfaceRouter
            ? surfaceRouter.open(String(pluginId), String(payloadJson || ""))
            : "error"
    }

    function surfaceClose(pluginId) {
        return surfaceRouter ? surfaceRouter.close(String(pluginId)) : "error"
    }

    function surfaceDismissPanels() {
        if (!surfaceRouter) return "error"
        surfaceRouter.dismissPanels()
        return "ok"
    }

    function surfaceToggle(pluginId, payloadJson) {
        return surfaceRouter
            ? surfaceRouter.toggle(String(pluginId), String(payloadJson || ""))
            : "error"
    }

    function pluginUnload(pluginId) {
        return catalog ? catalog.unload(String(pluginId)) : "error"
    }

    function pluginReload(pluginId) {
        return catalog ? catalog.reload(String(pluginId)) : "error"
    }

    function pluginRescan() {
        if (!catalog)
            return "error"
        return catalog.rescan() || "ok"
    }

    function profileList() {
        return JSON.stringify(catalog ? catalog.availableProfiles : [])
    }

    function profileCurrent() {
        return JSON.stringify({
            active: catalog ? catalog.activeProfile : "default",
            requested: requestedProfile,
            revision: catalog ? catalog.profileRevision : 0,
            state: profileState,
            error: profileError
        })
    }

    function profileActivate(profileId) {
        var key = String(profileId || "")
        if (key === "" || !catalog)
            return "error"
        var available = catalog.availableProfiles || []
        var known = false
        for (var index = 0; index < available.length; index++) {
            if (available[index].id === key) {
                known = true
                break
            }
        }
        if (!known)
            return "unknown"
        if (profileProcess.running || profileState === "switching")
            return "busy"
        if (catalog.activeProfile === key) {
            requestedProfile = ""
            _setSettledProfileState()
            return "ok"
        }
        if (profileHelperPath === "" || profileRuntimeConfigPath === "") {
            profileState = "error"
            profileError = "profile helper is unavailable"
            return "error"
        }

        requestedProfile = key
        requestedProfileBaselineRevision = catalog.profileRevision
        profileState = "switching"
        profileError = ""
        profileProcess.command = [
            profileHelperPath,
            "--config", profileRuntimeConfigPath,
            "profile", "activate", key
        ]
        profileTimeout.restart()
        profileProcess.running = true
        return "started"
    }

    function _syncProfileState() {
        if (!catalog || catalog.reconciling)
            return
        if (requestedProfile === "") {
            if (!ready || (profileState === "error"
                    && catalog.profileRevision === observedProfileRevision))
                return
            observedProfileRevision = catalog.profileRevision
            _setSettledProfileState()
            return
        }
        if (catalog.activeProfile !== requestedProfile
                || catalog.profileRevision <= requestedProfileBaselineRevision
                || !ready)
            return
        observedProfileRevision = catalog.profileRevision
        requestedProfile = ""
        _setSettledProfileState()
        profileTimeout.stop()
    }

    function _setSettledProfileState() {
        var failure = _profileFailureSummary()
        profileState = failure === "" ? "ready" : "degraded"
        profileError = failure
    }

    function _setProfileError(message) {
        profileTimeout.stop()
        requestedProfile = ""
        profileState = "error"
        profileError = String(message)
    }

    function _queueSettledProfileRefresh() {
        Qt.callLater(function() {
            if (!root.ready || root.requestedProfile !== ""
                    || root.profileState === "switching"
                    || root.profileState === "error")
                return
            root._setSettledProfileState()
        })
    }

    function _profileFailureSummary() {
        if (!catalog)
            return "catalog unavailable"
        if (catalog.loadError !== "")
            return catalog.loadError
        var failures = catalog.failures || {}
        var failureIds = Object.keys(failures).sort()
        if (failureIds.length > 0) {
            var firstFailure = failures[failureIds[0]] || []
            return failureIds[0] + ": " + String(firstFailure[0] || "catalog error")
        }
        var runtimeErrors = catalog.runtimeErrors || {}
        var runtimeIds = Object.keys(runtimeErrors).sort()
        if (runtimeIds.length > 0)
            return runtimeIds[0] + ": " + String(runtimeErrors[runtimeIds[0]])
        var serviceRecords = serviceRegistry ? serviceRegistry.statusRecords() : {}
        var serviceIds = Object.keys(serviceRecords).sort()
        for (var serviceIndex = 0; serviceIndex < serviceIds.length; serviceIndex++) {
            var serviceId = serviceIds[serviceIndex]
            if (serviceRecords[serviceId].state === "error")
                return serviceId + ": " + serviceRecords[serviceId].error
        }
        var surfaceRecords = surfaceRouter ? surfaceRouter.statusRecords() : {}
        var surfaceIds = Object.keys(surfaceRecords).sort()
        for (var surfaceIndex = 0; surfaceIndex < surfaceIds.length; surfaceIndex++) {
            var surfaceId = surfaceIds[surfaceIndex]
            if (surfaceRecords[surfaceId].state === "error")
                return surfaceId + ": " + surfaceRecords[surfaceId].error
        }
        return ""
    }

    onReadyChanged: {
        _syncProfileState()
        _queueSettledProfileRefresh()
    }

    function agentPanelOpen() {
        return _agentPanelAction("open")
    }

    function agentPanelHide() {
        return _agentPanelAction("hide")
    }

    function agentPanelToggle() {
        return _agentPanelAction("toggle")
    }

    function agentPanelStatus() {
        return _agentPanelAction("status")
    }

    function agentPanelTerminate() {
        return _agentPanelAction("terminate")
    }

    function _agentPanelAction(action) {
        var allowedActions = ["open", "hide", "toggle", "status", "terminate"]
        if (allowedActions.indexOf(action) === -1)
            return _agentPanelEnvelope("error")
        if (agentPanelProcess.running)
            return _agentPanelEnvelope("busy")

        agentPanelLastAction = action
        agentPanelProcess.command = [agentPanelHelper, action]
        agentPanelProcess.running = true
        return _agentPanelEnvelope("started")
    }

    function _agentPanelEnvelope(dispatch) {
        return JSON.stringify({
            dispatch: dispatch,
            running: agentPanelProcess.running,
            lastAction: agentPanelLastAction,
            lastResult: agentPanelLastResult
        })
    }

    function _pluginState(pluginId) {
        if (!catalog || !catalog.has(pluginId) || !catalog.isEnabled(pluginId))
            return "unloaded"

        var states = []
        var entry = catalog.get(pluginId)
        for (var index = 0; index < entry.manifest.kinds.length; index++) {
            var kind = entry.manifest.kinds[index]
            if (kind === "bar" || kind === "bar-widget")
                states.push(catalog.contributionState(pluginId, kind))
        }
        if (entry.manifest.kinds.indexOf("service") !== -1 && serviceRegistry)
            states.push(serviceRegistry.state(pluginId))
        if (catalog.primarySurfaceKind(pluginId) !== "" && surfaceRouter)
            states.push(surfaceRouter.state(pluginId))

        if (states.indexOf("error") !== -1)
            return "error"
        if (states.indexOf("loading") !== -1)
            return "loading"
        if (states.indexOf("loaded") !== -1)
            return "loaded"
        return "unloaded"
    }
}
