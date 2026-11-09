import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services

ShellRoot {
    id: fixture

    readonly property int heldLimit: {
        var configured = Number(Quickshell.env("STILLSUIT_NOTIFICATION_HELD_LIMIT"))
        return isFinite(configured) && configured > 0 ? Math.round(configured) : 50
    }

    QtObject {
        id: fixtureContext

        property var settings: ({
            values: {
                claimNotificationBus: true,
                notifications: {
                    popupLimit: 5,
                    deckRowLimit: 8,
                    heldLimit: fixture.heldLimit,
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
                quiet: notificationService.quiet,
                popups: notificationService.popups,
                held: notificationService.held,
                queuedArrivals: notificationService.queuedArrivals,
                heldBadgeText: notificationService.heldBadgeText,
                decks: notificationService.toastDecksForOutput("output-a").map(function(deck) {
                    return { key: deck.key, rows: deck.rows.length }
                }),
                liveRefCount: Object.keys(notificationService.liveRefs).length,
                stateWrites: notificationService.stateWrites,
                now: Date.now()
            })
        }

        function firstKey(): string {
            var rows = notificationService.popups.length ? notificationService.popups : notificationService.held
            return rows.length > 0 ? rows[0].key : ""
        }

        function invokeFirst(identifier: string): string {
            var key = firstKey()
            return key ? notificationService.invokeAction(key, identifier) : "unknown"
        }

        function firstActionState(): string {
            var key = firstKey()
            return key ? notificationService.actionState(key) : "none"
        }

        function dismissFirst(): string {
            var key = firstKey()
            return key ? notificationService.dismiss(key) : "unknown"
        }

        function dismissPopups(): string {
            var writesBefore = notificationService.stateWrites
            var keys = notificationService.popups.map(function(row) { return row.key })
            for (var index = 0; index < keys.length; index++)
                notificationService.dismiss(keys[index])
            return JSON.stringify({
                dismissed: keys.length,
                synchronousWrites: notificationService.stateWrites - writesBefore
            })
        }

        function dismissAll(): string {
            return notificationService.dismissAll()
        }

        function toggleQuiet(): string {
            return notificationService.toggleQuiet()
        }

        function hoverFirst(value: string): string {
            var rows = notificationService.popups
            if (!rows.length) return "unknown"
            notificationService.setDeckHovered(rows[0].sourceKey, String(value) === "on")
            return "ok"
        }

        function pruneAt(timestamp: string): string {
            return String(notificationService.pruneAt(Number(timestamp)))
        }

        function presentationProof(): string {
            var rowsA = notificationService.toastsForOutput("output-a")
            var rowsB = notificationService.toastsForOutput("output-b")
            return JSON.stringify({
                outputA: rowsA.length,
                outputB: rowsB.length,
                overlap: rowsA.filter(function(left) {
                    return rowsB.some(function(right) { return right.key === left.key })
                }).length
            })
        }
    }
}
