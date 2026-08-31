pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Niri's event format is intentionally normalized here before it crosses the
// host boundary. All commands are fixed literal argv arrays; plugins receive
// only adapter snapshots and cannot issue compositor commands.
Scope {
    id: root

    property bool enabled: true
    property int reconciliationIntervalMs: 2500
    property int reconnectDelayMs: 1000
    readonly property bool eventStreamRunning: eventStream.running
    readonly property int instanceCount: 1
    readonly property QtObject adapter: compositorAdapter
    readonly property int lastCompletedReconciliationGeneration: root._lastCompletedGeneration
    readonly property int lastAcceptedReconciliationGeneration: root._lastAcceptedGeneration
    readonly property bool reconciliationRunning: root._reconciliationRunning

    property int _reconciliationGeneration: 0
    property int _lastCompletedGeneration: 0
    property int _lastAcceptedGeneration: 0
    property bool _reconciliationRunning: false

    CompositorAdapter { id: compositorAdapter }

    function parseEvent(raw) {
        var line = String(raw || "").trim()
        if (line === "") return false
        try {
            var event = JSON.parse(line)
            var nextOutputs = compositorAdapter.outputs
            var nextWorkspaces = compositorAdapter.workspaces
            var nextWindows = compositorAdapter.windows
            var nextFocused = compositorAdapter.focusedOutputId
            var changed = false
            if (event.OutputsChanged && event.OutputsChanged.outputs !== undefined) {
                nextOutputs = _normalizeOutputs(event.OutputsChanged.outputs)
                if (nextOutputs === null) throw new Error("OutputsChanged.outputs is not an output map or array")
                changed = true
            } else if (event.WorkspacesChanged && Array.isArray(event.WorkspacesChanged.workspaces)) {
                nextWorkspaces = event.WorkspacesChanged.workspaces
                nextFocused = _focusedOutputId(nextWorkspaces, nextFocused)
                changed = true
            } else if (event.WorkspaceActivated) {
                nextWorkspaces = _workspaceActivated(nextWorkspaces, event.WorkspaceActivated)
                nextFocused = _focusedOutputId(nextWorkspaces, nextFocused)
                changed = true
            } else if (event.WorkspaceActiveWindowChanged) {
                nextWorkspaces = _workspaceActiveWindow(nextWorkspaces, event.WorkspaceActiveWindowChanged)
                changed = true
            } else if (event.WindowsChanged && Array.isArray(event.WindowsChanged.windows)) {
                nextWindows = event.WindowsChanged.windows
                changed = true
            } else if (event.WindowOpenedOrChanged && event.WindowOpenedOrChanged.window) {
                nextWindows = _upsertWindow(nextWindows, event.WindowOpenedOrChanged.window)
                changed = true
            } else if (event.WindowClosed) {
                nextWindows = _removeWindow(nextWindows, event.WindowClosed.id)
                changed = true
            } else if (event.WindowFocusChanged) {
                nextWindows = _focusedWindow(nextWindows, event.WindowFocusChanged.id)
                changed = true
            }
            if (!changed) return false
            compositorAdapter.replace(nextOutputs, nextFocused, nextWorkspaces, nextWindows)
            return true
        } catch (error) {
            console.warn("stillsuit niri: ignored malformed event: " + error)
            return false
        }
    }

    function reconcile(outputsJson, workspacesJson, windowsJson) {
        try {
            var nextOutputs = _parseOutputs(outputsJson)
            var nextWorkspaces = _parseSnapshotArray(workspacesJson, "workspaces")
            var nextWindows = _parseSnapshotArray(windowsJson, "windows")
            compositorAdapter.replace(nextOutputs, _focusedOutputId(nextWorkspaces, compositorAdapter.focusedOutputId), nextWorkspaces, nextWindows)
            return true
        } catch (error) {
            console.warn("stillsuit niri: ignored malformed reconciliation: " + error)
            return false
        }
    }

    function refresh() {
        if (!enabled || _reconciliationRunning) return
        _reconciliationGeneration += 1
        _reconciliationRunning = true
        _prepareResult(outputsResult, _reconciliationGeneration)
        _prepareResult(workspacesResult, _reconciliationGeneration)
        _prepareResult(windowsResult, _reconciliationGeneration)
        outputsProcess.requestGeneration = _reconciliationGeneration
        workspacesProcess.requestGeneration = _reconciliationGeneration
        windowsProcess.requestGeneration = _reconciliationGeneration
        outputsProcess.running = true
        workspacesProcess.running = true
        windowsProcess.running = true
    }

    function _prepareResult(result, generation) {
        result.generation = generation
        result.text = ""
        result.streamFinished = false
        result.exited = false
        result.exitCode = -1
        result.exitStatus = -1
    }

    function _collectorFinished(result, generation, text) {
        if (generation !== _reconciliationGeneration || result.generation !== generation) return
        result.text = String(text || "")
        result.streamFinished = true
        _tryFinishReconciliation(generation)
    }

    function _processExited(result, generation, exitCode, exitStatus) {
        if (generation !== _reconciliationGeneration || result.generation !== generation) return
        result.exitCode = Number(exitCode)
        result.exitStatus = Number(exitStatus)
        result.exited = true
        _tryFinishReconciliation(generation)
    }

    function _tryFinishReconciliation(generation) {
        if (!_reconciliationRunning || generation !== _reconciliationGeneration) return
        var results = [outputsResult, workspacesResult, windowsResult]
        for (var index = 0; index < results.length; index++) {
            var result = results[index]
            if (result.generation !== generation || !result.streamFinished || !result.exited) return
        }

        var successful = true
        for (var resultIndex = 0; resultIndex < results.length; resultIndex++) {
            if (results[resultIndex].exitCode !== 0 || results[resultIndex].exitStatus !== 0) successful = false
        }
        if (successful)
            successful = reconcile(outputsResult.text, workspacesResult.text, windowsResult.text)
        else
            console.warn("stillsuit niri: ignored failed reconciliation generation " + generation)

        _lastCompletedGeneration = generation
        if (successful) _lastAcceptedGeneration = generation
        _reconciliationRunning = false
    }

    function _parseOutputs(raw) {
        var text = String(raw || "").trim()
        if (text === "") throw new Error("niri outputs result is empty")
        var outputs = _normalizeOutputs(JSON.parse(text))
        if (outputs === null) throw new Error("niri outputs result is not an output map or array")
        return outputs
    }

    function _parseSnapshotArray(raw, label) {
        var text = String(raw || "").trim()
        if (text === "") throw new Error("niri " + label + " result is empty")
        var rows = JSON.parse(text)
        if (!Array.isArray(rows)) throw new Error("niri " + label + " result is not an array")
        for (var index = 0; index < rows.length; index++) {
            if (!rows[index] || typeof rows[index] !== "object" || Array.isArray(rows[index]))
                throw new Error("niri " + label + " result contains a non-object snapshot")
        }
        return _plain(rows)
    }

    function _normalizeOutputs(value) {
        var sourceRows = []
        if (Array.isArray(value)) {
            for (var arrayIndex = 0; arrayIndex < value.length; arrayIndex++) {
                var arrayOutput = _plain(value[arrayIndex])
                if (!arrayOutput || typeof arrayOutput !== "object" || Array.isArray(arrayOutput)) return null
                var arrayConnector = String(arrayOutput.name || arrayOutput.id || "")
                if (arrayConnector === "") return null
                if (String(arrayOutput.id || "") === "") arrayOutput.id = arrayConnector
                if (String(arrayOutput.name || "") === "") arrayOutput.name = arrayConnector
                sourceRows.push({ connector: arrayConnector, output: arrayOutput })
            }
        } else if (value && typeof value === "object") {
            var connectors = Object.keys(value)
            for (var mapIndex = 0; mapIndex < connectors.length; mapIndex++) {
                var connector = String(connectors[mapIndex])
                if (connector === "") return null
                var mapOutput = _plain(value[connector])
                if (!mapOutput || typeof mapOutput !== "object" || Array.isArray(mapOutput)) return null
                if (String(mapOutput.id || "") === "") mapOutput.id = connector
                if (String(mapOutput.name || "") === "") mapOutput.name = connector
                sourceRows.push({ connector: connector, output: mapOutput })
            }
        } else {
            return null
        }

        sourceRows.sort(function(left, right) {
            if (left.connector < right.connector) return -1
            if (left.connector > right.connector) return 1
            var leftName = String(left.output.name || "")
            var rightName = String(right.output.name || "")
            if (leftName < rightName) return -1
            if (leftName > rightName) return 1
            return 0
        })
        return sourceRows.map(function(row) { return row.output })
    }

    function _plain(value) {
        try { return JSON.parse(JSON.stringify(value)) } catch (error) { return null }
    }

    function _upsertWindow(rows, window) {
        if (!window || window.id === undefined) return rows
        var next = rows.slice()
        for (var index = 0; index < next.length; index++) {
            if (next[index] && next[index].id === window.id) { next[index] = window; return next }
        }
        next.push(window)
        return next
    }

    function _removeWindow(rows, windowId) {
        return rows.filter(function(window) { return window && window.id !== windowId })
    }

    function _focusedWindow(rows, windowId) {
        return rows.map(function(window) {
            if (!window) return window
            var next = _plain(window)
            if (!next) return window
            next.is_focused = next.id === windowId
            return next
        })
    }

    function _workspaceActivated(rows, event) {
        var activatedId = event.id
        var output = ""
        for (var index = 0; index < rows.length; index++) {
            if (rows[index] && rows[index].id === activatedId) { output = String(rows[index].output || ""); break }
        }
        return rows.map(function(workspace) {
            if (!workspace) return workspace
            var next = _plain(workspace)
            if (!next) return workspace
            if (String(next.output || "") === output) next.is_active = next.id === activatedId
            if (event.focused) next.is_focused = next.id === activatedId
            return next
        })
    }

    function _workspaceActiveWindow(rows, event) {
        return rows.map(function(workspace) {
            if (!workspace || workspace.id !== event.workspace_id) return workspace
            var next = _plain(workspace)
            if (next) next.active_window_id = event.active_window_id
            return next || workspace
        })
    }

    function _focusedOutputId(rows, fallback) {
        for (var index = 0; index < rows.length; index++) {
            if (rows[index] && rows[index].is_focused) return String(rows[index].output || "")
        }
        return String(fallback || "")
    }

    Process {
        id: eventStream
        command: ["niri", "msg", "--json", "event-stream"]
        running: root.enabled
        stdout: SplitParser { splitMarker: "\n"; onRead: function(line) { root.parseEvent(line) } }
        onExited: function() { if (root.enabled) reconnectTimer.restart() }
    }

    component ReconciliationResult: QtObject {
        property int generation: 0
        property string text: ""
        property bool streamFinished: false
        property bool exited: false
        property int exitCode: -1
        property int exitStatus: -1
    }

    ReconciliationResult { id: outputsResult }
    ReconciliationResult { id: workspacesResult }
    ReconciliationResult { id: windowsResult }

    Process {
        id: outputsProcess
        property int requestGeneration: 0
        command: ["niri", "msg", "-j", "outputs"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: function() { root._collectorFinished(outputsResult, outputsProcess.requestGeneration, text) }
        }
        onExited: function(exitCode, exitStatus) { root._processExited(outputsResult, outputsProcess.requestGeneration, exitCode, exitStatus) }
    }
    Process {
        id: workspacesProcess
        property int requestGeneration: 0
        command: ["niri", "msg", "-j", "workspaces"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: function() { root._collectorFinished(workspacesResult, workspacesProcess.requestGeneration, text) }
        }
        onExited: function(exitCode, exitStatus) { root._processExited(workspacesResult, workspacesProcess.requestGeneration, exitCode, exitStatus) }
    }
    Process {
        id: windowsProcess
        property int requestGeneration: 0
        command: ["niri", "msg", "-j", "windows"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: function() { root._collectorFinished(windowsResult, windowsProcess.requestGeneration, text) }
        }
        onExited: function(exitCode, exitStatus) { root._processExited(windowsResult, windowsProcess.requestGeneration, exitCode, exitStatus) }
    }
    Timer { id: reconnectTimer; interval: root.reconnectDelayMs; repeat: false; onTriggered: if (root.enabled) eventStream.running = true }
    Timer { interval: root.reconciliationIntervalMs; running: root.enabled; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
}
