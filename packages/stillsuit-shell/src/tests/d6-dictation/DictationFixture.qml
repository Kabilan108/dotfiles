import QtQuick
import Quickshell
import Quickshell.Io
import "plugins/builtin/workflows" as Workflows
import "plugins/builtin/dictation" as Dictation
import "tests/FixtureTheme.js" as FixtureTheme

ShellRoot {
    id: fixture

    QtObject {
        id: fixtureContext
        property var settings: ({ values: {
            dictatorCliPath: Quickshell.env("STILLSUIT_FIXTURE_DICTATOR"),
            dictatorGuiPath: "",
            recentLimit: 5,
            dictatorSocketPath: Quickshell.env("STILLSUIT_FIXTURE_SOCKET"),
            recorderHelperPath: "", recordingStatePath: "", meetingStatusPath: "",
            meetingJobsPath: "", meetingHelperPath: "", openHelperPath: "", publishHelperPath: ""
        } })
        property var compositor: ({ focusedOutputId: "DP-1" })
        property var theme: FixtureTheme.create()
        property var services: ({ get: function(id) { return id === "stillsuit.workflows" ? workflows : null } })
    }

    Workflows.Service { id: workflows; context: fixtureContext }
    Dictation.Service { id: dictation; context: fixtureContext }

    IpcHandler {
        target: "stillsuit-d6-fixture"
        function state(): string {
            return JSON.stringify({
                apiVersion: dictation.apiVersion,
                configured: dictation.configured,
                connected: dictation.connected,
                state: dictation.state,
                canToggle: dictation.canToggle,
                canCancel: dictation.canCancel,
                actionRunning: dictation.actionRunning,
                errorMessage: dictation.errorMessage,
                recentStatus: dictation.recentStatus,
                recent: dictation.recent,
                socketConnections: workflows.dictator.socketConnections
            })
        }
        function toggle(): string { return dictation.toggle() }
        function cancel(): string { return dictation.cancel() }
        function refresh(): string { return dictation.refreshRecent() }
        function copy(index: string): string { return dictation.copyText(dictation.recent[Number(index)].text) }
        function clipboard(): string { return String(Quickshell.clipboardText || "") }
    }
}
