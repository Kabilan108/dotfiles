import QtQuick
import Quickshell
import Quickshell.Io
import "plugins/builtin/workflows" as Workflows
import "plugins/builtin/dictation" as Dictation
import "plugins/builtin/osd" as Osd
import "tests/FixtureTheme.js" as FixtureTheme

ShellRoot {
    id: fixture

    QtObject {
        id: fixtureContext
        property var settings: ({ values: {
            dictatorCliPath: Quickshell.env("STILLSUIT_FIXTURE_DICTATOR"),
            dictatorGuiPath: Quickshell.env("STILLSUIT_FIXTURE_DICTATOR_GUI"),
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
    Dictation.Panel { id: panel; context: fixtureContext; service: dictation; screen: ({ name: "DP-1" }); outputId: "DP-1" }
    Osd.DictationPill { id: pill; context: fixtureContext; dictator: workflows.dictator }

    function rectangles(node, found) {
        var children = node.children || []
        var bars = []
        for (var index = 0; index < children.length; index++) {
            if (children[index].border !== undefined) bars.push(children[index])
            rectangles(children[index], found)
        }
        if (bars.length === workflows.dictator.barCount) found.push(bars)
        return found
    }
    function meter(view) {
        var groups = rectangles(view, [])
        var bars = groups.length === 1 ? groups[0] : []
        return { groups: groups.length, heights: bars.map(function(bar) { return bar.height }) }
    }

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
                launchCount: dictation.launchCount,
                socketConnections: workflows.dictator.socketConnections
            })
        }
        function toggle(): string { return dictation.toggle() }
        function cancel(): string { return dictation.cancel() }
        function refresh(): string { return dictation.refreshRecent() }
        function openWindow(): string { return dictation.openWindow() }
        function copy(index: string): string { return dictation.copyText(dictation.recent[Number(index)].text) }
        function clipboard(): string { return String(Quickshell.clipboardText || "") }
        function setDictatorState(value: string): string {
            workflows.dictator.applyLine(JSON.stringify({ type: "state", value: value, recording_duration_ms: 1000 }))
            return workflows.dictator.visualizerState
        }
        function setPanelOpened(value: string): string { panel.opened = value === "on"; return "ok" }
        function meters(): string {
            return JSON.stringify({ scanPos: workflows.dictator.scanPos, panel: fixture.meter(panel), pill: fixture.meter(pill) })
        }
    }
}
