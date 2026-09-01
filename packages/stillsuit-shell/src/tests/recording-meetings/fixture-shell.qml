pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "plugins/builtin/meeting" as Meeting
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
        property string recordingDirectory: "/tmp/recordings"
        property bool defaultDesktopAudio: true
        property bool defaultMicrophone: false
        property bool actionRunning: false
        property string copiedPath: ""
        property string errorMessage: ""
        function defaultTitle() { return "fixture title" }
        function start(directory, monitor, title, desktopAudio, microphone) { return "started" }
        function togglePause() { return "started" }
        function stopAsMeeting() { return "started" }
        function finish() { return "started" }
        function cancel() { return "started" }
        function rename(title) { return "started" }
        function copyOutputPath() { copiedPath = outputPath; return "copied" }
        function openRecording() { return "started" }
        function openFolder() { return "started" }
        function dismiss() { phase = "idle"; return "started" }
    }

    QtObject {
        id: meetingModel
        property bool visible: true
        property bool active: false
        property bool failed: false
        property string label: ""
        property string jobsStateStatus: "ready"
        property bool retryConfigured: true
        property bool actionRunning: false
        property string retryingJobId: ""
        property var jobs: [
            { jobId: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", phase: "error", title: "Failed meeting", label: "Meeting failed", progress: 0, total: 0, attempt: 2, error: "Fixture failure\nFull details", notePath: "", updatedAt: 20, createdAt: 10, completedAt: 0 },
            { jobId: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", phase: "completed", title: "Completed meeting", label: "Meeting note ready", progress: 1, total: 1, attempt: 1, error: "", notePath: "/tmp/meeting.md", updatedAt: 10, createdAt: 5, completedAt: 10 }
        ]
        function refresh() {}
        function retry(jobId) { retryingJobId = jobId; return "started" }
        function openResult(jobId) { return "started" }
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
        function surfaceClose(pluginId) {
            if (pluginId === "stillsuit.recording") recordingPanel.close()
            if (pluginId === "stillsuit.meeting") meetingPanel.close()
            return "ok"
        }
        function surfaceToggle(pluginId, payloadJson) { return "ok" }
        function surfaceOpen(pluginId, payloadJson) {
            lastOpenPlugin = String(pluginId)
            lastOpenPayload = String(payloadJson)
            if (pluginId === "stillsuit.recording") recordingPanel.open(payloadJson)
            if (pluginId === "stillsuit.meeting") meetingPanel.open(payloadJson)
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
    Meeting.MeetingPanel {
        id: meetingPanel
        context: context
        screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        outputId: fixture.outputId
    }
    Meeting.MeetingWidget {
        id: meetingWidget
        context: context
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
        function openMeetings(): string { return meetingWidget.openMeetings() }
        function setReducedMotion(value: bool): string {
            settings.values = { reducedMotion: value }
            recordingModel.phase = "recording"
            return "ok"
        }
        function state(): string {
            return JSON.stringify({
                recordingOpen: recordingPanel.opened,
                selectedView: recordingPanel.selectedView,
                recordingMeetingRows: recordingPanel.meetingQueueRowCount,
                meetingOpen: meetingPanel.opened,
                meetingRows: meetingModel.jobs.length,
                meetingRoute: { pluginId: actions.lastOpenPlugin, payload: actions.lastOpenPayload },
                pulses: {
                    widget: recordingWidget.pulseRunning,
                    panel: recordingPanel.pulseRunning,
                    widgetScale: recordingWidget.pulseScale,
                    panelScale: recordingPanel.pulseScale
                }
            })
        }
    }
}
