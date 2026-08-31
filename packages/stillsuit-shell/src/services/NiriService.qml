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
    readonly property QtObject adapter: adapter

    CompositorAdapter { id: adapter }

    function parseEvent(raw) {
        var line = String(raw || "").trim()
        if (line === "") return false
        try {
            var event = JSON.parse(line)
            var nextOutputs = adapter.outputs
            var nextWorkspaces = adapter.workspaces
            var nextWindows = adapter.windows
            var nextFocused = adapter.focusedOutputId
            var changed = false
            if (event.OutputsChanged && Array.isArray(event.OutputsChanged.outputs)) {
                nextOutputs = event.OutputsChanged.outputs
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
            adapter.replace(nextOutputs, nextFocused, nextWorkspaces, nextWindows)
            return true
        } catch (error) {
            console.warn("stillsuit niri: ignored malformed event: " + error)
            return false
        }
    }

    function reconcile(outputsJson, workspacesJson, windowsJson) {
        try {
            var nextOutputs = JSON.parse(String(outputsJson || "[]"))
            var nextWorkspaces = JSON.parse(String(workspacesJson || "[]"))
            var nextWindows = JSON.parse(String(windowsJson || "[]"))
            if (!Array.isArray(nextOutputs) || !Array.isArray(nextWorkspaces) || !Array.isArray(nextWindows))
                throw new Error("niri reconciliation result is not arrays")
            adapter.replace(nextOutputs, _focusedOutputId(nextWorkspaces, adapter.focusedOutputId), nextWorkspaces, nextWindows)
            return true
        } catch (error) {
            console.warn("stillsuit niri: ignored malformed reconciliation: " + error)
            return false
        }
    }

    function refresh() {
        if (!enabled) return
        if (!outputsProcess.running) outputsProcess.running = true
        if (!workspacesProcess.running) workspacesProcess.running = true
        if (!windowsProcess.running) windowsProcess.running = true
    }

    function _tryReconcile() {
        if (!outputsResult.ready || !workspacesResult.ready || !windowsResult.ready) return
        reconcile(outputsResult.text, workspacesResult.text, windowsResult.text)
        outputsResult.ready = false
        workspacesResult.ready = false
        windowsResult.ready = false
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

    QtObject { id: outputsResult; property bool ready: false; property string text: "" }
    QtObject { id: workspacesResult; property bool ready: false; property string text: "" }
    QtObject { id: windowsResult; property bool ready: false; property string text: "" }

    Process {
        id: outputsProcess
        command: ["niri", "msg", "-j", "outputs"]
        stdout: StdioCollector { waitForEnd: true; onStreamFinished: function() { outputsResult.text = text; outputsResult.ready = true; root._tryReconcile() } }
    }
    Process {
        id: workspacesProcess
        command: ["niri", "msg", "-j", "workspaces"]
        stdout: StdioCollector { waitForEnd: true; onStreamFinished: function() { workspacesResult.text = text; workspacesResult.ready = true; root._tryReconcile() } }
    }
    Process {
        id: windowsProcess
        command: ["niri", "msg", "-j", "windows"]
        stdout: StdioCollector { waitForEnd: true; onStreamFinished: function() { windowsResult.text = text; windowsResult.ready = true; root._tryReconcile() } }
    }
    Timer { id: reconnectTimer; interval: root.reconnectDelayMs; repeat: false; onTriggered: if (root.enabled) eventStream.running = true }
    Timer { interval: root.reconciliationIntervalMs; running: root.enabled; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
}
