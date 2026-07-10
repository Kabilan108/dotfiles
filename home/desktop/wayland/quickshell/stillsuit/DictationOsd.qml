import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property int stackOffset: 0
    property bool shouldShow: false
    readonly property int pillHeight: 38

    readonly property int maxReconnectAttempts: 30
    readonly property int reconnectInitialDelayMs: 1000
    readonly property int reconnectMaxDelayMs: 8000
    readonly property var runtimeDir: Quickshell.env("XDG_RUNTIME_DIR")
    readonly property string socketUser: socketUserID()
    readonly property string socketPath: runtimeDir
        ? runtimeDir + "/dictator/osd.sock"
        : "/tmp/dictator-osd-" + socketUser + "/osd.sock"

    readonly property int barCount: 23

    property bool reconnectExhausted: false
    property int reconnectAttempts: 0
    property string lastSocketError: ""
    property bool panelActive: false
    property string visualizerState: "idle"
    property real smoothedLevel: 0
    property var levels: []
    property real recordingBaseMs: 0
    property real recordingAnchorMs: 0
    property string durationText: ""

    Component.onCompleted: {
        resetLevels()
        dictatorSocket.connected = true
    }

    function clamp(value, min, max) {
        return Math.min(Math.max(value, min), max)
    }

    function socketUserID() {
        const user = sanitize(Quickshell.env("USER"))
        if (user.length > 0) return user
        const uid = sanitize(Quickshell.env("UID"))
        return uid.length > 0 ? uid : "unknown"
    }

    function sanitize(value) {
        return String(value || "").replace(/[^A-Za-z0-9_-]/g, "")
    }

    function isKnownState(value) {
        return value === "idle" || value === "recording" || value === "transcribing" || value === "typing" || value === "error"
    }

    function isVisibleState(value) {
        return value === "recording" || value === "transcribing" || value === "typing" || value === "error"
    }

    function isFiniteNumber(value) {
        return typeof value === "number" && isFinite(value)
    }

    function hasDuration(event) {
        return isFiniteNumber(event.recording_duration_ms) && event.recording_duration_ms >= 0
    }

    function resetLevels() {
        const next = []
        for (let i = 0; i < barCount; i++) next.push(0)
        levels = next
        smoothedLevel = 0
    }

    function setVisualizerState(value) {
        visualizerState = value
        if (isVisibleState(value)) {
            panelActive = true
            shouldShow = true
            deactivateTimer.stop()
        } else {
            shouldShow = false
            resetLevels()
            deactivateTimer.restart()
        }
    }

    function reconnectDelay() {
        const delay = reconnectInitialDelayMs * Math.pow(1.35, reconnectAttempts)
        return Math.min(Math.round(delay), reconnectMaxDelayMs)
    }

    function scheduleReconnect() {
        if (reconnectTimer.running || reconnectExhausted) return
        dictatorSocket.connected = false
        if (reconnectAttempts >= maxReconnectAttempts) {
            reconnectExhausted = true
            setVisualizerState("idle")
            console.warn("dictator OSD socket reconnect limit reached:", lastSocketError)
            return
        }
        reconnectTimer.interval = reconnectDelay()
        reconnectAttempts += 1
        reconnectTimer.restart()
    }

    function normalizeLevel(rms, peak) {
        const db = 20 * (Math.log(Math.max(rms, 0.00000001)) / Math.LN10)
        const rmsLevel = Math.pow(clamp((db + 50) / 38, 0, 1), 0.65)
        const peakLevel = Math.sqrt(clamp((peak - 0.03) / 0.77, 0, 1))
        return clamp(Math.max(rmsLevel * 0.88, peakLevel * 0.55), 0, 0.92)
    }

    function pushLevel(rms, peak) {
        const target = normalizeLevel(clamp(rms, 0, 1), clamp(peak, 0, 1))
        const alpha = target > smoothedLevel ? 0.55 : 0.25
        smoothedLevel = (smoothedLevel * (1 - alpha)) + (target * alpha)

        const next = levels.slice()
        while (next.length < barCount) next.unshift(0)
        next.push(smoothedLevel)
        while (next.length > barCount) next.shift()
        levels = next
    }

    function applyMeter(event) {
        if (!isFiniteNumber(event.rms) || !isFiniteNumber(event.peak)) return
        if (visualizerState !== "recording") return
        pushLevel(event.rms, event.peak)
    }

    function formatDuration(ms) {
        const totalSeconds = Math.floor(Math.max(ms, 0) / 1000)
        const minutes = Math.floor(totalSeconds / 60)
        const seconds = totalSeconds % 60
        return minutes + ":" + (seconds < 10 ? "0" + seconds : seconds)
    }

    function updateDuration() {
        durationText = formatDuration(recordingBaseMs + (Date.now() - recordingAnchorMs))
    }

    function applyState(event) {
        const value = String(event.value || "")
        if (!isKnownState(value)) return
        if ((value === "recording" || value === "transcribing") && !hasDuration(event)) return
        if (value === "error" && event.message !== undefined && typeof event.message !== "string") return

        if (value === "recording") {
            recordingBaseMs = event.recording_duration_ms
            recordingAnchorMs = Date.now()
            updateDuration()
        } else if (value === "transcribing") {
            durationText = formatDuration(event.recording_duration_ms)
        } else if (value !== "typing") {
            durationText = ""
        }
        setVisualizerState(value)
    }

    function applyLine(line) {
        const trimmed = line.trim()
        if (trimmed.length === 0) return
        try {
            const event = JSON.parse(trimmed)
            if (!event || typeof event.type !== "string") return
            if (event.type === "state") applyState(event)
            else if (event.type === "meter") applyMeter(event)
        } catch (error) {}
    }

    Timer {
        id: reconnectTimer
        repeat: false
        onTriggered: dictatorSocket.connected = true
    }

    Timer {
        id: deactivateTimer
        interval: 140
        onTriggered: if (!root.shouldShow) root.panelActive = false
    }

    Timer {
        interval: 500
        repeat: true
        running: root.visualizerState === "recording" && root.shouldShow
        triggeredOnStart: true
        onTriggered: root.updateDuration()
    }

    Socket {
        id: dictatorSocket
        path: root.socketPath
        connected: false

        onConnectedChanged: {
            if (connected) {
                root.lastSocketError = ""
                root.reconnectAttempts = 0
                root.reconnectExhausted = false
            } else {
                root.scheduleReconnect()
            }
        }

        onError: function(error) {
            root.lastSocketError = String(error)
            root.scheduleReconnect()
        }

        parser: SplitParser {
            splitMarker: "\n"
            onRead: function(data) { root.applyLine(data) }
        }
    }

    LazyLoader {
        active: root.panelActive

        PanelWindow {
            anchors.bottom: true
            margins.bottom: screen.height * 0.02 + root.stackOffset
            exclusiveZone: 0
            aboveWindows: true
            focusable: false
            implicitWidth: pill.implicitWidth
            implicitHeight: pill.implicitHeight
            color: "transparent"
            mask: Region {}

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "dictator-osd"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Item {
                anchors.fill: parent
                opacity: root.shouldShow ? 1 : 0
                scale: root.shouldShow ? 1 : 0.96

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animationFast
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.animationFast
                        easing.type: Easing.OutCubic
                    }
                }

                DictationPill {
                    id: pill
                    anchors.centerIn: parent
                    mode: root.visualizerState
                    levels: root.levels
                    durationText: root.durationText
                }
            }
        }
    }
}
