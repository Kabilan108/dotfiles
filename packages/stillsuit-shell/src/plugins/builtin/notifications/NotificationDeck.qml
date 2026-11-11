import QtQuick
import Quickshell
import "Motion.js" as Motion

// The toasts from one source. Collapsed, the newest card sits in front of up
// to two narrower cards peeking out below it; hovered, they spread into a
// list. Every card keeps its own slot while it leaves, so the others reflow
// at once and the leaving one finishes its exit where it was.
Item {
    id: root

    required property var context
    required property var service
    required property var deck
    property bool exiting: false
    property real targetY: 0
    property bool positioned: false
    property bool surfaceReady: true

    readonly property string deckKey: String((deck || {}).key || "")
    readonly property bool reducedMotion: context.settings && context.settings.values
                                          && context.settings.values.reducedMotion === true
    readonly property bool expanded: !exiting && service && service.activeDeckKey === deckKey
    readonly property var rows: !exiting && deck && Array.isArray(deck.rows) ? deck.rows : []
    readonly property real gap: context.theme.metrics.spaceUnit * 2
    readonly property real peek: 10
    readonly property int maxPeeks: 2

    // Rows on screen, newest first, including ones still leaving.
    property var rendered: []
    property var rowCache: ({})
    property var naturalHeights: ({})
    readonly property var liveKeys: rendered.filter(function (entry) {
        return !entry.exiting
    }).map(function (entry) {
        return entry.key
    })
    readonly property real frontHeight: liveKeys.length > 0 ? heightOf(liveKeys[0]) : 0
    readonly property real layoutHeight: {
        if (liveKeys.length === 0)
            return 0
        if (!expanded)
            return frontHeight + Math.min(maxPeeks, liveKeys.length - 1) * peek
        var total = 0
        for (var index = 0; index < liveKeys.length; index++)
            total += heightOf(liveKeys[index])
        return total + (liveKeys.length - 1) * gap
    }

    readonly property alias slotInstances: slots

    signal drained

    width: context.theme.metrics.panelWidth
    height: heightSpring.value
    y: positioned ? ySpring.value : targetY

    function heightOf(key) {
        var height = Number(naturalHeights[key] || 0)
        return height > 0 ? height : 72
    }

    function reportHeight(key, height) {
        if (Number(naturalHeights[key] || 0) === height)
            return
        var next = Object.assign({}, naturalHeights)
        next[key] = height
        naturalHeights = next
    }

    function syncRows() {
        var cache = Object.assign({}, rowCache)
        for (var index = 0; index < rows.length; index++)
            cache[rows[index].key] = rows[index]
        rowCache = cache
        var next = Motion.merge(rendered, rows.map(function (row) {
            return row.key
        }))
        if (!Motion.sameEntries(next, rendered))
            rendered = next
        if (exiting && rendered.length === 0)
            Qt.callLater(root.drained)
    }

    function dropRow(key) {
        var next = Motion.drop(rendered, key)
        if (next.length === rendered.length)
            return
        rendered = next
        var cache = Object.assign({}, rowCache)
        var heights = Object.assign({}, naturalHeights)
        if (rendered.every(function (entry) {
            return entry.key !== key
        })) {
            delete cache[key]
            delete heights[key]
        }
        rowCache = cache
        naturalHeights = heights
        if (exiting && rendered.length === 0)
            Qt.callLater(root.drained)
    }

    function isExiting(key) {
        for (var index = 0; index < rendered.length; index++)
            if (rendered[index].key === key)
                return rendered[index].exiting
        return true
    }

    // Where a live row sits, collapsed or expanded.
    function placement(key) {
        var index = liveKeys.indexOf(key)
        if (index < 0)
            return null
        if (expanded) {
            var y = 0
            for (var before = 0; before < index; before++)
                y += heightOf(liveKeys[before]) + gap
            return {
                index: index,
                y: y,
                scale: 1,
                opacity: 1,
                content: 1,
                height: heightOf(key)
            }
        }
        var depth = Math.min(index, maxPeeks)
        return {
            index: index,
            y: depth * peek,
            scale: 1 - depth * 0.04,
            opacity: index === 0 ? 1 : index <= maxPeeks ? 0.9 - index * 0.2 : 0,
            content: index === 0 ? 1 : 0,
            height: index === 0 ? heightOf(key) : frontHeight
        }
    }

    function syncHovered() {
        var hovered = false
        for (var index = 0; index < slots.count && !hovered; index++) {
            var slot = slots.itemAt(index)
            hovered = slot && !slot.exiting && slot.card.hovered
        }
        service.setDeckHovered(deckKey, hovered)
    }

    onRowsChanged: syncRows()
    onExitingChanged: syncRows()
    Component.onCompleted: syncRows()

    SpringValue {
        id: ySpring
        spring: Motion.LAYOUT
        target: root.targetY
        instant: root.reducedMotion || !root.positioned
    }

    SpringValue {
        id: heightSpring
        spring: Motion.LAYOUT
        target: root.layoutHeight
        instant: root.reducedMotion
    }

    ScriptModel {
        id: renderedKeys
        values: root.rendered.map(function (entry) {
            return entry.key
        })
    }

    Repeater {
        id: slots
        model: renderedKeys

        Item {
            id: slot

            required property string modelData
            readonly property string rowKey: modelData
            readonly property var snapshot: root.rowCache[rowKey] || ({
                                                                          key: rowKey
                                                                      })
            readonly property bool exiting: root.isExiting(rowKey)
            readonly property var place: root.placement(rowKey)
            property var lastPlace: ({
                                         index: 0,
                                         y: 0,
                                         scale: 1,
                                         opacity: 1,
                                         content: 1,
                                         height: 72
                                     })
            readonly property var layout: place || lastPlace
            property real exitDirection: 1
            property var xMotion: Motion.ENTER
            readonly property real offsetX: card.dragging ? card.dragOffset : xSpring.value
            // Until it has mostly faded in, a new card takes its measured
            // height at once instead of growing into it.
            readonly property bool fresh: !exiting && appear.value < 0.3
            readonly property real presence: appear.value
            property alias card: card

            width: root.width
            height: heightSpring.value
            y: ySpring.value
            z: exiting ? 200 : 100 - layout.index
            opacity: opacitySpring.value * appear.value * (1 - Math.min(Math.abs(offsetX) / Math.max(
                                                                            width, 1), 0.48))
            transformOrigin: Item.Bottom
            scale: scaleSpring.value * (exiting ? 1 : Motion.ENTER_SCALE + (1 - Motion.ENTER_SCALE)
                                                  * appear.value)
            enabled: !exiting && (layout.index === 0 || root.expanded)

            // Leaving rows keep the place they last had.
            onPlaceChanged: if (place)
                                lastPlace = place

            transform: Translate {
                x: slot.offsetX
            }

            onExitingChanged: Qt.callLater(root.syncHovered)

            SpringValue {
                id: appear
                spring: slot.exiting ? Motion.EXIT : Motion.ENTER
                from: 0
                target: slot.exiting ? 0 : 1
                epsilon: 0.002
                instant: root.reducedMotion
                hold: !root.surfaceReady
                onSettled: if (slot.exiting && value === 0)
                               root.dropRow(slot.rowKey)
            }

            SpringValue {
                id: xSpring
                spring: slot.exiting ? Motion.EXIT : slot.xMotion
                from: Motion.ENTER_OFFSET
                target: slot.exiting ? slot.exitDirection * (slot.width + 56) : 0
                instant: root.reducedMotion
                hold: !root.surfaceReady
            }

            SpringValue {
                id: ySpring
                spring: Motion.LAYOUT
                target: slot.layout.y
                instant: root.reducedMotion
            }

            SpringValue {
                id: scaleSpring
                spring: Motion.LAYOUT
                target: slot.layout.scale
                epsilon: 0.001
                instant: root.reducedMotion
            }

            SpringValue {
                id: opacitySpring
                spring: Motion.LAYOUT
                target: slot.layout.opacity
                epsilon: 0.002
                instant: root.reducedMotion
            }

            SpringValue {
                id: contentSpring
                spring: Motion.LAYOUT
                target: slot.layout.content
                epsilon: 0.002
                instant: root.reducedMotion
            }

            SpringValue {
                id: heightSpring
                spring: Motion.LAYOUT
                target: slot.layout.height
                instant: root.reducedMotion || slot.fresh
            }

            NotificationCard {
                id: card
                width: slot.width
                height: slot.height
                context: root.context
                service: root.service
                snapshot: slot.snapshot
                interactive: !slot.exiting
                contentOpacity: contentSpring.value
                onImplicitHeightChanged: root.reportHeight(slot.rowKey, implicitHeight)
                onHoveredChanged: Qt.callLater(root.syncHovered)
                onSwipeEnded: (dismissed, direction, velocity) => {
                    xSpring.jump(card.dragOffset)
                    xSpring.velocity = velocity
                    card.dragOffset = 0
                    if (dismissed) {
                        slot.exitDirection = direction
                        root.service.dismiss(slot.rowKey)
                    } else {
                        slot.xMotion = Motion.SNAP
                        xSpring.retarget()
                    }
                }
                Component.onCompleted: root.reportHeight(slot.rowKey, implicitHeight)
            }
        }
    }

    // How many cards wait behind the front one.
    Rectangle {
        readonly property int count: root.liveKeys.length
        visible: countFade.value > 0.01
        opacity: countFade.value
        anchors {
            right: parent.right
            rightMargin: 14
        }
        y: Math.max(0, root.frontHeight + Math.min(root.maxPeeks, Math.max(0, count - 1))
                    * root.peek - height / 2)
        z: 300
        width: countText.implicitWidth + 12
        height: countText.implicitHeight + 6
        radius: height / 2
        color: root.context.theme.component.control.active

        Text {
            id: countText
            anchors.centerIn: parent
            text: String(parent.count)
            color: root.context.theme.component.control.onActive
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }

        SpringValue {
            id: countFade
            spring: Motion.ENTER
            target: parent.count > 1 && !root.expanded ? 1 : 0
            epsilon: 0.002
            instant: root.reducedMotion
        }
    }
}
