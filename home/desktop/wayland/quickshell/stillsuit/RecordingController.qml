import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    required property var niri
    property var coordinator: null
    property bool visible: false
    property var monitors: []
    property string selectedMonitor: ""
    property bool desktopAudio: true
    property bool microphone: false
    property string draftTitle: ""
    property string renameTitle: ""
    property string phase: "idle"
    property string outputPath: ""
    property string activeMonitor: ""
    property int elapsedSeconds: 0
    property double outputSizeBytes: 0
    property string errorMessage: ""
    property bool actionRunning: false
    property string actionKind: ""
    property bool dismissAfterRename: false
    property bool completionInteractionActive: false
    property var policy: ({ recordings: { directory: Quickshell.env("HOME") + "/media/recordings" } })

    readonly property string helperPath: Quickshell.env("HOME") + "/bin/stillsuit-recorder"
    readonly property bool active: phase === "recording" || phase === "paused" || phase === "stopping"
    readonly property bool paused: phase === "paused"
    readonly property bool completed: phase === "completed"
    readonly property string outputFilename: {
        const parts = outputPath.split("/")
        return parts.length > 0 ? parts[parts.length - 1] : ""
    }
    readonly property string outputDirectory: {
        const index = outputPath.lastIndexOf("/")
        return index > 0 ? outputPath.slice(0, index) : recordingDirectory
    }
    readonly property string recordingDirectory: {
        const recordings = policy && policy.recordings
        return recordings && recordings.directory
            ? String(recordings.directory)
            : Quickshell.env("HOME") + "/media/recordings"
    }
    readonly property int completionTimeoutMs: {
        const recordings = policy && policy.recordings
        return recordings && recordings.completionTimeoutMs !== undefined
            ? Math.max(0, Number(recordings.completionTimeoutMs))
            : 8000
    }
    readonly property string elapsedText: formatDuration(elapsedSeconds)
    readonly property string outputSizeText: formatBytes(outputSizeBytes)

    function pad(value) {
        return String(value).padStart(2, "0")
    }

    function defaultTitle() {
        const now = new Date()
        return now.getFullYear() + "." + pad(now.getMonth() + 1) + "." + pad(now.getDate())
            + "-" + pad(now.getHours()) + "." + pad(now.getMinutes()) + "." + pad(now.getSeconds())
    }

    function formatDuration(seconds) {
        const total = Math.max(0, Number(seconds || 0))
        const hours = Math.floor(total / 3600)
        const minutes = Math.floor((total % 3600) / 60)
        const remaining = total % 60
        return hours > 0
            ? pad(hours) + ":" + pad(minutes) + ":" + pad(remaining)
            : pad(minutes) + ":" + pad(remaining)
    }

    function formatBytes(bytes) {
        const value = Math.max(0, Number(bytes || 0))
        if (value < 1024) return value + " B"
        if (value < 1024 * 1024) return (value / 1024).toFixed(1) + " KB"
        if (value < 1024 * 1024 * 1024) return (value / (1024 * 1024)).toFixed(1) + " MB"
        return (value / (1024 * 1024 * 1024)).toFixed(1) + " GB"
    }

    function parseState(raw) {
        try {
            const state = JSON.parse(String(raw || "{}"))
            phase = String(state.phase || "idle")
            outputPath = String(state.output || "")
            activeMonitor = String(state.monitor || "")
            elapsedSeconds = Number(state.elapsed_seconds || 0)
            outputSizeBytes = Number(state.size_bytes || 0)
            errorMessage = String(state.error || "")
            if (phase === "completed" && renameTitle === "") renameTitle = String(state.title || "")
        } catch (error) {
            console.warn("stillsuit recording: failed to parse state:", error)
        }
    }

    function parseMonitors(raw) {
        try {
            const outputs = JSON.parse(String(raw || "{}"))
            const rows = []
            const names = Object.keys(outputs)
            for (let index = 0; index < names.length; index++) {
                const output = outputs[names[index]] || {}
                const logical = output.logical || {}
                const modes = output.modes || []
                const mode = modes[Number(output.current_mode || 0)] || {}
                rows.push({
                    name: String(output.name || names[index]),
                    make: String(output.make || "Display"),
                    model: String(output.model || ""),
                    width: Number(mode.width || logical.width || 0),
                    height: Number(mode.height || logical.height || 0),
                    refreshRate: Number(mode.refresh_rate || 0) / 1000,
                    x: Number(logical.x || 0),
                    y: Number(logical.y || 0),
                    scale: Number(logical.scale || 1)
                })
            }
            rows.sort((left, right) => left.y === right.y ? left.x - right.x : left.y - right.y)
            monitors = rows
            const focused = root.niri ? root.niri.focusedOutput() : ""
            if (!selectedMonitor || !rows.some(row => row.name === selectedMonitor)) {
                selectedMonitor = rows.some(row => row.name === focused)
                    ? focused
                    : rows.length > 0 ? rows[0].name : ""
            }
        } catch (error) {
            console.warn("stillsuit recording: failed to parse outputs:", error)
            monitors = []
        }
    }

    function refresh() {
        if (!statusProc.running) statusProc.running = true
    }

    function refreshMonitors() {
        if (!monitorsProc.running) monitorsProc.running = true
    }

    function open() {
        if (coordinator && coordinator.closeInteractivePanels) coordinator.closeInteractivePanels(root)
        if (!active && !completed) {
            draftTitle = defaultTitle()
            desktopAudio = true
            microphone = false
            renameTitle = ""
            refreshMonitors()
        }
        visible = true
        refresh()
    }

    function close() {
        completionInteractionActive = false
        visible = false
    }

    function toggle() {
        if (visible) close()
        else open()
    }

    function runAction(kind, command) {
        if (actionRunning) return
        actionKind = kind
        actionRunning = true
        actionProc.command = command
        actionProc.running = true
    }

    function start() {
        if (!selectedMonitor || actionRunning) return
        const command = [
            helperPath, "start",
            "--directory", recordingDirectory,
            "--monitor", selectedMonitor,
            "--title", draftTitle || defaultTitle()
        ]
        command.push(desktopAudio ? "--desktop-audio" : "--no-desktop-audio")
        command.push(microphone ? "--microphone" : "--no-microphone")
        runAction("start", command)
    }

    function togglePause() {
        runAction("pause", [helperPath, "toggle-pause"])
    }

    function finish() {
        runAction("stop", [helperPath, "stop"])
    }

    function cancel() {
        runAction("cancel", [helperPath, "cancel"])
    }

    function rename() {
        if (!renameTitle.trim()) return
        runAction("rename", [helperPath, "rename", "--title", renameTitle.trim()])
    }

    function renameAndDismiss() {
        if (!renameTitle.trim()) return
        dismissAfterRename = true
        rename()
    }

    function dismiss() {
        completionInteractionActive = false
        runAction("dismiss", [helperPath, "dismiss"])
        visible = false
    }

    function openFolder() {
        Quickshell.execDetached(["xdg-open", outputDirectory])
    }

    function openRecording() {
        if (outputPath) Quickshell.execDetached(["xdg-open", outputPath])
    }

    Component.onCompleted: {
        refresh()
        refreshMonitors()
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/stillsuit-policy.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.policy = JSON.parse(text())
            } catch (error) {
                console.warn("stillsuit recording: failed to parse policy:", error)
            }
        }
    }

    Process {
        id: statusProc
        command: [root.helperPath, "status"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parseState(text)
        }
    }

    Process {
        id: monitorsProc
        command: ["niri", "msg", "-j", "outputs"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parseMonitors(text)
        }
    }

    Process {
        id: actionProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parseState(text)
        }
        onExited: function(exitCode) {
            const completedAction = root.actionKind
            root.actionRunning = false
            if (exitCode !== 0 && root.errorMessage === "") root.errorMessage = "Recording action failed"
            root.actionKind = ""
            if (exitCode === 0 && completedAction === "rename" && root.dismissAfterRename) {
                root.dismissAfterRename = false
                root.dismiss()
                return
            }
            if (exitCode === 0 && (completedAction === "start" || completedAction === "cancel")) {
                root.visible = false
            }
            root.dismissAfterRename = false
            root.refresh()
        }
    }

    Timer {
        interval: Math.max(1, root.completionTimeoutMs)
        running: root.visible && root.completed && !root.actionRunning
            && !root.completionInteractionActive && root.completionTimeoutMs > 0
        repeat: false
        onTriggered: root.dismiss()
    }

    Timer {
        interval: root.active ? 1000 : 5000
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "recording"

        function toggle(): string {
            root.toggle()
            return root.visible ? "open" : "closed"
        }

        function open(): string {
            root.open()
            return "open"
        }

        function close(): string {
            root.close()
            return "closed"
        }

        function status(): string {
            return JSON.stringify({
                phase: root.phase,
                elapsedSeconds: root.elapsedSeconds,
                monitor: root.activeMonitor,
                output: root.outputPath
            })
        }
    }
}
