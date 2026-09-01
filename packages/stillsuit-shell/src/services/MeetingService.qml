import QtQuick
import Quickshell
import Quickshell.Io

// Projection of meeting-minutes' durable status and bounded queue snapshot.
// The worker owns every job. This service may request an explicit retry for a
// failed job, but never retries while loading state or recovering after reload.
Scope {
    id: root

    required property var context

    readonly property string apiVersion: "1"
    readonly property var settings: context.settings ? context.settings.values : ({})
    readonly property string statusPath: String(settings.meetingStatusPath || "")
    readonly property string jobsPath: String(settings.meetingJobsPath || _siblingPath(statusPath, "jobs.json"))
    readonly property string helperPath: String(settings.meetingHelperPath
        || _siblingPath(String(settings.recorderHelperPath || ""), "meeting-minutes"))
    readonly property string openHelperPath: String(settings.openHelperPath || "")
    readonly property bool configured: statusPath.charAt(0) === "/" && jobsPath.charAt(0) === "/"
        && openHelperPath.charAt(0) === "/"
    readonly property bool retryConfigured: helperPath.charAt(0) === "/"
    readonly property bool active: _isProcessingPhase(phase) || phase === "staging" || phase === "queued"
    readonly property bool completed: phase === "completed"
    readonly property bool failed: phase === "error"
    readonly property bool visible: jobs.length > 0 || active
        || ((completed || failed) && currentTime < visibleUntil)
    readonly property int actionableCount: jobs.filter(function(job) { return _isActionablePhase(job.phase) }).length

    property string phase: "idle"
    property string label: ""
    property string notePath: ""
    property string errorMessage: ""
    property int progress: 0
    property int total: 0
    property double visibleUntil: 0
    property double currentTime: Date.now() / 1000
    property string stateStatus: configured ? "missing" : "unconfigured"
    property string jobsStateStatus: configured ? "missing" : "unconfigured"
    property var snapshot: ({ schemaVersion: 1, phase: "idle" })
    property var jobsSnapshot: ({ schemaVersion: 1, jobs: [] })
    property var jobs: []
    property bool actionRunning: false
    property string retryingJobId: ""
    property string lastCommandJson: "[]"

    function _siblingPath(path, filename) {
        var value = String(path || "")
        var separator = value.lastIndexOf("/")
        return separator > 0 ? value.slice(0, separator + 1) + filename : ""
    }

    function _isProcessingPhase(value) {
        return ["preparing", "chunking", "transcribing", "diarizing", "aligning",
            "generating", "enriching", "writing"].indexOf(String(value || "")) !== -1
    }

    function _isActionablePhase(value) {
        var phaseName = String(value || "")
        return phaseName === "staging" || phaseName === "queued" || phaseName === "error"
            || _isProcessingPhase(phaseName)
    }

    function _validJobId(value) {
        return /^[a-f0-9]{32}$/.test(String(value || ""))
    }

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
        var legacy = value.schemaVersion === undefined
        if (legacy && !_isLegacyStatus(value)) {
            _reset("unsupported", "unversioned meeting status does not match the pre-version schema")
            return
        }
        if (!legacy && Number(value.schemaVersion) !== 1) {
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
        stateStatus = legacy ? "migrated" : "ready"
        if (legacy) {
            var migrated = JSON.parse(JSON.stringify(value))
            migrated.schemaVersion = 1
            snapshot = migrated
        } else {
            snapshot = value
        }
    }

    function _applyJobs(raw) {
        var value
        try { value = JSON.parse(String(raw || "")) } catch (error) {
            jobs = []
            jobsStateStatus = "corrupt"
            return
        }
        if (!value || typeof value !== "object" || Array.isArray(value)
                || Number(value.schemaVersion) !== 1 || !Array.isArray(value.jobs)) {
            jobs = []
            jobsStateStatus = "unsupported"
            return
        }
        var next = []
        for (var index = 0; index < value.jobs.length; index++) {
            var source = value.jobs[index]
            if (!source || typeof source !== "object" || Array.isArray(source)
                    || !_validJobId(source.job_id) || (!_isActionablePhase(source.phase)
                        && String(source.phase || "") !== "completed"))
                continue
            next.push({
                jobId: String(source.job_id),
                phase: String(source.phase),
                title: String(source.title || "Untitled meeting"),
                label: String(source.label || ""),
                progress: Math.max(0, Math.round(Number(source.progress || 0))),
                total: Math.max(0, Math.round(Number(source.total || 0))),
                attempt: Math.max(1, Math.round(Number(source.attempt || 1))),
                error: String(source.error || ""),
                notePath: String(source.note_path || ""),
                recordingPath: String(source.recording_path || ""),
                createdAt: Math.max(0, Number(source.created_at || 0)),
                updatedAt: Math.max(0, Number(source.updated_at || 0)),
                completedAt: Math.max(0, Number(source.completed_at || 0))
            })
        }
        jobsSnapshot = value
        jobs = next
        jobsStateStatus = "ready"
    }

    function _isLegacyStatus(value) {
        return typeof value.job_id === "string"
            && typeof value.phase === "string"
            && typeof value.label === "string"
            && typeof value.note_path === "string"
            && typeof value.error === "string"
            && typeof value.progress === "number" && isFinite(value.progress)
            && typeof value.total === "number" && isFinite(value.total)
            && typeof value.updated_at === "number" && isFinite(value.updated_at)
    }

    function _job(jobId) {
        for (var index = 0; index < jobs.length; index++)
            if (jobs[index].jobId === String(jobId || ""))
                return jobs[index]
        return null
    }

    function refresh() {
        if (!configured)
            return
        statusFile.reload()
        jobsFile.reload()
        if (retryConfigured && !jobListProcess.running) {
            jobListProcess.command = [helperPath, "jobs"]
            jobListProcess.running = true
        }
    }

    function openResult(jobId) {
        var selected = arguments.length > 0 ? _job(jobId) : null
        var selectedPhase = selected ? selected.phase : phase
        var selectedPath = selected ? selected.notePath : notePath
        if (selectedPhase !== "completed" || !selectedPath.startsWith("/")
                || selectedPath.indexOf("\u0000") !== -1 || actionRunning)
            return "unavailable"
        return _runAction([openHelperPath, selectedPath], "")
    }

    function retry(jobId) {
        var selected = _job(jobId)
        if (!retryConfigured || !selected || selected.phase !== "error" || actionRunning)
            return "unavailable"
        return _runAction([helperPath, "retry", selected.jobId], selected.jobId)
    }

    function _runAction(argv, retryJobId) {
        lastCommandJson = JSON.stringify(argv)
        retryingJobId = String(retryJobId || "")
        actionRunning = true
        action.command = argv
        action.running = true
        return "started"
    }

    FileView {
        id: statusFile
        path: root.statusPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root._apply(text())
        onLoadFailed: root._reset(root.configured ? "missing" : "unconfigured", "")
    }

    FileView {
        id: jobsFile
        path: root.jobsPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root._applyJobs(text())
        onLoadFailed: {
            root.jobs = []
            root.jobsStateStatus = root.configured ? "missing" : "unconfigured"
        }
    }

    Process {
        id: jobListProcess
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root._applyJobs(text)
        }
    }

    Process {
        id: action
        onExited: function(exitCode) {
            root.actionRunning = false
            root.retryingJobId = ""
            root.refresh()
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible && (root.completed || root.failed)
        onTriggered: root.currentTime = Date.now() / 1000
    }

    Component.onCompleted: refresh()
}
