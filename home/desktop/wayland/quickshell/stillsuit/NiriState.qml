import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property var workspaces: []
    property var windows: []
    property var casts: []
    property bool gpuScreenRecorderActive: false
    property bool eventStreamRunning: false
    readonly property bool screenCaptureActive: casts.length > 0 || gpuScreenRecorderActive

    function parseEvent(raw) {
        const line = String(raw || "").trim()
        if (line.length === 0) return

        try {
            const event = JSON.parse(line)
            if (event.WorkspacesChanged) {
                workspaces = event.WorkspacesChanged.workspaces || []
            } else if (event.WorkspaceActivated) {
                setWorkspaceActivated(event.WorkspaceActivated.id, event.WorkspaceActivated.focused)
            } else if (event.WorkspaceActiveWindowChanged) {
                setWorkspaceActiveWindow(event.WorkspaceActiveWindowChanged.workspace_id, event.WorkspaceActiveWindowChanged.active_window_id)
            } else if (event.WindowsChanged) {
                windows = event.WindowsChanged.windows || []
            } else if (event.WindowOpenedOrChanged) {
                upsertWindow(event.WindowOpenedOrChanged.window)
            } else if (event.WindowClosed) {
                removeWindow(event.WindowClosed.id)
            } else if (event.WindowFocusChanged) {
                markFocusedWindow(event.WindowFocusChanged.id)
            } else if (event.CastsChanged) {
                casts = event.CastsChanged.casts || []
            }
        } catch (error) {
            console.warn("stillsuit niri: failed to parse event:", error, line)
        }
    }

    function loadWorkspaces(raw) {
        try {
            workspaces = JSON.parse(String(raw || "[]"))
        } catch (error) {
            console.warn("stillsuit niri: failed to parse workspaces:", error)
        }
    }

    function loadWindows(raw) {
        try {
            windows = JSON.parse(String(raw || "[]"))
        } catch (error) {
            console.warn("stillsuit niri: failed to parse windows:", error)
        }
    }

    function upsertWindow(window) {
        if (!window || window.id === undefined) return

        const next = windows.slice()
        for (let i = 0; i < next.length; i++) {
            if (next[i] && next[i].id === window.id) {
                next[i] = window
                windows = next
                return
            }
        }

        next.push(window)
        windows = next
    }

    function removeWindow(id) {
        windows = windows.filter(window => window && window.id !== id)
    }

    function markFocusedWindow(id) {
        const next = []
        for (let i = 0; i < windows.length; i++) {
            const window = windows[i]
            if (!window) continue
            const copy = JSON.parse(JSON.stringify(window))
            copy.is_focused = copy.id === id
            next.push(copy)
        }
        windows = next
    }

    function setWorkspaceActivated(id, focused) {
        let output = ""
        for (let i = 0; i < workspaces.length; i++) {
            if (workspaces[i] && workspaces[i].id === id) {
                output = String(workspaces[i].output || "")
                break
            }
        }

        workspaces = workspaces.map(function(ws) {
            if (!ws) return ws
            const copy = Object.assign({}, ws)
            if (String(copy.output || "") === output) copy.is_active = copy.id === id
            if (focused) copy.is_focused = copy.id === id
            return copy
        })
    }

    function setWorkspaceActiveWindow(workspaceId, activeWindowId) {
        const next = workspaces.slice()
        for (let i = 0; i < next.length; i++) {
            if (next[i] && next[i].id === workspaceId) {
                if (next[i].active_window_id === activeWindowId) return
                next[i] = Object.assign({}, next[i], { active_window_id: activeWindowId })
                workspaces = next
                return
            }
        }
    }

    function refresh() {
        if (!workspacesProc.running) workspacesProc.running = true
        if (!windowsProc.running) windowsProc.running = true
        if (!screenCaptureProc.running) screenCaptureProc.running = true
    }

    function outputName(screen) {
        return screen && screen.name ? String(screen.name) : ""
    }

    function workspacesForOutput(output) {
        const name = String(output || "")
        const rows = []
        for (let i = 0; i < workspaces.length; i++) {
            const workspace = workspaces[i]
            if (workspace && String(workspace.output || "") === name) rows.push(workspace)
        }
        rows.sort((a, b) => {
            const left = Number(a.idx || 0)
            const right = Number(b.idx || 0)
            if (left !== right) return left - right
            return Number(a.id || 0) - Number(b.id || 0)
        })
        return rows
    }

    function activeWorkspaceForOutput(output) {
        const rows = workspacesForOutput(output)
        for (let i = 0; i < rows.length; i++) {
            if (rows[i] && rows[i].is_active) return rows[i]
        }
        return rows.length > 0 ? rows[0] : null
    }

    function focusedOutput() {
        for (let i = 0; i < workspaces.length; i++) {
            const workspace = workspaces[i]
            if (workspace && workspace.is_focused) return String(workspace.output || "")
        }
        return ""
    }

    function isFocusedOutput(output) {
        return String(output || "") === focusedOutput()
    }

    function windowsForWorkspace(workspaceId) {
        const rows = []
        for (let i = 0; i < windows.length; i++) {
            const window = windows[i]
            if (window && window.workspace_id === workspaceId && !window.is_floating) rows.push(window)
        }
        rows.sort((a, b) => {
            const left = columnIndexForWindow(a)
            const right = columnIndexForWindow(b)
            if (left !== right) return left - right
            return Number(a.id || 0) - Number(b.id || 0)
        })
        return rows
    }

    function columnIndexForWindow(window) {
        const pos = window && window.layout ? window.layout.pos_in_scrolling_layout : null
        if (!Array.isArray(pos) || pos.length === 0) return 1
        return Math.max(1, Number(pos[0] || 1))
    }

    function focusedColumnForWorkspace(workspace) {
        if (!workspace) return 1

        const rows = windowsForWorkspace(workspace.id)

        for (let i = 0; i < rows.length; i++) {
            if (rows[i] && rows[i].is_focused) return columnIndexForWindow(rows[i])
        }

        const activeWindowId = workspace.active_window_id
        for (let i = 0; i < rows.length; i++) {
            if (rows[i] && rows[i].id === activeWindowId) return columnIndexForWindow(rows[i])
        }

        return rows.length > 0 ? columnIndexForWindow(rows[0]) : 1
    }

    function columnCountForWorkspace(workspace) {
        if (!workspace) return 0

        const seen = ({})
        const rows = windowsForWorkspace(workspace.id)
        for (let i = 0; i < rows.length; i++) {
            seen[columnIndexForWindow(rows[i])] = true
        }

        const keys = Object.keys(seen)
        if (keys.length === 0) return 1
        let maxColumn = 1
        for (let j = 0; j < keys.length; j++) {
            maxColumn = Math.max(maxColumn, Number(keys[j]))
        }
        return maxColumn
    }

    Process {
        id: eventStream
        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) { root.parseEvent(line) }
        }
        onStarted: root.eventStreamRunning = true
        onExited: {
            root.eventStreamRunning = false
            streamRestart.restart()
        }
    }

    Timer {
        id: streamRestart
        interval: 1000
        repeat: false
        onTriggered: eventStream.running = true
    }

    Process {
        id: workspacesProc
        command: ["niri", "msg", "-j", "workspaces"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.loadWorkspaces(text)
        }
    }

    Process {
        id: windowsProc
        command: ["niri", "msg", "-j", "windows"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.loadWindows(text)
        }
    }

    Process {
        id: screenCaptureProc
        command: ["pgrep", "--quiet", "-f", "^gpu-screen-recorder"]
        onExited: function(exitCode) {
            root.gpuScreenRecorderActive = exitCode === 0
        }
    }

    Timer {
        interval: 2500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
