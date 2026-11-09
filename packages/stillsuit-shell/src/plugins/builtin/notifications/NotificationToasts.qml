import QtQuick
import Quickshell
import Quickshell.Wayland
import "Motion.js" as Motion

Scope {
    id: root

    required property var context
    required property var screen
    required property var service

    property string outputId: String(screen.name || "")
    readonly property var decks: service ? service.toastDecksForOutput(outputId) : []
    readonly property alias deckInstances: deckRepeater
    readonly property real cardWidth: context.theme.metrics.panelWidth
    readonly property real edgeGap: context.theme.metrics.spaceUnit * 2
    readonly property real spacing: context.theme.metrics.spaceUnit * 2
    // Room left of the cards for a leftward swipe and the cards' shadows.
    readonly property real slack: 64

    // Decks on screen, including ones whose last cards are still leaving,
    // and the last data each had.
    property var rendered: []
    property var deckCache: ({})
    property real extent: 0
    // False from the moment the overlay maps until it has presented a frame,
    // so an entrance starts on screen instead of during the map.
    property bool surfaceReady: false
    readonly property bool overlayVisible: rendered.length > 0

    onOverlayVisibleChanged: if (!overlayVisible) surfaceReady = false

    function syncDecks() {
        var cache = Object.assign({}, deckCache)
        for (var index = 0; index < decks.length; index++) cache[decks[index].key] = decks[index]
        deckCache = cache
        var next = Motion.merge(rendered, decks.map(function(deck) { return deck.key }))
        if (!Motion.sameEntries(next, rendered)) rendered = next
        Qt.callLater(root.relayout)
    }

    function dropDeck(key) {
        rendered = Motion.drop(rendered, key)
        if (rendered.every(function(entry) { return entry.key !== key })) {
            var cache = Object.assign({}, deckCache)
            delete cache[key]
            deckCache = cache
        }
        Qt.callLater(root.relayout)
    }

    function isExiting(key) {
        for (var index = 0; index < rendered.length; index++)
            if (rendered[index].key === key) return rendered[index].exiting
        return true
    }

    function deckItem(key) {
        for (var index = 0; index < deckRepeater.count; index++) {
            var item = deckRepeater.itemAt(index)
            if (item && item.deckKey === key) return item
        }
        return null
    }

    // Live decks stack top-down; a leaving deck keeps its place and leaves
    // the flow, so the ones below move up while its cards exit.
    function relayout() {
        var y = 0
        for (var index = 0; index < rendered.length; index++) {
            var entry = rendered[index]
            var item = deckItem(entry.key)
            if (!item || entry.exiting) continue
            item.targetY = y
            item.positioned = true
            y += item.layoutHeight + spacing
        }
        updateExtent()
    }

    function updateExtent() {
        var bottom = 0
        for (var index = 0; index < deckRepeater.count; index++) {
            var item = deckRepeater.itemAt(index)
            if (item) bottom = Math.max(bottom, item.y + item.height)
        }
        extent = bottom
    }

    onDecksChanged: syncDecks()
    Component.onCompleted: syncDecks()

    ScriptModel {
        id: deckKeys
        values: root.rendered.map(function(entry) { return entry.key })
    }

    PanelWindow {
        screen: root.screen
        visible: root.overlayVisible
        anchors {
            top: true
            right: true
        }
        margins {
            top: root.context.theme.metrics.barHeight + root.context.theme.metrics.spaceUnit * 2
            right: 0
        }
        exclusiveZone: 0
        aboveWindows: true
        focusable: false
        color: "transparent"
        implicitWidth: root.slack + root.cardWidth + root.edgeGap
        implicitHeight: Math.max(1, root.screen.height
            - root.context.theme.metrics.barHeight
            - root.context.theme.metrics.spaceUnit * 4)
        mask: Region { item: inputArea }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "stillsuit.notifications"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // Only the cards take the pointer; everywhere else clicks pass through.
        Item {
            id: inputArea
            x: root.slack
            width: root.cardWidth
            height: Math.max(1, root.extent)
        }

        Connections {
            target: root.overlayVisible && !root.surfaceReady ? stack.Window.window : null
            function onFrameSwapped() { root.surfaceReady = true }
        }

        Item {
            id: stack
            x: root.slack
            width: root.cardWidth
            height: parent.height

            Repeater {
                id: deckRepeater
                model: deckKeys

                NotificationDeck {
                    required property string modelData
                    surfaceReady: root.surfaceReady
                    context: root.context
                    service: root.service
                    deck: root.deckCache[modelData] || ({ key: modelData, label: "", rows: [] })
                    exiting: root.isExiting(modelData)
                    onLayoutHeightChanged: Qt.callLater(root.relayout)
                    onYChanged: root.updateExtent()
                    onHeightChanged: root.updateExtent()
                    onDrained: root.dropDeck(modelData)
                }
            }
        }
    }
}
