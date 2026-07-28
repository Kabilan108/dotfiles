import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property string phase: "idle"
    property string label: ""
    property string notePath: ""
    property string errorMessage: ""
    property int progress: 0
    property int total: 0
    property double visibleUntil: 0
    property double currentTime: Date.now() / 1000

    readonly property bool active: ["staging", "queued", "preparing", "chunking", "transcribing", "diarizing", "aligning", "generating", "enriching", "writing"].includes(phase)
    readonly property bool completed: phase === "completed"
    readonly property bool failed: phase === "error"
    readonly property bool visible: active || ((completed || failed) && currentTime < visibleUntil)

    function parseState(raw) {
        try {
            const state = JSON.parse(String(raw || "{}"))
            phase = String(state.phase || "idle")
            label = String(state.label || "")
            notePath = String(state.note_path || "")
            errorMessage = String(state.error || "")
            progress = Number(state.progress || 0)
            total = Number(state.total || 0)
            visibleUntil = Number(state.visible_until || 0)
        } catch (error) {
            console.warn("meeting minutes: failed to parse status:", error)
        }
    }

    function openResult() {
        if (completed && notePath) Quickshell.execDetached(["xdg-open", notePath])
    }

    Component.onCompleted: statusFile.reload()

    FileView {
        id: statusFile
        path: Quickshell.env("HOME") + "/.local/state/meeting-minutes/status.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parseState(text())
        onLoadFailed: root.phase = "idle"
    }

    Timer {
        interval: root.active ? 1000 : 5000
        running: true
        repeat: true
        onTriggered: statusFile.reload()
    }

    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        onTriggered: root.currentTime = Date.now() / 1000
    }
}
