import QtQuick
import Quickshell
import Quickshell.Io

// Recording control and recent transcripts for the dictation panel. Live
// state and levels come from the shared Dictator OSD projection in the
// workflows aggregate; this service only adds commands and history reads.
Scope {
    id: root

    required property var context

    readonly property string apiVersion: "1"
    readonly property var settings: context.settings ? context.settings.values : ({})
    readonly property string cliPath: String(settings.dictatorCliPath || "")
    readonly property string guiPath: String(settings.dictatorGuiPath || "")
    readonly property int recentLimit: Math.max(1, Math.min(10, Number(settings.recentLimit || 5)))
    readonly property bool configured: cliPath.charAt(0) === "/"
    readonly property var workflows: context.services ? context.services.get("stillsuit.workflows") : null
    readonly property QtObject dictator: workflows ? workflows.dictator : null
    readonly property string state: dictator ? String(dictator.visualizerState || "idle") : "idle"
    readonly property bool connected: dictator ? dictator.connectionState === "connected" : false
    readonly property bool recording: state === "recording"
    readonly property bool busy: state === "recording" || state === "transcribing" || state === "typing"
    readonly property bool canToggle: configured && connected && !actionRunning
        && (state === "idle" || state === "recording" || state === "error")
    readonly property bool canCancel: configured && connected && !actionRunning
        && (state === "recording" || state === "transcribing")
    readonly property var latest: recent.length > 0 ? recent[0] : null

    property int launchCount: 0
    property var recent: []
    property string recentStatus: "idle"
    property string errorMessage: ""
    property bool actionRunning: false
    property string actionKind: ""
    property string previousState: "idle"

    function toggle() { return _run("toggle") }
    function cancel() { return _run("cancel") }

    function _run(kind) {
        if (!configured) return "unconfigured"
        if (actionRunning) return "busy"
        actionRunning = true
        actionKind = kind
        errorMessage = ""
        action.command = [cliPath, kind]
        action.running = true
        return "started"
    }

    function refreshRecent() {
        if (!configured || history.running) return "busy"
        recentStatus = "loading"
        history.command = [cliPath, "transcripts", "-n", String(recentLimit)]
        history.running = true
        return "started"
    }

    function openWindow() {
        if (guiPath.charAt(0) !== "/") return "unconfigured"
        Quickshell.execDetached([guiPath])
        launchCount++
        return "started"
    }

    function copyText(text) {
        var value = String(text || "")
        if (value === "") return "empty"
        Quickshell.clipboardText = value
        return "copied"
    }

    function _applyHistory(text) {
        var parsed
        try { parsed = JSON.parse(text) } catch (error) { recentStatus = "error"; return }
        if (!Array.isArray(parsed)) { recentStatus = "error"; return }
        var rows = []
        for (var index = 0; index < parsed.length; index++) {
            var row = parsed[index]
            if (!row || typeof row !== "object") continue
            rows.push({
                id: Number(row.id || 0),
                timestamp: String(row.timestamp || ""),
                durationMs: Number(row.duration_ms || 0),
                text: String(row.text || "")
            })
        }
        recent = rows
        recentStatus = "ready"
    }

    // A finished recording lands in history after the daemon returns to idle.
    onStateChanged: {
        var was = previousState
        previousState = state
        if (was !== "idle" && (state === "idle" || state === "error")) refreshTimer.restart()
    }

    Timer {
        id: refreshTimer
        interval: 400
        repeat: false
        onTriggered: root.refreshRecent()
    }
    Process {
        id: action
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { id: actionErr; waitForEnd: true }
        onExited: function(exitCode) {
            root.actionRunning = false
            if (exitCode !== 0) {
                var detail = actionErr.text.trim().split("\n").filter(function(line) { return line !== "" }).pop() || ""
                root.errorMessage = detail !== "" ? detail : "dictator " + root.actionKind + " exited " + exitCode
            }
            root.actionKind = ""
        }
    }
    Process {
        id: history
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root._applyHistory(text)
        }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(exitCode) {
            if (exitCode !== 0) root.recentStatus = "error"
        }
    }
    Component.onCompleted: refreshRecent()
}
