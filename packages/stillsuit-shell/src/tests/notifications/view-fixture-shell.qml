import QtQuick
import Quickshell
import Quickshell.Io
import "src/services" as Services
import "src/plugins/builtin/notifications" as Notifications

ShellRoot {
    id: fixture

    property int toastViewCount: 0
    property int centerViewCount: 0
    property int widgetViewCount: 0
    property var fixtureTheme: ({})
    property bool themeReady: false
    property bool rowsSeeded: false
    property var toastViews: []
    property var centerViews: []
    property var capturedDeck: null
    property var capturedCard: null

    function descendants(node, predicate, found) {
        if (!node || found.seen.indexOf(node) !== -1) return found
        found.seen.push(node)
        if (predicate(node)) found.items.push(node)
        var children = node.children || []
        for (var index = 0; index < children.length; index++)
            descendants(children[index], predicate, found)
        return found
    }

    function decksOf(view) {
        var decks = []
        for (var index = 0; index < view.deckInstances.count; index++)
            decks.push(view.deckInstances.itemAt(index))
        return decks
    }

    function expandedCardsOf(deck) {
        return descendants(deck, function(node) {
            return node.snapshot !== undefined && node.dismissGesturesEnabled !== undefined
                && node.parent !== deck
        }, { seen: [], items: [] }).items
    }

    function firstOutputId() {
        return Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""
    }

    function toastRow(key, sourceKey, offsetMs) {
        var now = Date.now()
        return {
            key: key,
            originalId: 10,
            appName: sourceKey,
            summary: key,
            body: "",
            urgency: 1,
            actions: [],
            hints: ({}),
            timestamp: now + offsetMs,
            deadline: now + 60000,
            outputId: firstOutputId(),
            quietClass: "visible",
            sourceKey: sourceKey,
            sourceLabel: sourceKey,
            closeReason: "",
            read: false,
            readAt: 0
        }
    }

    function deckReport() {
        var view = toastViews.filter(function(candidate) {
            return candidate.outputId === firstOutputId()
        })[0]
        var decks = view ? decksOf(view) : []
        var tracked = fixture.capturedDeck
            ? decks.filter(function(deck) { return deck === fixture.capturedDeck })[0] : null
        var cards = tracked ? expandedCardsOf(tracked) : []
        return {
            deckKeys: decks.map(function(deck) { return deck.deck.key }),
            capturedDeckAlive: tracked !== null && tracked !== undefined,
            capturedRows: tracked ? tracked.rows.map(function(row) { return row.key }) : [],
            capturedRead: tracked ? tracked.rows.map(function(row) { return row.read === true }) : [],
            capturedSummaries: tracked ? tracked.rows.map(function(row) { return row.summary }) : [],
            expandedCards: cards.length,
            capturedCardAlive: fixture.capturedCard !== null
                && cards.some(function(card) { return card === fixture.capturedCard }),
            enteredAll: decks.every(function(deck) { return deck.entered === true })
        }
    }

    function frontCardOf(deck) {
        return descendants(deck, function(node) {
            return node.parent === deck && node.snapshot !== undefined
                && node.dismissGesturesEnabled !== undefined
        }, { seen: [], items: [] }).items[0] || null
    }

    function deckByKey(key) {
        var view = toastViews.filter(function(candidate) {
            return candidate.outputId === firstOutputId()
        })[0]
        return (view ? decksOf(view) : []).filter(function(deck) { return deck.deck.key === key })[0] || null
    }

    function swipeReport(sourceKey) {
        var deck = deckByKey(sourceKey)
        var card = deck ? frontCardOf(deck) : null
        return {
            deckAlive: deck !== null && deck === fixture.capturedDeck,
            frontKey: card ? card.snapshotKey : "",
            frontDragOffset: card ? card.dragOffset : -1,
            popups: notificationService.popups.map(function(row) { return row.key }),
            dismissed: notificationService.history.filter(function(row) {
                return row.closeReason === "dismissed"
            }).map(function(row) { return row.key })
        }
    }

    Timer {
        id: arrivalDuringSwipe
        interval: 30
        repeat: false
        onTriggered: notificationService.insertPopup(fixture.toastRow("new-arrival", "app:other", 2000))
    }

    function centerReport() {
        return fixture.centerViews.map(function(view) {
            return { outputId: view.outputId, presented: view.presented, rows: view.rows.length,
                sections: view.sections.length }
        })
    }

    FileView {
        path: Quickshell.env("STILLSUIT_NOTIFICATION_VIEW_THEME")
        printErrors: true
        onLoaded: {
            fixture.fixtureTheme = JSON.parse(text())
            fixture.themeReady = true
        }
    }

    QtObject {
        id: serviceFacade
        function get(pluginId) {
            return pluginId === "stillsuit.notifications" ? notificationService : null
        }
    }

    QtObject {
        id: fixtureContext
        property var settings: ({
            values: { claimNotificationBus: true },
            paths: { stateRoot: Quickshell.env("XDG_STATE_HOME") }
        })
        property var compositor: ({
            focusedOutputId: Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "",
            outputs: Quickshell.screens.map(function(screen) { return { id: screen.name } })
        })
        property var logger: ({
            warn: function(message) { console.warn(message) }
        })
        property var services: serviceFacade
        property var actions: ({
            surfaceToggle: function(pluginId, payloadJson) { return "ok" }
        })
        property var theme: fixture.fixtureTheme
    }

    Services.NotificationService {
        id: notificationService
        context: fixtureContext
    }

    Variants {
        model: fixture.themeReady ? Quickshell.screens : []
        delegate: Component {
            Notifications.NotificationToasts {
                id: toastView
                required property var modelData
                context: fixtureContext
                service: notificationService
                screen: modelData
                Component.onCompleted: {
                    fixture.toastViewCount += 1
                    fixture.toastViews = fixture.toastViews.concat([toastView])
                }
                Component.onDestruction: fixture.toastViewCount -= 1
            }
        }
    }

    Variants {
        model: fixture.themeReady ? Quickshell.screens : []
        delegate: Component {
            Notifications.NotificationCenter {
                id: centerView
                required property var modelData
                context: fixtureContext
                service: notificationService
                screen: modelData
                Component.onCompleted: {
                    fixture.centerViewCount += 1
                    fixture.centerViews = fixture.centerViews.concat([centerView])
                }
                Component.onDestruction: fixture.centerViewCount -= 1
            }
        }
    }

    Variants {
        model: fixture.themeReady ? Quickshell.screens : []
        delegate: Component {
            Notifications.Widget {
                required property var modelData
                context: fixtureContext
                service: notificationService
                outputId: modelData.name
                Component.onCompleted: fixture.widgetViewCount += 1
                Component.onDestruction: fixture.widgetViewCount -= 1
            }
        }
    }

    IpcHandler {
        target: "stillsuit-notification-view-fixture"
        function ready(): string {
            var screenCount = Quickshell.screens.length
            return fixture.themeReady && notificationService.ready && notificationService.serverActive
                && fixture.toastViewCount === screenCount
                && fixture.centerViewCount === screenCount
                && fixture.widgetViewCount === screenCount ? "ready" : "loading"
        }
        function seedRows(): string {
            var outputId = Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""
            var now = Date.now()
            notificationService.popups = [{
                key: "toast-row",
                originalId: 1,
                appName: "Fixture",
                summary: "Toast row",
                body: "Visible toast body",
                urgency: 1,
                actions: [],
                hints: ({}),
                timestamp: now,
                deadline: now + 60000,
                outputId: outputId,
                quietClass: "visible",
                sourceKey: "app:fixture",
                sourceLabel: "Fixture",
                closeReason: "",
                read: false,
                readAt: 0
            }]
            notificationService.history = [{
                key: "history-row",
                originalId: 2,
                appName: "Fixture",
                summary: "History row",
                body: "Visible history body",
                urgency: 1,
                actions: [],
                hints: ({}),
                timestamp: now - 1000,
                deadline: 0,
                outputId: outputId,
                quietClass: "visible",
                sourceKey: "app:fixture",
                sourceLabel: "Fixture",
                closeReason: "dismissed",
                read: false,
                readAt: 0
            }]
            notificationService.revision += 1
            notificationService.openCenter(outputId)
            notificationService.closeCenter(outputId)
            fixture.rowsSeeded = true
            return "ok"
        }
        function captureDeck(): string {
            var view = fixture.toastViews.filter(function(candidate) {
                return candidate.outputId === fixture.firstOutputId()
            })[0]
            var decks = view ? fixture.decksOf(view) : []
            fixture.capturedDeck = decks.length > 0 ? decks[0] : null
            fixture.capturedCard = fixture.capturedDeck
                ? fixture.expandedCardsOf(fixture.capturedDeck)[0] || null : null
            return JSON.stringify(fixture.deckReport())
        }
        function decks(): string {
            return JSON.stringify(fixture.deckReport())
        }
        function markToastsRead(): string {
            notificationService.markRowsRead(notificationService.popups.map(function(row) {
                return row.key
            }), Date.now())
            return JSON.stringify(fixture.deckReport())
        }
        function touchToast(key: string): string {
            notificationService.popups = notificationService.popups.map(function(row) {
                return row.key === key ? Object.assign({}, row, { summary: row.summary + " (updated)" }) : row
            })
            notificationService.revision += 1
            return JSON.stringify(fixture.deckReport())
        }
        function addToast(key: string, sourceKey: string): string {
            notificationService.insertPopup(fixture.toastRow(key, sourceKey, 1000))
            return JSON.stringify(fixture.deckReport())
        }
        function swipeWithArrival(sourceKey: string): string {
            var deck = fixture.deckByKey(sourceKey)
            var card = deck ? fixture.frontCardOf(deck) : null
            if (!card) return "unknown"
            fixture.capturedDeck = deck
            var swipedKey = card.snapshotKey
            card.dismissWithSlide(1)
            arrivalDuringSwipe.start()
            return swipedKey
        }
        function swipeState(sourceKey: string): string {
            return JSON.stringify(fixture.swipeReport(sourceKey))
        }
        function centers(): string {
            return JSON.stringify({ trackedCount: notificationService.trackedCount,
                views: fixture.centerReport() })
        }
        function openCenter(): string {
            notificationService.openCenter(fixture.firstOutputId())
            return JSON.stringify({ trackedCount: notificationService.trackedCount,
                views: fixture.centerReport() })
        }
        function closeCenter(): string {
            notificationService.closeCenter(fixture.firstOutputId())
            return JSON.stringify({ trackedCount: notificationService.trackedCount,
                views: fixture.centerReport() })
        }
        function topology(): string {
            var outputId = Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""
            return JSON.stringify({
                serviceInstances: 1,
                outputs: Quickshell.screens.length,
                toastViews: fixture.toastViewCount,
                centerViews: fixture.centerViewCount,
                widgetViews: fixture.widgetViewCount,
                rowsSeeded: fixture.rowsSeeded,
                centerRows: notificationService.centerRows().length,
                toastRows: outputId === "" ? 0
                    : notificationService.toastsForOutput(outputId).length
            })
        }
    }
}
