import QtQuick
import Quickshell
import Quickshell.Io

// Global recording authority. Views only consume this snapshot; destroying a
// view or reloading an overlay never signals the recorder process.
Scope {
    id: root

    required property var context

    readonly property string apiVersion: "1"
    readonly property var settings: context.settings ? context.settings.values : ({})
    readonly property string helperPath: String(settings.recorderHelperPath || "")
    readonly property string statePath: String(settings.recordingStatePath || "")
    readonly property string recordingDirectory: String(settings.recordingDirectory || "")
    readonly property bool configured: helperPath.charAt(0) === "/" && statePath.charAt(0) === "/"
    readonly property bool active: phase === "recording" || phase === "paused" || phase === "stopping"
    readonly property bool paused: phase === "paused"
    readonly property bool completed: phase === "completed"
    readonly property string elapsedText: _formatDuration(elapsedSeconds)
    readonly property string outputFilename: {
        var parts = outputPath.split("/")
        return parts.length > 0 ? parts[parts.length - 1] : ""
    }

    property string phase: "idle"
    property string outputPath: ""
    property string monitor: ""
    property string title: ""
    property int elapsedSeconds: 0
    property double outputSizeBytes: 0
    property string errorMessage: ""
    property string stateStatus: configured ? "missing" : "unconfigured"
    property var snapshot: ({ schemaVersion: 1, phase: "idle" })
    property bool actionRunning: false
    property string lastCommandJson: "[]"

    function _finiteNumber(value, fallback) {
        var number = Number(value)
        return isFinite(number) ? number : fallback
    }

    function _formatDuration(seconds) {
        var total = Math.max(0, Math.round(seconds || 0))
        var hours = Math.floor(total / 3600)
        var minutes = Math.floor((total % 3600) / 60)
        var remaining = total % 60
        function pad(value) { return String(value).padStart(2, "0") }
        return hours > 0 ? pad(hours) + ":" + pad(minutes) + ":" + pad(remaining)
            : pad(minutes) + ":" + pad(remaining)
    }

    function _defaultTitle() {
        if (typeof settings.recordingDefaultTitle === "string" && settings.recordingDefaultTitle)
            return settings.recordingDefaultTitle
        var now = new Date()
        function pad(value) { return String(value).padStart(2, "0") }
        return now.getFullYear() + "." + pad(now.getMonth() + 1) + "." + pad(now.getDate())
            + "-" + pad(now.getHours()) + "." + pad(now.getMinutes()) + "." + pad(now.getSeconds())
    }

    function _reset(status, message) {
        phase = "idle"
        outputPath = ""
        monitor = ""
        title = ""
        elapsedSeconds = 0
        outputSizeBytes = 0
        errorMessage = String(message || "")
        stateStatus = status
        snapshot = ({ schemaVersion: 1, phase: "idle" })
    }

    function _apply(raw) {
        var value
        try {
            value = JSON.parse(String(raw || ""))
        } catch (error) {
            _reset("corrupt", "recording state is not JSON")
            return
        }
        if (!value || typeof value !== "object" || Array.isArray(value)) {
            _reset("corrupt", "recording state is not an object")
            return
        }
        if (Number(value.schemaVersion) !== 1) {
            _reset("unsupported", "recording state schemaVersion must be 1")
            return
        }
        var nextPhase = String(value.phase || "idle")
        if (["idle", "recording", "paused", "stopping", "completed", "error"].indexOf(nextPhase) === -1) {
            _reset("corrupt", "recording state phase is invalid")
            return
        }
        phase = nextPhase
        outputPath = String(value.output || "")
        monitor = String(value.monitor || "")
        title = String(value.title || "")
        elapsedSeconds = Math.max(0, Math.round(_finiteNumber(value.elapsed_seconds, 0)))
        outputSizeBytes = Math.max(0, _finiteNumber(value.size_bytes, 0))
        errorMessage = String(value.error || "")
        stateStatus = "ready"
        snapshot = value
    }

    function refresh() {
        if (configured)
            stateFile.reload()
    }

    function _run(argv) {
        if (!configured || actionRunning)
            return "unavailable"
        lastCommandJson = JSON.stringify(argv)
        actionRunning = true
        action.command = argv
        action.running = true
        return "started"
    }

    // Every command starts with the configured immutable helper path. No shell
    // string is constructed and this service never starts or owns the recorder.
    function start(directory, selectedMonitor, requestedTitle, desktopAudio, microphone) {
        if (arguments.length === 0) {
            directory = recordingDirectory
            selectedMonitor = context.compositor ? String(context.compositor.focusedOutputId || "") : ""
            requestedTitle = _defaultTitle()
            desktopAudio = settings.desktopAudioDefault === undefined ? true : Boolean(settings.desktopAudioDefault)
            microphone = settings.microphoneDefault === undefined ? false : Boolean(settings.microphoneDefault)
        }
        if (!String(directory || "").startsWith("/") || !String(selectedMonitor || "") || !String(requestedTitle || ""))
            return "invalid"
        return _run([
            helperPath, "start", "--directory", String(directory), "--monitor", String(selectedMonitor),
            "--title", String(requestedTitle), desktopAudio ? "--desktop-audio" : "--no-desktop-audio",
            microphone ? "--microphone" : "--no-microphone"
        ])
    }

    function togglePause() { return _run([helperPath, "toggle-pause"]) }
    function finish() { return _run([helperPath, "stop"]) }
    function stop() { return _run([helperPath, "stop"]) }
    function stopAsMeeting() { return _run([helperPath, "stop", "--meeting"]) }
    function cancel() { return _run([helperPath, "cancel"]) }
    function dismiss() { return _run([helperPath, "dismiss"]) }
    function rename(requestedTitle) {
        return String(requestedTitle || "").trim()
            ? _run([helperPath, "rename", "--title", String(requestedTitle).trim()])
            : "invalid"
    }

    FileView {
        id: stateFile
        path: root.statePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root._apply(text())
        onLoadFailed: root._reset(root.configured ? "missing" : "unconfigured", "")
    }

    Process {
        id: action
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(exitCode) {
            root.actionRunning = false
            if (exitCode !== 0)
                root.errorMessage = "recording helper exited " + exitCode
            root.refresh()
        }
    }

    Component.onCompleted: refresh()
}
