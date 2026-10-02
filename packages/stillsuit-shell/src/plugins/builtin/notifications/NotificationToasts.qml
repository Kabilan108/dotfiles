import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    required property var context
    required property var screen
    required property var service

    property string outputId: String(screen.name || "")
    readonly property var decks: service ? service.toastDecksForOutput(outputId) : []
    readonly property alias deckInstances: deckRepeater
    readonly property var decksByKey: {
        var index = {}
        for (var position = 0; position < decks.length; position++)
            index[decks[position].key] = decks[position]
        return index
    }

    // Keyed by source so a revision updates existing decks in place; only a
    // genuinely new source creates a delegate and plays the entry animation.
    ScriptModel {
        id: deckKeys
        values: root.decks.map(function(deck) { return deck.key })
    }

    PanelWindow {
        screen: root.screen
        visible: deckRepeater.count > 0
        anchors {
            top: true
            right: true
        }
        margins {
            top: root.context.theme.metrics.barHeight + root.context.theme.metrics.spaceUnit * 2
            right: root.context.theme.metrics.spaceUnit * 2
        }
        exclusiveZone: 0
        aboveWindows: true
        focusable: false
        color: "transparent"
        implicitWidth: toastColumn.implicitWidth
        height: Math.max(1, root.screen.height
            - root.context.theme.metrics.barHeight
            - root.context.theme.metrics.spaceUnit * 4)
        mask: Region { item: toastColumn }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "stillsuit.notifications"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        ColumnLayout {
            id: toastColumn
            anchors {
                top: parent.top
                right: parent.right
            }
            spacing: root.context.theme.metrics.spaceUnit * 2

            Repeater {
                id: deckRepeater
                model: deckKeys

                NotificationDeck {
                    required property string modelData
                    context: root.context
                    service: root.service
                    deck: root.decksByKey[modelData] || ({ key: modelData, label: "", rows: [] })
                }
            }
        }

    }
}
