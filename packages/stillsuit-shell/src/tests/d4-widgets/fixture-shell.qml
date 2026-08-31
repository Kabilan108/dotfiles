import QtQuick
import Quickshell
import Quickshell.Io
import "clock" as Clock
import "meeting" as Meeting
import "recording" as Recording
import "resources" as Resources
import "workspaces" as Workspaces

ShellRoot {
    id: fixture

    property int resourceServiceInstances: 0
    property var actionCalls: []

    QtObject {
        id: recordingModel
        property bool active: true
        property bool paused: false
        property string elapsedText: "00:12"
        property bool completed: false
        property string outputFilename: "fixture.mp4"
        property string errorMessage: ""
        property int startCalls: 0
        property int pauseCalls: 0
        property int finishCalls: 0
        function start() { startCalls += 1; active = true }
        function togglePause() { pauseCalls += 1; paused = !paused }
        function finish() { finishCalls += 1; active = false; completed = true }
    }

    QtObject {
        id: meetingModel
        property bool visible: true
        property bool failed: false
        property bool completed: false
        property string label: "Making minutes"
        property string errorMessage: ""
        property int openResultCalls: 0
        function openResult() { openResultCalls += 1 }
    }

    QtObject {
        id: workflowService
        property string apiVersion: "1"
        property var recording: recordingModel
        property var meeting: meetingModel
    }

    QtObject {
        id: serviceFacade
        function get(pluginId) { return pluginId === "stillsuit.workflows" ? workflowService : null }
    }

    QtObject {
        id: actions
        function surfaceToggle(pluginId, payloadJson) {
            fixture.actionCalls = fixture.actionCalls.concat([String(pluginId)])
            return "ok"
        }
        function surfaceClose(pluginId) { return "ok" }
    }

    QtObject {
        id: context
        property var services: serviceFacade
        property var actions: actions
        property var compositor: ({
            outputs: [{ id: "primary" }, { id: "secondary" }],
            focusedOutputId: "secondary",
            workspaces: [
                { id: 1, idx: 1, output: "primary", is_active: true, active_window_id: 11 },
                { id: 2, idx: 1, output: "secondary", is_active: true, active_window_id: 22 },
                { id: 3, idx: 2, output: "secondary", is_urgent: true }
            ],
            windows: [
                { id: 11, workspace_id: 1, is_focused: true, layout: { pos_in_scrolling_layout: [1] } },
                { id: 22, workspace_id: 2, is_focused: true, layout: { pos_in_scrolling_layout: [2] } },
                { id: 23, workspace_id: 2, layout: { pos_in_scrolling_layout: [4] } }
            ]
        })
        property var theme: ({
            colors: {
                surface: { panel: "#181825" }, text: { primary: "#cdd6f4", secondary: "#bac2de", tertiary: "#a6adc8" },
                border: { subtle: "#313244", normal: "#45475a" }, status: { info: "#89b4fa", success: "#a6e3a1", warning: "#f9e2af", danger: "#f38ba8" }
            }, controls: { normal: { fill: "#313244", text: "#cdd6f4", border: "#45475a" }, hover: { fill: "#45475a" } },
            typography: { family: "sans-serif", monospaceFamily: "monospace", baseSize: 13, weightMedium: 500, weightBold: 700 },
            geometry: { radius: 8, barHeight: 30, panelGap: 8 }, motion: { fast: 0 }
        })
    }

    Resources.ResourceService {
        id: resourceService
        context: context
        Component.onCompleted: fixture.resourceServiceInstances += 1
        Component.onDestruction: fixture.resourceServiceInstances -= 1
    }

    Item {
        Clock.ClockWidget { id: clockOne; context: context }
        Clock.ClockWidget { id: clockTwo; context: context }
        Workspaces.WorkspaceWidget { id: workspacePrimary; context: context; outputId: "primary" }
        Workspaces.WorkspaceWidget { id: workspaceSecondary; context: context; outputId: "secondary" }
        Resources.ResourceWidget { id: resourcesPrimary; context: context; service: resourceService }
        Resources.ResourceWidget { id: resourcesSecondary; context: context; service: resourceService }
        Meeting.MeetingWidget { id: meetingPrimary; context: context }
        Meeting.MeetingWidget { id: meetingSecondary; context: context }
        Recording.RecordingWidget { id: recordingPrimary; context: context }
        Recording.RecordingWidget { id: recordingSecondary; context: context }
    }

    IpcHandler {
        target: "stillsuit-d4-fixture"
        function ready(): string { return fixture.resourceServiceInstances === 1 ? "ready" : "loading" }
        function topology(): string {
            return JSON.stringify({
                serviceInstances: fixture.resourceServiceInstances,
                outputs: 2,
                clockViews: 2,
                workspaceViews: 2,
                resourceViews: 2,
                meetingViews: 2,
                recordingViews: 2,
                sharedResourceService: resourcesPrimary.service === resourcesSecondary.service
            })
        }
        function workspaceSnapshot(): string {
            return JSON.stringify({
                primaryWorkspaces: workspacePrimary.workspaces.length,
                secondaryWorkspaces: workspaceSecondary.workspaces.length,
                secondaryColumns: workspaceSecondary.columns,
                secondaryFocusedColumn: workspaceSecondary.focusedColumn
            })
        }
        function routeActions(): string {
            meetingPrimary.togglePanel()
            recordingPrimary.togglePanel()
            resourcesPrimary.togglePanel()
            return JSON.stringify(fixture.actionCalls)
        }
        function workflowState(): string {
            recordingModel.elapsedText = "01:07"
            meetingModel.completed = true
            meetingModel.label = "Minutes ready"
            return JSON.stringify({
                recordingText: recordingPrimary.recording.elapsedText,
                meetingText: meetingPrimary.meeting.label,
                meetingCompleted: meetingPrimary.completed
            })
        }
    }
}
