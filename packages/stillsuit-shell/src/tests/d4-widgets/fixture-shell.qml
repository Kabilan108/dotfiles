import QtQuick
import Quickshell
import Quickshell.Io
import "FixtureTheme.js" as FixtureTheme
import "plugins/builtin/bar" as Bar
import "plugins/builtin/clock" as Clock
import "plugins/builtin/meeting" as Meeting
import "plugins/builtin/recording" as Recording
import "plugins/builtin/resources" as Resources
import "plugins/builtin/workspaces" as Workspaces

ShellRoot {
    id: fixture

    property int clockServiceInstances: 0
    property int resourceServiceInstances: 0
    property int workspaceConstructionCount: 0
    property var productionWorkspaceCounts: ({})
    property var actionCalls: []
    readonly property string primaryOutputId: Quickshell.screens.length > 0
        ? String(Quickshell.screens[0].name) : ""
    readonly property string secondaryOutputId: Quickshell.screens.length > 1
        ? String(Quickshell.screens[1].name) : ""

    function recordProductionWorkspace(outputId, count) {
        var next = Object.assign({}, productionWorkspaceCounts)
        next[String(outputId)] = count
        productionWorkspaceCounts = next
        workspaceConstructionCount++
    }

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
        property bool active: true
        property string label: "Making minutes"
        property string errorMessage: ""
        property var jobs: []
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
        function surfaceOpen(pluginId, payloadJson) {
            fixture.actionCalls = fixture.actionCalls.concat([String(pluginId)])
            return "ok"
        }
        function surfaceClose(pluginId) { return "ok" }
    }

    QtObject {
        id: context
        property var services: serviceFacade
        property var actions: actions
        property var settings: ({ values: { shadowMode: true } })
        property var logger: ({
            debug: function(message) {},
            info: function(message) {},
            warn: function(message) { console.warn(message) },
            error: function(message) { console.error(message) }
        })
        property var compositor: ({
            outputs: [{ id: fixture.primaryOutputId }, { id: fixture.secondaryOutputId }],
            focusedOutputId: fixture.secondaryOutputId,
            workspaces: [
                { id: 1, idx: 1, output: fixture.primaryOutputId, is_active: true, active_window_id: 11 },
                { id: 2, idx: 1, output: fixture.secondaryOutputId, is_active: true, active_window_id: 22 },
                { id: 3, idx: 2, output: fixture.secondaryOutputId, is_urgent: true }
            ],
            windows: [
                { id: 11, workspace_id: 1, is_focused: true, layout: { pos_in_scrolling_layout: [1] } },
                { id: 22, workspace_id: 2, is_focused: true, layout: { pos_in_scrolling_layout: [2] } },
                { id: 23, workspace_id: 2, layout: { pos_in_scrolling_layout: [4] } }
            ]
        })
        property var theme: FixtureTheme.create()
    }

    Resources.ResourceService {
        id: resourceService
        context: context
        statPath: Quickshell.env("STILLSUIT_FIXTURE_STAT")
        memoryPath: Quickshell.env("STILLSUIT_FIXTURE_MEMINFO")
        Component.onCompleted: fixture.resourceServiceInstances += 1
        Component.onDestruction: fixture.resourceServiceInstances -= 1
    }

    Clock.ClockService {
        id: clockService
        context: context
        Component.onCompleted: fixture.clockServiceInstances += 1
        Component.onDestruction: fixture.clockServiceInstances -= 1
    }

    Component {
        id: productionWorkspaceComponent

        Workspaces.WorkspaceWidget {
            Component.onCompleted: fixture.recordProductionWorkspace(outputId, workspaces.length)
        }
    }

    Bar.Bar {
        id: productionBar
        context: context
        widgetRegistrations: [{
            component: productionWorkspaceComponent,
            context: context,
            manifest: { id: "stillsuit.workspaces" },
            defaultSection: "left",
            allowMultiple: false
        }]
        outputScreens: Quickshell.screens
    }

    Item {
        Clock.ClockWidget { id: clockOne; context: context; service: clockService; outputId: fixture.primaryOutputId }
        Clock.ClockWidget { id: clockTwo; context: context; service: clockService; outputId: fixture.secondaryOutputId }
        Workspaces.WorkspaceWidget { id: workspacePrimary; context: context; outputId: fixture.primaryOutputId }
        Workspaces.WorkspaceWidget { id: workspaceSecondary; context: context; outputId: fixture.secondaryOutputId }
        Resources.ResourceWidget { id: resourcesPrimary; context: context; service: resourceService; outputId: fixture.primaryOutputId }
        Resources.ResourceWidget { id: resourcesSecondary; context: context; service: resourceService; outputId: fixture.secondaryOutputId }
        Meeting.MeetingWidget { id: meetingPrimary; context: context; outputId: fixture.primaryOutputId }
        Meeting.MeetingWidget { id: meetingSecondary; context: context; outputId: fixture.secondaryOutputId }
        Recording.RecordingWidget { id: recordingPrimary; context: context; outputId: fixture.primaryOutputId }
        Recording.RecordingWidget { id: recordingSecondary; context: context; outputId: fixture.secondaryOutputId }
    }

    IpcHandler {
        target: "stillsuit-d4-fixture"
        function ready(): string {
            return fixture.clockServiceInstances === 1 && fixture.resourceServiceInstances === 1
                && fixture.workspaceConstructionCount === 2
                ? "ready" : "loading"
        }
        function topology(): string {
            return JSON.stringify({
                clockServiceInstances: fixture.clockServiceInstances,
                resourceServiceInstances: fixture.resourceServiceInstances,
                outputs: 2,
                clockViews: 2,
                workspaceViews: 2,
                resourceViews: 2,
                meetingViews: 2,
                recordingViews: 2,
                sharedClockService: clockOne.service === clockTwo.service,
                sharedResourceService: resourcesPrimary.service === resourcesSecondary.service
            })
        }
        function productionBarSnapshot(): string {
            return JSON.stringify({
                constructions: fixture.workspaceConstructionCount,
                outputIds: [fixture.primaryOutputId, fixture.secondaryOutputId],
                primaryWorkspaces: fixture.productionWorkspaceCounts[fixture.primaryOutputId],
                secondaryWorkspaces: fixture.productionWorkspaceCounts[fixture.secondaryOutputId]
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
        function resourceSnapshot(): string {
            resourceService.refresh()
            return JSON.stringify({
                cpuPercent: resourceService.cpuPercent,
                memoryPercent: resourceService.memoryPercent
            })
        }
        function routeActions(): string {
            meetingPrimary.trigger()
            recordingPrimary.trigger()
            resourcesPrimary.trigger()
            return JSON.stringify(fixture.actionCalls)
        }
        function workflowState(): string {
            recordingModel.elapsedText = "01:07"
            meetingModel.completed = true
            meetingModel.label = "Minutes ready"
            return JSON.stringify({
                recordingText: recordingPrimary.recording.elapsedText,
                meetingText: meetingPrimary.meeting.label,
                meetingCompleted: meetingPrimary.meeting.completed
            })
        }
    }
}
