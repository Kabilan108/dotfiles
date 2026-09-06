import QtQuick
import Quickshell
import Quickshell.Io

// The one global Dictator socket client. Overlay instances render this service
// state and never open another socket.
Scope {
    id: root

    required property var context

    readonly property string apiVersion: "1"
    readonly property var settings: context.settings ? context.settings.values : ({})
    readonly property string socketPath: String(settings.dictatorSocketPath || "")
    readonly property bool configured: socketPath.charAt(0) === "/"
    readonly property int barCount: 23
    readonly property bool visible: visualizerState === "recording" || visualizerState === "transcribing" || visualizerState === "typing" || visualizerState === "error"

    property string visualizerState: "idle"
    property var levels: []
    property string durationText: ""
    property string connectionState: configured ? "connecting" : "unconfigured"
    property int socketConnections: 0
    property int reconnectAttempts: 0
    property real smoothedLevel: 0
    property real recordingBaseMs: 0
    property real recordingAnchorMs: 0
    property real scanPos: 0

    function _clamp(value, minimum, maximum) { return Math.min(Math.max(value, minimum), maximum) }
    function _finite(value) { return typeof value === "number" && isFinite(value) }
    function _knownState(value) { return ["idle", "recording", "transcribing", "typing", "error"].indexOf(value) !== -1 }
    function _resetLevels() {
        var next = []
        for (var index = 0; index < barCount; index++) next.push(0)
        levels = next
        smoothedLevel = 0
    }
    function _formatDuration(milliseconds) {
        var seconds = Math.floor(Math.max(milliseconds, 0) / 1000)
        return Math.floor(seconds / 60) + ":" + String(seconds % 60).padStart(2, "0")
    }
    function _updateDuration() { durationText = _formatDuration(recordingBaseMs + Date.now() - recordingAnchorMs) }
    function _applyState(event) {
        var state = String(event.value || "")
        if (!_knownState(state)) return
        if ((state === "recording" || state === "transcribing") || event.recording_duration_ms !== undefined) {
            if (!_finite(event.recording_duration_ms) || event.recording_duration_ms < 0) return
        }
        visualizerState = state
        if (state === "recording") {
            recordingBaseMs = event.recording_duration_ms
            recordingAnchorMs = Date.now()
            _updateDuration()
        } else if (state === "transcribing") {
            durationText = _formatDuration(event.recording_duration_ms)
        } else if (state !== "typing") {
            durationText = ""
            _resetLevels()
        }
    }
    function _applyMeter(event) {
        if (visualizerState !== "recording" || !_finite(event.rms) || !_finite(event.peak)) return
        var decibels = 20 * (Math.log(Math.max(event.rms, 0.00000001)) / Math.LN10)
        var rms = Math.pow(_clamp((decibels + 50) / 38, 0, 1), 0.65)
        var peak = Math.sqrt(_clamp((event.peak - 0.03) / 0.77, 0, 1))
        var target = _clamp(Math.max(rms * 0.88, peak * 0.55), 0, 0.92)
        smoothedLevel = smoothedLevel * (target > smoothedLevel ? 0.45 : 0.75) + target * (target > smoothedLevel ? 0.55 : 0.25)
        var next = levels.slice()
        next.push(smoothedLevel)
        while (next.length > barCount) next.shift()
        levels = next
    }
    function applyLine(line) {
        var event
        try { event = JSON.parse(String(line || "").trim()) } catch (error) { return }
        if (!event || typeof event.type !== "string") return
        if (event.type === "state") _applyState(event)
        else if (event.type === "meter") _applyMeter(event)
    }
    function _reconnect() {
        if (!configured || reconnectTimer.running) return
        reconnectTimer.interval = Math.min(8000, Math.round(1000 * Math.pow(1.35, reconnectAttempts)))
        reconnectAttempts++
        reconnectTimer.restart()
    }

    Timer {
        id: reconnectTimer
        repeat: false
        onTriggered: socket.connected = root.configured
    }
    Timer {
        interval: 500
        repeat: true
        running: root.visualizerState === "recording"
        onTriggered: root._updateDuration()
    }
    Timer {
        interval: 16
        repeat: true
        running: root.visualizerState === "transcribing"
        onTriggered: root.scanPos = (root.scanPos + 0.2) % (root.barCount + 5)
    }
    Socket {
        id: socket
        path: root.socketPath
        connected: root.configured
        onConnectedChanged: {
            if (connected) {
                root.connectionState = "connected"
                root.socketConnections++
                root.reconnectAttempts = 0
            } else if (root.configured) {
                root.connectionState = "disconnected"
                root._reconnect()
            }
        }
        onError: function(error) {
            root.connectionState = "error"
            root._reconnect()
        }
        parser: SplitParser { splitMarker: "\n"; onRead: function(data) { root.applyLine(data) } }
    }
    Component.onCompleted: _resetLevels()
}
