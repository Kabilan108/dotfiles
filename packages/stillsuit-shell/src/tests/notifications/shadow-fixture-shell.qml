import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services

ShellRoot {
    QtObject {
        id: fixtureContext
        property var settings: ({
            values: { shadowMode: true },
            paths: { stateRoot: Quickshell.env("XDG_STATE_HOME") }
        })
        property var compositor: ({ focusedOutputId: "", outputs: [] })
        property var logger: ({ warn: function(message) { console.warn(message) } })
    }

    Services.NotificationService {
        id: notificationService
        context: fixtureContext
    }

    IpcHandler {
        target: "stillsuit-notification-shadow-fixture"
        function ready(): string {
            return notificationService.ready && !notificationService.serverActive ? "ready" : "loading"
        }
    }
}
