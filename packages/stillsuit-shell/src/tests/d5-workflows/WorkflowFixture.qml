import QtQuick
import Quickshell
import Quickshell.Io
import "plugins/builtin/workflows" as Workflows
import "plugins/builtin/osd" as Osd

ShellRoot {
    id: fixture

    QtObject {
        id: fixtureContext
        property var settings: ({ values: {
            recorderHelperPath: Quickshell.env("STILLSUIT_FIXTURE_HELPER"),
            recordingStatePath: Quickshell.env("STILLSUIT_FIXTURE_RECORDING_STATE"),
            recordingDirectory: "/tmp/fixture-recordings",
            recordingDefaultTitle: "fixture-default-title",
            desktopAudioDefault: true,
            microphoneDefault: false,
            meetingStatusPath: Quickshell.env("STILLSUIT_FIXTURE_MEETING_STATE"),
            openHelperPath: Quickshell.env("STILLSUIT_FIXTURE_OPEN_HELPER"),
            dictatorSocketPath: Quickshell.env("STILLSUIT_FIXTURE_SOCKET")
        } })
        property var compositor: ({ focusedOutputId: "DP-1" })
        property var theme: ({ motion: { slow: 260 } })
    }

    Workflows.Service { id: workflows; context: fixtureContext }
    Osd.Service { id: osdService; context: fixtureContext }

    // Two output views consume one global aggregate. Production OsdOverlay
    // instances use context.services.get() with the same identity.
    property var overlayViews: [
        { outputId: "fixture-a", workflows: workflows, service: osdService },
        { outputId: "fixture-b", workflows: workflows, service: osdService }
    ]

    IpcHandler {
        target: "stillsuit-d5-fixture"
        function state(): string {
            return JSON.stringify({
                aggregateApiVersion: workflows.apiVersion,
                serviceObjects: 1,
                osdServiceObjects: 1,
                overlays: overlayViews.length,
                overlaySharesAggregate: overlayViews[0].workflows === overlayViews[1].workflows,
                overlaySharesOsdService: overlayViews[0].service === overlayViews[1].service,
                recording: { apiVersion: workflows.recording.apiVersion, phase: workflows.recording.phase, status: workflows.recording.stateStatus, active: workflows.recording.active, paused: workflows.recording.paused, elapsedSeconds: workflows.recording.elapsedSeconds, elapsedText: workflows.recording.elapsedText, completed: workflows.recording.completed, outputFilename: workflows.recording.outputFilename, errorMessage: workflows.recording.errorMessage, command: workflows.recording.lastCommandJson },
                meeting: { apiVersion: workflows.meeting.apiVersion, phase: workflows.meeting.phase, status: workflows.meeting.stateStatus, visible: workflows.meeting.visible, failed: workflows.meeting.failed, completed: workflows.meeting.completed, label: workflows.meeting.label, errorMessage: workflows.meeting.errorMessage, snapshotSchemaVersion: workflows.meeting.snapshot.schemaVersion, command: workflows.meeting.lastCommandJson },
                dictator: { apiVersion: workflows.dictator.apiVersion, state: workflows.dictator.visualizerState, socketConnections: workflows.dictator.socketConnections, levels: workflows.dictator.levels.length }
            })
        }
        function refresh(): string { workflows.recording.refresh(); workflows.meeting.refresh(); return "ok" }
        function start(): string { return workflows.recording.start("/tmp/fixture-recordings", "DP-1", "fixture-title", true, false) }
        function d4Start(): string { return workflows.recording.start() }
        function d4Finish(): string { return workflows.recording.finish() }
        function openResult(): string { return workflows.meeting.openResult() }
    }
}
