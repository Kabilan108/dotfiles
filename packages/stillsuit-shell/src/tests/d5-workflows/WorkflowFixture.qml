import QtQuick
import Quickshell
import Quickshell.Io
import "plugins/builtin/workflows" as Workflows

ShellRoot {
    id: fixture

    QtObject {
        id: fixtureContext
        property var settings: ({ values: {
            recorderHelperPath: Quickshell.env("STILLSUIT_FIXTURE_HELPER"),
            recordingStatePath: Quickshell.env("STILLSUIT_FIXTURE_RECORDING_STATE"),
            meetingStatusPath: Quickshell.env("STILLSUIT_FIXTURE_MEETING_STATE"),
            dictatorSocketPath: Quickshell.env("STILLSUIT_FIXTURE_SOCKET")
        } })
    }

    Workflows.Service { id: workflows; context: fixtureContext }

    // Two output views consume one global aggregate. Production OsdOverlay
    // instances use context.services.get() with the same identity.
    property var overlayViews: [
        { outputId: "fixture-a", workflows: workflows },
        { outputId: "fixture-b", workflows: workflows }
    ]

    IpcHandler {
        target: "stillsuit-d5-fixture"
        function state(): string {
            return JSON.stringify({
                aggregateApiVersion: workflows.apiVersion,
                serviceObjects: 1,
                overlays: overlayViews.length,
                overlaySharesAggregate: overlayViews[0].workflows === overlayViews[1].workflows,
                recording: { apiVersion: workflows.recording.apiVersion, phase: workflows.recording.phase, status: workflows.recording.stateStatus, active: workflows.recording.active, command: workflows.recording.lastCommandJson },
                meeting: { apiVersion: workflows.meeting.apiVersion, phase: workflows.meeting.phase, status: workflows.meeting.stateStatus },
                dictator: { apiVersion: workflows.dictator.apiVersion, state: workflows.dictator.visualizerState, socketConnections: workflows.dictator.socketConnections, levels: workflows.dictator.levels.length }
            })
        }
        function refresh(): string { workflows.recording.refresh(); workflows.meeting.refresh(); return "ok" }
        function start(): string { return workflows.recording.start("/tmp/fixture-recordings", "DP-1", "fixture-title", true, false) }
    }
}
