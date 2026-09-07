import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var context
    required property var service
    required property var deck

    readonly property bool expanded: service && service.activeDeckKey === deck.key
    readonly property var rows: deck && deck.rows ? deck.rows : []
    readonly property int peekCount: Math.min(2, Math.max(0, rows.length - 1))
    readonly property bool reducedMotion: context.settings
        && context.settings.values
        && context.settings.values.reducedMotion === true
    readonly property int motionDuration: reducedMotion ? 0 : context.theme.motion.fast
    property bool entered: false

    function syncHovered() {
        var hovered = frontCard.hovered
        for (var index = 0; index < expandedCards.count && !hovered; index++) {
            var card = expandedCards.itemAt(index)
            hovered = card && card.hovered
        }
        service.setDeckHovered(deck.key, hovered)
    }

    implicitWidth: context.theme.metrics.panelWidth
    implicitHeight: expanded ? frontCard.implicitHeight
        + context.theme.metrics.spaceUnit * 2 + expandedColumn.implicitHeight
        : frontCard.implicitHeight + peekCount * 10
    opacity: reducedMotion || entered ? 1 : 0
    clip: true

    Behavior on opacity {
        NumberAnimation {
            duration: root.motionDuration
            easing.type: Easing.OutCubic
        }
    }

    transform: Translate {
        x: root.reducedMotion || root.entered
            ? 0 : root.context.theme.motion.distanceMedium

        Behavior on x {
            NumberAnimation {
                duration: root.motionDuration
                easing.type: Easing.OutCubic
            }
        }
    }

    Repeater {
        model: root.peekCount
        Rectangle {
            required property int index
            x: (index + 1) * 4
            y: (index + 1) * 10
            width: root.width - (index + 1) * 8
            height: frontCard.implicitHeight
            radius: root.context.theme.metrics.radiusSmall
            color: root.context.theme.component.control.background
            border.width: 1
            border.color: root.context.theme.component.control.outline
            opacity: root.expanded ? 0 : 0.78 - index * 0.16

            Behavior on opacity {
                NumberAnimation {
                    duration: root.motionDuration
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    NotificationCard {
        id: frontCard
        visible: root.rows.length > 0
        width: root.width
        context: root.context
        service: root.service
        snapshot: root.rows.length > 0 ? root.rows[0] : ({})
        z: 10
        onHoveredChanged: Qt.callLater(root.syncHovered)

    }

    Rectangle {
        visible: opacity > 0 && root.rows.length > 1
        anchors {
            right: parent.right
            top: parent.top
            margins: 8
        }
        width: countText.implicitWidth + 12
        height: countText.implicitHeight + 6
        radius: height / 2
        color: root.context.theme.component.control.active
        opacity: root.expanded ? 0 : 1
        z: 20


        Behavior on opacity {
            NumberAnimation {
                duration: root.motionDuration
                easing.type: Easing.OutCubic
            }
        }
        Text {
            id: countText
            anchors.centerIn: parent
            text: String(root.rows.length)
            color: root.context.theme.component.control.onActive
        }
    }

    ColumnLayout {
        id: expandedColumn
        visible: true
        enabled: root.expanded
        opacity: root.expanded ? 1 : 0
        y: frontCard.implicitHeight + root.context.theme.metrics.spaceUnit * 2
        width: root.width
        spacing: root.context.theme.metrics.spaceUnit * 2

        transform: Translate {
            y: root.expanded ? 0 : -root.context.theme.motion.distanceMedium

            Behavior on y {
                NumberAnimation {
                    duration: root.motionDuration
                    easing.type: Easing.OutCubic
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: root.motionDuration
                easing.type: Easing.OutCubic
            }
        }

        Repeater {
            id: expandedCards
            model: root.rows.slice(1)
            NotificationCard {
                required property var modelData
                Layout.fillWidth: true
                context: root.context
                service: root.service
                snapshot: modelData
                onHoveredChanged: Qt.callLater(root.syncHovered)
            }
        }
    }

    Component.onCompleted: Qt.callLater(function() { root.entered = true })
}
