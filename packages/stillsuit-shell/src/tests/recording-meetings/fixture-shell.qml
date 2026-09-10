pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "plugins/builtin/recording" as Recording

ShellRoot {
    id: fixture

    readonly property string outputId: Quickshell.screens.length > 0
        ? String(Quickshell.screens[0].name) : "fixture-output"
    property var theme: ({
        schemaVersion: 2,
        semantic: {
            surface: { panel: "#101010", pressed: "#202020" },
            content: { primary: "#f0f0f0", secondary: "#d0d0d0", muted: "#a0a0a0", disabled: "#707070" },
            outline: { subtle: "#303030", default: "#404040", focus: "#5050ff" },
            accent: { primary: "#6060ff", onAccent: "#080808" },
            status: { info: "#50a0ff", success: "#50d080", warning: "#e0c050", danger: "#f05060" },
            signal: { audio: "#50d080", microphone: "#f05060", brightness: "#e0c050", recording: "#f05060" }
        },
        component: {
            bar: { background: "#101010", border: "#303030", clusterHover: "#202020", clusterActive: "#252545", clusterText: "#d0d0d0", clusterActiveText: "#f0f0f0" },
            panel: { background: "#101010", border: "#404040", section: "#202020", rowHover: "#252525", rowSelected: "#252545", rowDanger: "#402028" },
            control: { background: "#202020", hover: "#303030", pressed: "#404040", active: "#6060ff", disabled: "#181818", outline: "#404040", focus: "#5050ff", text: "#f0f0f0", textDisabled: "#707070", onActive: "#080808" },
            notification: { background: "#101010", border: "#404040" },
            osd: { border: "#404040", track: "#404040", fill: "#6060ff", text: "#f0f0f0" }
        },
        typography: { bodyFamily: "sans-serif", monoFamily: "monospace", iconFamily: "Material Symbols Rounded", baseSize: 13, captionSize: 11, headingSize: 17, weightRegular: 400, weightMedium: 500, weightBold: 700 },
        metrics: { spaceUnit: 4, radiusSmall: 5, radiusMedium: 7, radiusLarge: 11, barHeight: 26, iconSmall: 15, iconMedium: 18, iconLarge: 24, panelWidth: 380, panelPadding: 16, rowHeight: 38 },
        motion: { fast: 0, normal: 0, slow: 0 },
        effects: { surfaceOpacity: 0.8 }
    })

    QtObject {
        id: recordingModel
        property string phase: "idle"
        property bool active: phase === "recording" || phase === "paused"
        property bool paused: phase === "paused"
        property bool completed: phase === "completed"
        property string elapsedText: "01:02"
        property string outputPath: "/tmp/fixture recording.mp4"
        property string outputFilename: "fixture recording.mp4"
        property string outputSizeText: "2.0 KB"
        property string title: "fixture recording"
        property string monitor: "eDP-1"
        property string recordingDirectory: "/tmp/recordings"
        property bool defaultDesktopAudio: true
        property bool defaultMicrophone: false
        property bool actionRunning: false
        property int togglePauseCount: 0
        property int dismissCount: 0
        property int openRecordingCount: 0
        property int openFolderCount: 0
        property int copyPathCount: 0
        property string copiedPath: ""
        property string errorMessage: ""
        function defaultTitle() { return "fixture title" }
        function start(directory, monitor, title, desktopAudio, microphone) {
            phase = "recording"
            return "started"
        }
        function togglePause() {
            togglePauseCount += 1
            phase = paused ? "recording" : "paused"
            return "started"
        }
        function stopAsMeeting() { return "started" }
        function finish() { return "started" }
        function cancel() {
            phase = "idle"
            return "started"
        }
        function rename(requestedTitle) {
            outputPath = "/tmp/recordings/" + requestedTitle + ".mp4"
            title = requestedTitle
            return "started"
        }
        function copyOutputPath() {
            copyPathCount += 1
            copiedPath = outputPath
            return "copied"
        }
        function openRecording() {
            openRecordingCount += 1
            actionRunning = true
            return "started"
        }
        function openFolder() {
            openFolderCount += 1
            actionRunning = true
            return "started"
        }
        function dismiss() {
            dismissCount += 1
            phase = "idle"
            return "started"
        }
    }

    QtObject {
        id: meetingModel
        property bool visible: true
        property bool active: false
        property bool failed: false
        property bool completionVisible: false
        property bool failureVisible: false
        property string phase: "idle"
        property string label: ""
        property int progress: 0
        property int total: 0
        property string notePath: "/tmp/meeting note.md"
        property string copiedNotePath: ""
        property string jobsStateStatus: "ready"
        property bool retryConfigured: true
        property bool actionRunning: false
        property string retryingJobId: ""
        property string discardingJobId: ""
        property var jobs: [
            { jobId: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", phase: "error", title: "Failed meeting", label: "Meeting failed", progress: 0, total: 0, attempt: 2, error: "Fixture failure\nFull details", notePath: "", updatedAt: 20, createdAt: 10, completedAt: 0 },
            { jobId: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", phase: "completed", title: "Completed meeting", label: "Meeting note ready", progress: 1, total: 1, attempt: 1, error: "", notePath: "/tmp/meeting.md", updatedAt: 10, createdAt: 5, completedAt: 10 }
        ]
        // The real service persists discard through the meeting-minutes helper,
        // which rewrites jobs.json; refresh() there reloads from that file. This
        // fixture keeps the same in-memory jobs array as its durable source, so
        // calling refresh() after a discard must not resurrect the removed job.
        function refresh() {}
        function retry(jobId) { retryingJobId = jobId; return "started" }
        function discard(jobId) {
            discardingJobId = jobId
            jobs = jobs.filter(function (job) { return job.jobId !== jobId })
            return "started"
        }
        function openResult(jobId) { return "started" }
        function copyNotePath() {
            copiedNotePath = notePath
            completionVisible = false
            return "copied"
        }
    }

    QtObject {
        id: workflows
        property var recording: recordingModel
        property var meeting: meetingModel
    }

    QtObject {
        id: services
        function get(pluginId) { return pluginId === "stillsuit.workflows" ? workflows : null }
    }

    QtObject {
        id: actions
        property string lastOpenPlugin: ""
        property string lastOpenPayload: ""
        property int surfaceToggleCount: 0
        function surfaceClose(pluginId) {
            if (pluginId === "stillsuit.recording") recordingPanel.close()
            return "ok"
        }
        function surfaceToggle(pluginId, payloadJson) {
            surfaceToggleCount += 1
            lastOpenPlugin = String(pluginId)
            lastOpenPayload = String(payloadJson)
            return "ok"
        }
        function surfaceOpen(pluginId, payloadJson) {
            lastOpenPlugin = String(pluginId)
            lastOpenPayload = String(payloadJson)
            if (pluginId === "stillsuit.recording") recordingPanel.open(payloadJson)
            return "ok"
        }
    }

    QtObject {
        id: settings
        property var values: ({ reducedMotion: false })
    }

    QtObject {
        id: context
        property var theme: fixture.theme
        property var services: services
        property var actions: actions
        property var settings: settings
        property var compositor: ({
            focusedOutputId: fixture.outputId,
            outputs: [{ id: fixture.outputId, name: fixture.outputId, make: "Fixture", model: "Display", logical: { width: 1280, height: 720 } }]
        })
    }

    Recording.RecordingPanel {
        id: recordingPanel
        context: context
        screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        outputId: fixture.outputId
    }
    Recording.RecordingWidget {
        id: recordingWidget
        context: context
        outputId: fixture.outputId
    }

    IpcHandler {
        target: "stillsuit-recording-meetings-fixture"
        function ready(): string { return Quickshell.screens.length > 0 ? "ready" : "loading" }
        function openRecording(phase: string): string { recordingModel.phase = phase; recordingPanel.open(""); return recordingPanel.opened ? "open" : "closed" }
        function startFromPanel(): string {
            recordingModel.phase = "idle"
            recordingPanel.open("")
            return recordingPanel.startCapture()
        }
        function togglePauseFromPanel(phase: string): string {
            recordingModel.phase = phase
            recordingPanel.open("")
            return recordingPanel.togglePauseAndClose()
        }
        function cancelFromPanel(): string {
            recordingModel.phase = "recording"
            recordingPanel.open("")
            return recordingPanel.cancelAndClose()
        }
        function finishMeetingFromPanel(): string {
            recordingModel.phase = "recording"
            recordingPanel.open("")
            return recordingPanel.finishAsMeetingAndClose()
        }
        function renameFromPanel(requestedTitle: string): string {
            recordingModel.phase = "completed"
            recordingPanel.open("")
            recordingPanel.renameTitle = requestedTitle
            return recordingModel.rename(requestedTitle)
        }
        function closeCompletedPanel(): string {
            recordingModel.phase = "completed"
            recordingPanel.open("")
            recordingPanel.close()
            return "closed"
        }
        function openFileFromPanel(): string {
            recordingModel.phase = "completed"
            recordingPanel.open("")
            return recordingPanel.openRecordingAndClose()
        }
        function openFolderFromPanel(): string {
            recordingModel.phase = "completed"
            recordingPanel.open("")
            return recordingPanel.openFolderAndClose()
        }
        function copyPathFromPanel(): string {
            recordingModel.phase = "completed"
            recordingPanel.open("")
            return recordingPanel.copyOutputPathAndClose()
        }
        function finishOpenAction(): string {
            recordingModel.actionRunning = false
            return "finished"
        }
        function setReducedMotion(value: bool): string {
            settings.values = { reducedMotion: value }
            recordingModel.phase = "recording"
            return "ok"
        }
        function setMeetingProcessing(phase: string, label: string): string {
            recordingModel.phase = "idle"
            meetingModel.phase = phase
            meetingModel.label = label
            meetingModel.active = true
            return "ok"
        }
        function setMeetingCompleted(): string {
            recordingModel.phase = "idle"
            meetingModel.active = false
            meetingModel.phase = "completed"
            meetingModel.label = "Meeting note ready"
            meetingModel.completionVisible = true
            return "ok"
        }
        function setMeetingFailed(): string {
            recordingModel.phase = "idle"
            meetingModel.active = false
            meetingModel.phase = "error"
            meetingModel.failureVisible = true
            return "ok"
        }
        function clickRecordingWidget(): string {
            recordingWidget.toggleRecording()
            return meetingModel.copiedNotePath
        }
        function singleClickRecordingWidget(): string {
            recordingWidget.queueSingleClick()
            return "queued"
        }
        function doubleClickRecordingWidget(): string {
            recordingWidget.queueSingleClick()
            recordingWidget.handleDoubleClick()
            return "opened"
        }
        function resetInteractionCounts(): string {
            recordingModel.phase = "recording"
            meetingModel.active = false
            meetingModel.phase = "idle"
            recordingModel.togglePauseCount = 0
            actions.surfaceToggleCount = 0
            actions.lastOpenPlugin = ""
            return "ok"
        }
        function discardJob(jobId: string): string {
            meetingModel.discard(jobId)
            return "ok"
        }
        function refreshMeeting(): string {
            meetingModel.refresh()
            return "ok"
        }
        function state(): string {
            return JSON.stringify({
                recordingOpen: recordingPanel.opened,
                recordingPhase: recordingModel.phase,
                renameTitle: recordingPanel.renameTitle,
                dismissCount: recordingModel.dismissCount,
                openRecordingCount: recordingModel.openRecordingCount,
                openFolderCount: recordingModel.openFolderCount,
                copyPathCount: recordingModel.copyPathCount,
                copiedPath: recordingModel.copiedPath,
                actionRunning: recordingModel.actionRunning,
                recordingPanelWidth: recordingPanel.implicitWidth,
                standardPanelWidth: fixture.theme.metrics.panelWidth,
                recordingMeetingRows: recordingPanel.meetingQueueRowCount,
                meetingRows: meetingModel.jobs.length,
                recordingWidgetIcon: recordingWidget.indicatorIconName,
                recordingWidgetMeetingActive: recordingWidget.activeMeeting,
                recordingWidgetMeetingCompleted: recordingWidget.completedMeeting,
                recordingWidgetMeetingFailed: recordingWidget.failedMeeting,
                recordingWidgetMeetingLabel: recordingWidget.meetingLabel,
                recordingWidgetOutputLabel: recordingWidget.outputLabel,
                recordingWidgetWidth: recordingWidget.implicitWidth,
                togglePauseCount: recordingModel.togglePauseCount,
                surfaceToggleCount: actions.surfaceToggleCount,
                lastOpenPlugin: actions.lastOpenPlugin
            })
        }
    }
}
