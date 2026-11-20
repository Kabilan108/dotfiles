import QtQuick
import Quickshell
import Quickshell.Io
import "src/services" as Services
import "src/plugins/builtin/notifications" as Notifications

ShellRoot {
    id: fixture

    property int toastViewCount: 0
    property int widgetViewCount: 0
    property var fixtureTheme: ({})
    property bool themeReady: false
    property var toastViews: []
    property var widgets: []
    property var captured: ({})
    property var openedUrls: []
    property var warnings: []
    property string openStatus: "ok"

    function linkButton(item) {
        if (item.label === "Open link" && typeof item.clicked === "function")
            return item
        for (var index = 0; index < item.children.length; index++) {
            var found = linkButton(item.children[index])
            if (found)
                return found
        }
        return null
    }

    function checkLink() {
        openedUrls = []
        warnings = []
        var row = toastRow("link", "app:link", 0)
        row.link = {
            url: "https://example.com/meeting?q=a%20b#join",
            label: "Open link"
        }
        var component = Qt.createComponent("src/plugins/builtin/notifications/NotificationCard.qml",
                                           Component.PreferSynchronous)
        if (component.status !== Component.Ready)
            return component.errorString()
        var card = component.createObject(null, {
                                              context: fixtureContext,
                                              service: notificationService,
                                              snapshot: row
                                          })
        if (!card)
            return "link card construction failed"
        try {
            var button = linkButton(card)
            if (!button)
                return "link button missing"
            openStatus = "ok"
            button.clicked()
            if (openedUrls.length !== 1 || openedUrls[0] !== row.link.url || warnings.length !== 0)
                return "link button did not submit the exact URL to the host"
            openStatus = "unavailable"
            button.clicked()
            if (warnings.length !== 1 || warnings[0]
                    !== "Open notification link returned unavailable")
                return "host launch failure was not reported"
            card.snapshot = toastRow("no-link", "app:link", 0)
            button.clicked()
            if (openedUrls.length !== 2)
                return "missing link reached the host"
            return "ok"
        } finally {
            card.destroy()
            openStatus = "ok"
        }
    }

    function firstOutputId() {
        return Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""
    }

    function firstView() {
        return toastViews.filter(function (view) {
            return view.outputId === firstOutputId()
        })[0] || null
    }

    function decksOf(view) {
        var decks = []
        for (var index = 0; view && index < view.deckInstances.count; index++)
            decks.push(view.deckInstances.itemAt(index))
        return decks.filter(function (deck) {
            return deck !== null
        })
    }

    function slotsOf(deck) {
        var slots = []
        for (var index = 0; deck && index < deck.slotInstances.count; index++)
            slots.push(deck.slotInstances.itemAt(index))
        return slots.filter(function (slot) {
            return slot !== null
        })
    }

    function deckByKey(key) {
        return decksOf(firstView()).filter(function (deck) {
            return deck.deckKey === key
        })[0] || null
    }

    function slotByKey(key) {
        var decks = decksOf(firstView())
        for (var index = 0; index < decks.length; index++) {
            var slot = slotsOf(decks[index]).filter(function (candidate) {
                return candidate.rowKey === key
            })[0]
            if (slot)
                return slot
        }
        return null
    }

    function toastRow(key, sourceKey, offsetMs) {
        var now = Date.now()
        return {
            key: key,
            originalId: 10,
            appName: sourceKey,
            summary: key,
            body: "Body for " + key,
            urgency: 1,
            actions: [],
            hints: ({}),
            timestamp: now + offsetMs,
            deadline: now + 60000,
            outputId: firstOutputId(),
            quietClass: "visible",
            sourceKey: sourceKey,
            sourceLabel: sourceKey,
            context: "",
            link: null,
            heldReason: ""
        }
    }

    function report() {
        var view = firstView()
        return {
            rendered: view ? view.rendered : [],
            extent: view ? view.extent : 0,
            decks: decksOf(view).map(function (deck) {
                return {
                    key: deck.deckKey,
                    exiting: deck.exiting,
                    y: Math.round(deck.y),
                    targetY: Math.round(deck.targetY),
                    layoutHeight: Math.round(deck.layoutHeight),
                    expanded: deck.expanded,
                    slots: slotsOf(deck).map(function (slot) {
                        return {
                            key: slot.rowKey,
                            exiting: slot.exiting,
                            presence: Math.round(slot.presence * 1000) / 1000,
                            offsetX: Math.round(slot.offsetX),
                            y: Math.round(slot.y),
                            alive: fixture.captured[slot.rowKey] === slot
                        }
                    })
                }
            }),
            quiet: notificationService.quiet,
            popups: notificationService.popups.map(function (row) {
                return row.key
            }),
            held: notificationService.held.map(function (row) {
                return row.key
            })
        }
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
                                    values: {
                                        claimNotificationBus: true
                                    },
                                    paths: {
                                        stateRoot: Quickshell.env("XDG_STATE_HOME")
                                    }
                                })
        property var compositor: ({
                                      focusedOutputId: Quickshell.screens.length > 0
                                                       ? Quickshell.screens[0].name : "",
                                      outputs: Quickshell.screens.map(function (screen) {
                                          return {
                                              id: screen.name
                                          }
                                      })
                                  })
        property var logger: ({
                                  warn: function (message) {
                                      fixture.warnings = fixture.warnings.concat([message])
                                      console.warn(message)
                                  }
                              })
        property var services: serviceFacade
        property var actions: ({
                                   openUrl: function (url) {
                                       fixture.openedUrls = fixture.openedUrls.concat([url])
                                       return fixture.openStatus
                                   },
                                   surfaceToggle: function (pluginId, payloadJson) {
                                       return "ok"
                                   }
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
            Notifications.Widget {
                id: widget
                required property var modelData
                context: fixtureContext
                service: notificationService
                outputId: modelData.name
                Component.onCompleted: {
                    fixture.widgetViewCount += 1
                    fixture.widgets = fixture.widgets.concat([widget])
                }
                Component.onDestruction: fixture.widgetViewCount -= 1
            }
        }
    }

    IpcHandler {
        target: "stillsuit-notification-view-fixture"
        function linkProof(): string {
            return fixture.checkLink()
        }
        function ready(): string {
            var screenCount = Quickshell.screens.length
            return fixture.themeReady && notificationService.ready
                    && notificationService.serverActive && fixture.toastViewCount === screenCount
                    && fixture.widgetViewCount === screenCount ? "ready" : "loading"
        }
        function topology(): string {
            return JSON.stringify({
                                      outputs: Quickshell.screens.length,
                                      toastViews: fixture.toastViewCount,
                                      widgetViews: fixture.widgetViewCount
                                  })
        }
        function add(key: string, sourceKey: string): string {
            notificationService.insertPopup(fixture.toastRow(key, sourceKey, 0))
            return JSON.stringify(fixture.report())
        }
        function touch(key: string): string {
            notificationService.popups = notificationService.popups.map(function (row) {
                return row.key === key ? Object.assign({}, row, {
                                                           summary: row.summary + " (updated)"
                                                       }) : row
            })
            notificationService.revision += 1
            return JSON.stringify(fixture.report())
        }
        function capture(): string {
            var decks = fixture.decksOf(fixture.firstView())
            var next = {}
            for (var index = 0; index < decks.length; index++) {
                next["deck:" + decks[index].deckKey] = decks[index]
                var slots = fixture.slotsOf(decks[index])
                for (var slotIndex = 0; slotIndex < slots.length; slotIndex++)
                    next[slots[slotIndex].rowKey] = slots[slotIndex]
            }
            fixture.captured = next
            return JSON.stringify(fixture.report())
        }
        function decksAlive(): string {
            return JSON.stringify(fixture.decksOf(fixture.firstView()).map(function (deck) {
                return {
                    key: deck.deckKey,
                    alive: fixture.captured["deck:" + deck.deckKey] === deck
                }
            }))
        }
        function dismiss(key: string): string {
            notificationService.dismiss(key)
            return JSON.stringify(fixture.report())
        }
        function swipe(key: string): string {
            var slot = fixture.slotByKey(key)
            if (!slot)
                return "unknown"
            slot.card.dragOffset = 120
            slot.card.swipeEnded(true, 1, 1500)
            return JSON.stringify(fixture.report())
        }
        function snapBack(key: string): string {
            var slot = fixture.slotByKey(key)
            if (!slot)
                return "unknown"
            slot.card.dragOffset = 40
            slot.card.swipeEnded(false, 1, 0)
            return JSON.stringify(fixture.report())
        }
        function expand(sourceKey: string): string {
            notificationService.beginDeckInteraction(sourceKey)
            return JSON.stringify(fixture.report())
        }
        function collapse(): string {
            notificationService.endDeckInteraction()
            return JSON.stringify(fixture.report())
        }
        function clickWidget(): string {
            fixture.widgets[0].clicked()
            return JSON.stringify({
                                      quiet: notificationService.quiet,
                                      icon: fixture.widgets[0].iconName,
                                      label: fixture.widgets[0].label
                                  })
        }
        function state(): string {
            return JSON.stringify(fixture.report())
        }
    }
}
