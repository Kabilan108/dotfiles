import QtQuick
import Quickshell
import Quickshell.Io

// Read-only projection of meeting-minutes' durable worker status. This service
// deliberately has no Process or worker control surface.
Scope {
    id: root

    required property var context

    readonly property string apiVersion: "1"
    readonly property var settings: context.settings ? context.settings.values : ({})
    readonly property string statusPath: String(settings.meetingStatusPath || "")
    readonly property bool configured: statusPath.charAt(0) === "/"
    readonly property bool active: ["staging", "queued", "preparing", "chunking", "transcribing", "diarizing", "aligning", "generating", "enriching", "writing"].indexOf(phase) !== -1
    readonly property bool completed: phase === "completed"
    readonly property bool failed: phase === "error"

    property string phase: "idle"
    property string label: ""
    property string notePath: ""
    property string errorMessage: ""
    property int progress: 0
    property int total: 0
    property double visibleUntil: 0
    property string stateStatus: configured ? "missing" : "unconfigured"
    property var snapshot: ({ schemaVersion: 1, phase: "idle" })

    function _reset(status, message) {
        phase = "idle"
        label = ""
        notePath = ""
        errorMessage = String(message || "")
        progress = 0
        total = 0
        visibleUntil = 0
        stateStatus = status
        snapshot = ({ schemaVersion: 1, phase: "idle" })
    }

    function _apply(raw) {
        var value
        try { value = JSON.parse(String(raw || "")) } catch (error) {
            _reset("corrupt", "meeting status is not JSON")
            return
        }
        if (!value || typeof value !== "object" || Array.isArray(value)) {
            _reset("corrupt", "meeting status is not an object")
            return
        }
        if (Number(value.schemaVersion) !== 1) {
            _reset("unsupported", "meeting status schemaVersion must be 1")
            return
        }
        phase = String(value.phase || "idle")
        label = String(value.label || "")
        notePath = String(value.note_path || "")
        errorMessage = String(value.error || "")
        progress = Math.max(0, Math.round(Number(value.progress || 0)))
        total = Math.max(0, Math.round(Number(value.total || 0)))
        visibleUntil = Math.max(0, Number(value.visible_until || 0))
        stateStatus = "ready"
        snapshot = value
    }

    function refresh() { if (configured) statusFile.reload() }

    FileView {
        id: statusFile
        path: root.statusPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root._apply(text())
        onLoadFailed: root._reset(root.configured ? "missing" : "unconfigured", "")
    }

    Component.onCompleted: refresh()
}
