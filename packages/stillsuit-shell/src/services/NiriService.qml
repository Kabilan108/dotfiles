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
    // Niri's event stream is authoritative and resends full workspace and
    // window snapshots on connect. Reconciliation fills in outputs (which the
    // stream does not carry) on stream start, on screen changes, and after an
    // event the parser cannot apply; this interval is only a safety net.
    property int reconciliationIntervalMs: 60000
    property int reconciliationTimeoutMs: 5000
    property int reconnectDelayMs: 1000
    property int reconnectMaxDelayMs: 30000
    readonly property bool eventStreamRunning: eventStream.running
    readonly property int instanceCount: 1
    readonly property QtObject adapter: compositorAdapter
    readonly property int lastCompletedReconciliationGeneration: root._lastCompletedGeneration
    readonly property int lastAcceptedReconciliationGeneration: root._lastAcceptedGeneration
    readonly property int lastTimedOutReconciliationGeneration: root._lastTimedOutGeneration
    readonly property bool reconciliationRunning: root._reconciliationRunning
    readonly property int reconnectAttempts: root._reconnectAttempts
    readonly property int scheduledReconnectDelayMs: reconnectTimer.interval

    property int _reconciliationGeneration: 0
    property int _lastCompletedGeneration: 0
    property int _lastAcceptedGeneration: 0
    property int _lastTimedOutGeneration: 0
    property bool _reconciliationRunning: false
    property bool _reconciliationPending: false
    property int _reconnectAttempts: 0
    // Collections the event stream changed while the current reconciliation
    // was in flight. Its snapshot of those collections may predate the event.
    property var _streamTouched: ({})
    property string _screenSignature: ""

    readonly property var _ignoredEvents: [
        "KeyboardLayoutsChanged", "KeyboardLayoutSwitched", "OverviewOpenedOrClosed",
        "ConfigLoaded", "ScreenshotCaptured", "CastsChanged", "CastStartedOrChanged", "CastStopped"
    ]

    CompositorAdapter { id: compositorAdapter }

    function parseEvent(raw) {
        var line = String(raw || "").trim()
        if (line === "") return false
        try {
            var event = JSON.parse(line)
            if (!event || typeof event !== "object" || Array.isArray(event))
                throw new Error("event is not an object")
            var kind = Object.keys(event)[0]
            _reconnectAttempts = 0
            if (_ignoredEvents.indexOf(kind) >= 0) return false
            var changes = _eventChanges(kind, event[kind])
            if (changes === null) {
                console.warn("stillsuit niri: reconciling after unhandled event " + kind)
                refresh()
                return false
            }
            if (_reconciliationRunning) {
                for (var key in changes) _streamTouched[key] = true
            }
            return compositorAdapter.update(changes)
        } catch (error) {
            console.warn("stillsuit niri: reconciling after malformed event: " + error)
            refresh()
            return false
        }
    }

    // Returns the adapter collections an event changes, or null when the
    // event is unknown or its payload cannot be applied. Collections that the
    // event leaves untouched are passed back as the same array, so the adapter
    // skips them.
    function _eventChanges(kind, payload) {
        if (!payload || typeof payload !== "object") return null
        var workspaces = compositorAdapter.workspaces
        var windows = compositorAdapter.windows
        var focusedOutputId = compositorAdapter.focusedOutputId
        switch (kind) {
        case "OutputsChanged":
            var outputs = payload.outputs === undefined ? null : _normalizeOutputs(payload.outputs)
            return outputs === null ? null : { outputs: outputs }
        case "WorkspacesChanged":
            if (!Array.isArray(payload.workspaces)) return null
            return { workspaces: payload.workspaces, focusedOutputId: _focusedOutputId(payload.workspaces, focusedOutputId) }
        case "WorkspaceActivated":
            var activated = _workspaceActivated(workspaces, payload)
            return { workspaces: activated, focusedOutputId: _focusedOutputId(activated, focusedOutputId) }
        case "WorkspaceActiveWindowChanged":
            return { workspaces: _workspaceActiveWindow(workspaces, payload) }
        case "WorkspaceUrgencyChanged":
            return { workspaces: _patchRows(workspaces, function(workspace) {
                return workspace.id === payload.id ? { is_urgent: payload.urgent === true } : null
            }) }
        case "WindowsChanged":
            return Array.isArray(payload.windows) ? { windows: payload.windows } : null
        case "WindowOpenedOrChanged":
            return payload.window && payload.window.id !== undefined
                ? { windows: _upsertWindow(windows, payload.window) } : null
        case "WindowClosed":
            return { windows: _removeWindow(windows, payload.id) }
        case "WindowFocusChanged":
            return { windows: _focusedWindow(windows, payload.id) }
        case "WindowFocusTimestampChanged":
            return { windows: _patchRows(windows, function(window) {
                return window.id === payload.id ? { focus_timestamp: payload.focus_timestamp } : null
            }) }
        case "WindowUrgencyChanged":
            return { windows: _patchRows(windows, function(window) {
                return window.id === payload.id ? { is_urgent: payload.urgent === true } : null
            }) }
        case "WindowLayoutsChanged":
            return Array.isArray(payload.changes) ? { windows: _windowLayouts(windows, payload.changes) } : null
        }
        return null
    }

    function reconcile(outputsJson, workspacesJson, windowsJson) {
        return _applyReconciliation(outputsJson, workspacesJson, windowsJson, {})
    }

    function _applyReconciliation(outputsJson, workspacesJson, windowsJson, streamTouched) {
        try {
            var nextOutputs = _parseOutputs(outputsJson)
            var nextWorkspaces = _parseSnapshotArray(workspacesJson, "workspaces")
            var nextWindows = _parseSnapshotArray(windowsJson, "windows")
            var changes = {}
            if (!streamTouched.outputs) changes.outputs = nextOutputs
            if (!streamTouched.workspaces) {
                changes.workspaces = nextWorkspaces
                changes.focusedOutputId = _focusedOutputId(nextWorkspaces, compositorAdapter.focusedOutputId)
            }
            if (!streamTouched.windows) changes.windows = nextWindows
            compositorAdapter.update(changes)
            return true
        } catch (error) {
            console.warn("stillsuit niri: ignored malformed reconciliation: " + error)
            return false
        }
    }

    // A request that arrives while a generation is in flight runs once that
    // generation and its processes have finished.
    function refresh() {
        if (!enabled) return
        if (_reconciliationRunning || outputsProcess.running
                || workspacesProcess.running || windowsProcess.running) {
            _reconciliationPending = true
            return
        }
        _reconciliationPending = false
        _reconciliationGeneration += 1
        _reconciliationRunning = true
        _streamTouched = {}
        _prepareResult(outputsResult, _reconciliationGeneration)
        _prepareResult(workspacesResult, _reconciliationGeneration)
        _prepareResult(windowsResult, _reconciliationGeneration)
        outputsProcess.requestGeneration = _reconciliationGeneration
        workspacesProcess.requestGeneration = _reconciliationGeneration
        windowsProcess.requestGeneration = _reconciliationGeneration
        outputsProcess.running = true
        workspacesProcess.running = true
        windowsProcess.running = true
        reconciliationTimeout.restart()
    }

    function _runPendingReconciliation() {
        if (_reconciliationPending) refresh()
    }

    function _screenNames() {
        var names = []
        for (var index = 0; index < Quickshell.screens.length; index++)
            names.push(String(Quickshell.screens[index].name))
        return names.join("\n")
    }

    function _screensChanged() {
        var signature = _screenNames()
        if (signature === _screenSignature) return
        _screenSignature = signature
        refresh()
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
            successful = _applyReconciliation(outputsResult.text, workspacesResult.text, windowsResult.text, _streamTouched)
        else
            console.warn("stillsuit niri: ignored failed reconciliation generation " + generation)

        _lastCompletedGeneration = generation
        if (successful) _lastAcceptedGeneration = generation
        _reconciliationRunning = false
        reconciliationTimeout.stop()
        Qt.callLater(root._runPendingReconciliation)
    }

    function _reconciliationTimedOut(generation) {
        if (!_reconciliationRunning || generation !== _reconciliationGeneration) return
        console.warn("stillsuit niri: reconciliation generation " + generation + " timed out")
        _lastCompletedGeneration = generation
        _lastTimedOutGeneration = generation
        _reconciliationRunning = false
        outputsProcess.running = false
        workspacesProcess.running = false
        windowsProcess.running = false
        Qt.callLater(root._runPendingReconciliation)
    }

    function _reconnectDelay(attempt) {
        var base = Math.max(1, reconnectDelayMs)
        var maximum = Math.max(base, reconnectMaxDelayMs)
        return Math.min(maximum, base * Math.pow(2, Math.min(30, Math.max(0, attempt))))
    }

    function _scheduleReconnect() {
        if (!enabled || reconnectTimer.running) return
        eventStream.running = false
        reconnectTimer.interval = _reconnectDelay(_reconnectAttempts)
        _reconnectAttempts += 1
        reconnectTimer.restart()
    }

    function _setEnabled(nextEnabled) {
        reconnectTimer.stop()
        if (nextEnabled) {
            _reconnectAttempts = 0
            if (!eventStream.running) eventStream.running = true
        } else {
            eventStream.running = false
        }
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
        return rows
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

    // Copies only the rows whose fields actually change, so unchanged rows keep
    // their identity. `patchFor` returns the fields to set on a row, or null.
    function _patchRows(rows, patchFor) {
        var next = null
        for (var index = 0; index < rows.length; index++) {
            var row = rows[index]
            if (!row || typeof row !== "object") continue
            var patch = patchFor(row)
            if (!patch || !_patchChanges(row, patch)) continue
            if (next === null) next = rows.slice()
            next[index] = Object.assign({}, row, patch)
        }
        return next === null ? rows : next
    }

    function _patchChanges(row, patch) {
        for (var key in patch) {
            var value = patch[key]
            if (value !== null && typeof value === "object") {
                if (JSON.stringify(value) !== JSON.stringify(row[key])) return true
            } else if (row[key] !== value) {
                return true
            }
        }
        return false
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
        var next = rows.filter(function(window) { return window && window.id !== windowId })
        return next.length === rows.length ? rows : next
    }

    function _focusedWindow(rows, windowId) {
        return _patchRows(rows, function(window) { return { is_focused: window.id === windowId } })
    }

    function _windowLayouts(rows, changes) {
        var layouts = {}
        for (var index = 0; index < changes.length; index++) {
            var change = changes[index]
            if (Array.isArray(change) && change.length === 2) layouts[String(change[0])] = change[1]
        }
        return _patchRows(rows, function(window) {
            var key = String(window.id)
            return layouts.hasOwnProperty(key) ? { layout: layouts[key] } : null
        })
    }

    function _workspaceActivated(rows, event) {
        var activatedId = event.id
        var output = ""
        for (var index = 0; index < rows.length; index++) {
            if (rows[index] && rows[index].id === activatedId) { output = String(rows[index].output || ""); break }
        }
        return _patchRows(rows, function(workspace) {
            var patch = {}
            if (String(workspace.output || "") === output) patch.is_active = workspace.id === activatedId
            if (event.focused) patch.is_focused = workspace.id === activatedId
            return patch
        })
    }

    function _workspaceActiveWindow(rows, event) {
        return _patchRows(rows, function(workspace) {
            return workspace.id === event.workspace_id ? { active_window_id: event.active_window_id } : null
        })
    }

    function _focusedOutputId(rows, fallback) {
        for (var index = 0; index < rows.length; index++) {
            if (rows[index] && rows[index].is_focused) return String(rows[index].output || "")
        }
        return String(fallback || "")
    }

    // The one compositor mutation the host offers. The argv is fixed apart
    // from the window id, which is validated as an integer before it is used.
    // A request that arrives while one is in flight replaces any earlier
    // pending one and runs when the process exits: the last click wins.
    property int _pendingFocusId: 0

    function focusWindow(windowId) {
        var id = Number(windowId)
        if (!Number.isInteger(id) || id <= 0) return "invalid-window"
        if (focusProcess.running) {
            _pendingFocusId = id
            return "ok"
        }
        _runFocus(id)
        return "ok"
    }

    function _runFocus(id) {
        focusProcess.command = ["niri", "msg", "action", "focus-window", "--id", String(id)]
        focusProcess.running = true
    }

    Process {
        id: focusProcess
        command: ["niri", "msg", "action", "focus-window", "--id", "0"]
        onExited: {
            var next = root._pendingFocusId
            root._pendingFocusId = 0
            if (next > 0) root._runFocus(next)
        }
    }

    Process {
        id: eventStream
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser { splitMarker: "\n"; onRead: function(line) { root.parseEvent(line) } }
        onStarted: root.refresh()
        onRunningChanged: if (!running) root._scheduleReconnect()
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
        onRunningChanged: if (!running) Qt.callLater(root._runPendingReconciliation)
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
        onRunningChanged: if (!running) Qt.callLater(root._runPendingReconciliation)
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
        onRunningChanged: if (!running) Qt.callLater(root._runPendingReconciliation)
    }
    Timer { id: reconnectTimer; repeat: false; onTriggered: if (root.enabled) eventStream.running = true }
    Timer {
        id: reconciliationTimeout
        interval: Math.max(1, root.reconciliationTimeoutMs)
        repeat: false
        onTriggered: root._reconciliationTimedOut(root._reconciliationGeneration)
    }
    Timer { interval: Math.max(1, root.reconciliationIntervalMs); running: root.enabled; repeat: true; onTriggered: root.refresh() }
    Connections {
        target: Quickshell
        function onScreensChanged() { root._screensChanged() }
    }

    onEnabledChanged: root._setEnabled(enabled)
    Component.onCompleted: {
        root._screenSignature = root._screenNames()
        root._setEnabled(enabled)
    }
}
