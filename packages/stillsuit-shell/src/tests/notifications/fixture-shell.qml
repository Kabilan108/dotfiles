import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services

ShellRoot {
    id: fixture

    QtObject {
        id: fixtureContext

        property var settings: ({
            values: {
                claimNotificationBus: true,
                notifications: {
                    popupLimit: 5,
                    historyLimit: 100,
                    normalTimeoutMs: 5000,
                    lowTimeoutMs: 4000
                }
            },
            paths: {
                stateRoot: Quickshell.env("XDG_STATE_HOME")
            }
        })
        property var compositor: ({
            focusedOutputId: "output-a",
            outputs: [{ id: "output-a" }, { id: "output-b" }]
        })
        property var logger: ({
            debug: function(message) {},
            info: function(message) {},
            warn: function(message) { console.warn(message) },
            error: function(message) { console.error(message) }
        })
    }

    Services.NotificationService {
        id: notificationService
        context: fixtureContext
    }

    IpcHandler {
        target: "stillsuit-notification-fixture"

        function ready(): string {
            return notificationService.ready && notificationService.serverActive ? "ready" : "loading"
        }

        function state(): string {
            return JSON.stringify({
                dnd: notificationService.doNotDisturb,
                popups: notificationService.popups,
                history: notificationService.history,
                trackedCount: notificationService.trackedCount
            })
        }

        function firstKey(): string {
            var rows = notificationService.centerRows()
            return rows.length > 0 ? rows[0].key : ""
        }

        function invokeFirst(identifier: string): string {
            var key = firstKey()
            return key ? notificationService.invokeAction(key, identifier) : "unknown"
        }

        function dismissAll(): string {
            return notificationService.dismissAll()
        }

        function setDnd(value: string): string {
            var normalized = String(value).toLowerCase()
            return notificationService.setDnd(normalized === "on" || normalized === "true" || normalized === "1")
        }

        function presentationProof(): string {
            var rowsA = notificationService.toastsForOutput("output-a")
            var rowsB = notificationService.toastsForOutput("output-b")
            return JSON.stringify({
                serviceInstances: 1,
                outputA: rowsA.length,
                outputB: rowsB.length,
                overlap: rowsA.filter(function(left) {
                    return rowsB.some(function(right) { return right.key === left.key })
                }).length
            })
        }
    }
}
