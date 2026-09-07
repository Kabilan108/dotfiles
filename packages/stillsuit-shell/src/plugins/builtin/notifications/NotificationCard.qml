import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../ui" as Ui

Ui.ShellSurface {
    id: root

    required property var context
    required property var service
    required property var snapshot
    property bool inline: false
    property string timeText: ""
    property bool showOverflow: false
    property bool dismissGesturesEnabled: true
    property real dragOffset: 0

    theme: context.theme
    readonly property var actions: Array.isArray(snapshot.actions) ? snapshot.actions : []
    readonly property var primaryActions: actions.filter(function(action) {
        return !root.isSettingsAction(action)
    }).slice(0, 2)
    readonly property var overflowActions: actions.filter(function(action, index) {
        return root.isSettingsAction(action) || actions.filter(function(candidate) {
            return !root.isSettingsAction(candidate)
        }).indexOf(action) >= 2
    })
    readonly property var defaultAction: actions.find(function(action) {
        return String(action.identifier || "") === "default"
    })
    readonly property string actionState: service ? service.actionState(snapshot.key) : "expired"
    readonly property string stateRole: service ? service.viewState(snapshot) : "info"
    readonly property color stateColor: theme.component.notification[stateRole]
    readonly property bool reducedMotion: context.settings
        && context.settings.values
        && context.settings.values.reducedMotion === true
    readonly property int fastMotionDuration: reducedMotion ? 0 : theme.motion.fast
    readonly property int dismissMotionDuration: reducedMotion ? 0 : theme.motion.normal
    readonly property real dismissThreshold: Math.min(width * 0.25, 80)
    readonly property real flickVelocity: 420
    readonly property bool hovered: hoverMouse.containsMouse

    kind: "notification"
    implicitWidth: theme.metrics.panelWidth - theme.metrics.panelPadding * 2
    implicitHeight: contentColumn.implicitHeight + 24
    opacity: 1 - Math.min(Math.abs(dragOffset) / Math.max(width, 1), 0.48)

    transform: Translate {
        x: root.dragOffset
    }

    function cleanBody(value) {
        return String(value || "").replace(/<img[^>]*>/gi, "").trim()
    }

    function isSettingsAction(action) {
        var identifier = String((action || {}).identifier || "").trim().toLowerCase()
        var label = String((action || {}).text || "").trim().toLowerCase()
        return identifier === "settings" || label === "settings"
    }

    function iconForState(state) {
        if (state === "success") return "success"
        if (state === "warning") return "warning"
        if (state === "danger") return "danger"
        if (state === "info") return "info"
        return "notifications"
    }

    function withAlpha(value, alpha) {
        var parsed = Qt.color(value)
        return Qt.rgba(parsed.r, parsed.g, parsed.b, Math.max(0, Math.min(1, alpha)))
    }

    function dismissCard() {
        if (!root.service || !root.snapshot.key) return
        if (root.inline)
            root.service.deleteHistory(root.snapshot.key)
        else
            root.service.dismiss(root.snapshot.key)
    }

    function dismissWithSlide(direction) {
        if (!root.dismissGesturesEnabled || slideAwayAnimation.running) return
        slideAwayAnimation.targetOffset = direction * (root.width + 56)
        slideAwayAnimation.start()
    }

    function snapBack() {
        snapBackAnimation.stop()
        snapBackAnimation.from = root.dragOffset
        snapBackAnimation.start()
    }

    NumberAnimation {
        id: snapBackAnimation
        target: root
        property: "dragOffset"
        to: 0
        duration: root.fastMotionDuration
        easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        id: slideAwayAnimation
        property real targetOffset: 0

        NumberAnimation {
            target: root
            property: "dragOffset"
            to: slideAwayAnimation.targetOffset
            duration: root.dismissMotionDuration
            easing.type: Easing.OutCubic
        }

        ScriptAction {
            script: root.dismissCard()
        }
    }

    MouseArea {
        id: gestureMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: root.dismissGesturesEnabled ? Qt.LeftButton : Qt.NoButton
        cursorShape: root.actionState === "available" && root.defaultAction !== undefined
            ? Qt.PointingHandCursor
            : Qt.ArrowCursor
        preventStealing: dragging
        property real pressX: 0
        property real pressY: 0
        property bool dragging: false
        property bool gestureConsumed: false
        property real lastX: 0
        property real lastT: 0
        property real velocity: 0

        onPressed: mouse => {
            snapBackAnimation.stop()
            slideAwayAnimation.stop()
            pressX = mouse.x
            pressY = mouse.y
            lastX = mouse.x
            lastT = Date.now()
            velocity = 0
            dragging = false
            gestureConsumed = false
        }

        onPositionChanged: mouse => {
            if (!pressed || !root.dismissGesturesEnabled) return

            var dx = mouse.x - pressX
            var dy = mouse.y - pressY
            if (!dragging && Math.abs(dx) > 6 && Math.abs(dx) > Math.abs(dy) * 1.2) {
                dragging = true
                gestureConsumed = true
                lastX = mouse.x
                lastT = Date.now()
            }
            if (dragging) {
                var now = Date.now()
                var dt = now - lastT
                if (dt > 0) {
                    var instant = (mouse.x - lastX) / dt * 1000
                    velocity = velocity * 0.6 + instant * 0.4
                    lastX = mouse.x
                    lastT = now
                }
                root.dragOffset = dx
            }
        }

        onReleased: {
            if (!dragging) return

            var direction = root.dragOffset < 0 ? -1 : 1
            var flicked = Math.abs(velocity) >= root.flickVelocity
                && ((velocity < 0) === (root.dragOffset < 0))
            if (flicked || Math.abs(root.dragOffset) >= root.dismissThreshold)
                root.dismissWithSlide(direction)
            else
                root.snapBack()
            dragging = false
        }

        onCanceled: {
            if (dragging) root.snapBack()
            dragging = false
        }

        onClicked: {
            if (!gestureConsumed && root.actionState === "available"
                    && root.defaultAction !== undefined)
                root.service.invokeAction(root.snapshot.key, "default")
        }
    }

    ColumnLayout {
        id: contentColumn

        anchors {
            fill: parent
            margins: 12
        }
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                Layout.alignment: Qt.AlignTop
                radius: root.theme.metrics.radiusSmall
                color: root.withAlpha(root.stateColor, 0.16)

                Ui.ShellIcon {
                    anchors.centerIn: parent
                    theme: root.theme
                    name: root.iconForState(root.stateRole)
                    color: root.stateColor
                    accessibleName: root.stateRole + " notification"
                    source: root.service ? root.service.iconForSnapshot(root.snapshot) : ""
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Ui.ShellText {
                    Layout.fillWidth: true
                    theme: root.theme
                    text: root.snapshot.sourceLabel || root.snapshot.appName || "Notification"
                    sizeRole: "caption"
                    color: root.stateColor
                    elide: Text.ElideRight
                }

                Ui.ShellText {
                    Layout.fillWidth: true
                    theme: root.theme
                    text: root.snapshot.summary || "Notification"
                    sizeRole: "label"
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }

            Ui.ShellText {
                visible: root.timeText !== ""
                theme: root.theme
                text: root.timeText
                sizeRole: "caption"
                role: "muted"
                monospace: true
            }

            Ui.ShellButton {
                theme: root.theme
                label: ""
                iconName: root.inline ? "delete" : "close"
                compact: true
                ghost: true
                destructive: root.inline
                accessibleName: root.inline ? "Delete notification" : "Dismiss notification"
                onClicked: {
                    if (root.inline)
                        root.service.deleteHistory(root.snapshot.key)
                    else
                        root.service.dismiss(root.snapshot.key)
                }
            }
        }

        Ui.ShellText {
            Layout.fillWidth: true
            theme: root.theme
            text: root.cleanBody(root.snapshot.body)
            visible: text !== ""
            role: "secondary"
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: root.inline ? 5 : 3
            elide: Text.ElideRight
        }

        Ui.ShellText {
            visible: root.inline && String(root.snapshot.heldReason || "") !== ""
            Layout.fillWidth: true
            theme: root.theme
            text: root.snapshot.heldReason === "global-snooze"
                ? "Held during global quiet"
                : "Held while this source was snoozed"
            sizeRole: "caption"
            role: "muted"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: root.snapshot.link !== null
                || ((root.primaryActions.length > 0 || root.overflowActions.length > 0)
                    && root.actionState === "available")

            Item { Layout.fillWidth: true }

            Repeater {
                model: root.primaryActions

                Ui.ShellButton {
                    required property var modelData

                    theme: root.theme
                    label: modelData.text || modelData.identifier
                    accessibleName: label
                    compact: true
                    active: modelData.identifier === "default"
                    visible: root.actionState === "available"
                    onClicked: root.service.invokeAction(root.snapshot.key, modelData.identifier)
                }
            }


            Ui.ShellButton {
                visible: root.snapshot.link !== null
                theme: root.theme
                label: root.snapshot.link ? root.snapshot.link.label : "Open link"
                iconName: root.snapshot.link && root.snapshot.link.meeting ? "notifications" : "chevron-right"
                compact: true
                onClicked: if (root.snapshot.link) Qt.openUrlExternally(root.snapshot.link.url)
            }

            Ui.ShellButton {
                visible: root.actionState === "available" && (root.overflowActions.length > 0 || root.inline)
                theme: root.theme
                label: "More"
                iconName: "more"
                compact: true
                ghost: true
                active: root.showOverflow
                onClicked: root.showOverflow = !root.showOverflow
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: root.showOverflow && root.actionState === "available"

            Repeater {
                model: root.overflowActions

                Ui.ShellButton {
                    required property var modelData
                    Layout.fillWidth: true
                    theme: root.theme
                    label: modelData.text || modelData.identifier
                    accessibleName: label
                    compact: true
                    ghost: true
                    onClicked: root.service.invokeAction(root.snapshot.key, modelData.identifier)
                }
            }

        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: root.actions.length > 0 && root.actionState === "expired"

            Ui.ShellIcon {
                theme: root.theme
                name: "info"
                sizeRole: "small"
                role: "muted"
            }

            Ui.ShellText {
                theme: root.theme
                text: "Actions expired"
                sizeRole: "caption"
                role: "muted"
            }
        }
    }

    MouseArea {
        id: hoverMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

}
