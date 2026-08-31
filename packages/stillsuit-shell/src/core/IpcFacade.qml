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
        catalog.rescan()
        return "ok"
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
