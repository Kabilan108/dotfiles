import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services

ShellRoot {
    id: fixture

    Services.NiriService {
        id: niri
        reconciliationIntervalMs: 150
        reconnectDelayMs: 50
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
                windows: niri.adapter.windows
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
                running: niri.reconciliationRunning
            })
        }
    }
}
