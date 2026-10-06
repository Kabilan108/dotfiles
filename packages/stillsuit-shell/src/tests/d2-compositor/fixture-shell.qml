import QtQuick
import Quickshell
import Quickshell.Io
import "FixtureTheme.js" as FixtureTheme
import "services" as Services
import "plugins/builtin/workspaces" as Workspaces

ShellRoot {
    id: fixture

    // The fixture loads services and plugins from the live checkout. A hot
    // reload triggered by an unrelated edit would reset the state under test.
    settings.watchFiles: false

    property var markedWorkspaces: []
    property var markedWindows: []
    property var markedDelegates: []
    property var markedDelegateIds: []
    property int markedRevision: 0

    function workspaceDelegates() {
        var strip = workspaceView.children[0].children[0]
        var result = []
        for (var index = 0; index < strip.children.length; index++) {
            var child = strip.children[index]
            if (child.workspace !== undefined) result.push(child)
        }
        return result
    }

    function rowsReused(rows, markedRows) {
        var reused = {}
        for (var index = 0; index < rows.length; index++) {
            var row = rows[index]
            var match = false
            for (var markedIndex = 0; markedIndex < markedRows.length; markedIndex++) {
                if (markedRows[markedIndex] === row) match = true
            }
            reused[String(row.id)] = match
        }
        return reused
    }

    Services.NiriService {
        id: niri
        reconciliationTimeoutMs: 3000
        reconnectDelayMs: 50
        reconnectMaxDelayMs: 200
    }

    QtObject {
        id: widgetContext
        property var compositor: niri.adapter
        property var theme: FixtureTheme.create()
        property var settings: ({ values: { reducedMotion: true } })
    }

    Workspaces.WorkspaceWidget {
        id: workspaceView
        context: widgetContext
        outputId: "HDMI-A-1"
    }

    IpcHandler {
        target: "stillsuit-d2-compositor-fixture"

        function state(): string {
            return JSON.stringify({
                apiVersion: niri.adapter.apiVersion,
                name: niri.adapter.name,
                revision: niri.adapter.revision,
                outputs: niri.adapter.outputs,
                focusedOutputId: niri.adapter.focusedOutputId,
                workspaces: niri.adapter.workspaces,
                windows: niri.adapter.windows,
                lastFocusedWindowId: niri.adapter.lastFocusedWindowId
            })
        }

        function ownership(): string {
            return JSON.stringify({
                serviceInstances: niri.instanceCount,
                adapterInstances: 1,
                eventStreamRunning: niri.eventStreamRunning
            })
        }

        function reconciliation(): string {
            return JSON.stringify({
                completedGeneration: niri.lastCompletedReconciliationGeneration,
                acceptedGeneration: niri.lastAcceptedReconciliationGeneration,
                timedOutGeneration: niri.lastTimedOutReconciliationGeneration,
                running: niri.reconciliationRunning,
                intervalMs: niri.reconciliationIntervalMs
            })
        }

        function reconcile(): string {
            niri.refresh()
            return "ok"
        }

        function inject(line: string): string {
            return String(niri.parseEvent(line))
        }

        function focusWorkspace(workspaceId: string): string {
            return niri.focusWorkspace(workspaceId)
        }

        function markRows(): string {
            fixture.markedWorkspaces = niri.adapter.workspaces
            fixture.markedWindows = niri.adapter.windows
            fixture.markedRevision = niri.adapter.revision
            fixture.markedDelegates = fixture.workspaceDelegates()
            fixture.markedDelegateIds = fixture.markedDelegates.map(function(delegate) { return delegate.workspace.id })
            return "ok"
        }

        function rowIdentity(): string {
            var delegates = fixture.workspaceDelegates()
            var delegatesSame = delegates.length === fixture.markedDelegates.length
            var delegateStates = []
            var delegateKept = {}
            for (var index = 0; index < delegates.length; index++) {
                var delegate = delegates[index]
                if (fixture.markedDelegates.indexOf(delegate) < 0) delegatesSame = false
                var workspaceId = delegate.workspace.id
                delegateStates.push({ id: workspaceId, active: delegate.active === true })
                var kept = false
                for (var markedIndex = 0; markedIndex < fixture.markedDelegates.length; markedIndex++) {
                    var marked = fixture.markedDelegates[markedIndex]
                    if (marked === delegate && fixture.markedDelegateIds[markedIndex] === workspaceId) kept = true
                }
                delegateKept[String(workspaceId)] = kept
            }
            return JSON.stringify({
                revisionDelta: niri.adapter.revision - fixture.markedRevision,
                workspacesArraySame: niri.adapter.workspaces === fixture.markedWorkspaces,
                windowsArraySame: niri.adapter.windows === fixture.markedWindows,
                workspaceRowsReused: fixture.rowsReused(niri.adapter.workspaces, fixture.markedWorkspaces),
                windowRowsReused: fixture.rowsReused(niri.adapter.windows, fixture.markedWindows),
                delegatesSame: delegatesSame,
                delegateStates: delegateStates,
                delegateKept: delegateKept,
                columns: workspaceView.columns,
                focusedColumn: workspaceView.focusedColumn
            })
        }

        function reconnect(): string {
            return JSON.stringify({
                attempts: niri.reconnectAttempts,
                scheduledDelayMs: niri.scheduledReconnectDelayMs,
                baseDelayMs: niri._reconnectDelay(0),
                doubledDelayMs: niri._reconnectDelay(1),
                cappedDelayMs: niri._reconnectDelay(20)
            })
        }
    }
}
