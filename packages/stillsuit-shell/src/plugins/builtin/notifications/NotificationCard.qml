import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import "../../../ui" as Ui
import "Motion.js" as Motion

// One notification. The card draws and reports gestures; the deck's slot
// around it owns every position, scale, and opacity change.
Ui.ShellSurface {
    id: root

    required property var context
    required property var service
    required property var snapshot
    property bool interactive: true
    property real contentOpacity: 1
    // The horizontal drag, and its speed in points per second.
    property real dragOffset: 0
    property real dragVelocity: 0
    readonly property bool dragging: gestureMouse.dragging

    signal swipeEnded(bool dismissed, real direction, real velocity)

    theme: context.theme
    readonly property var actions: Array.isArray(snapshot.actions) ? snapshot.actions : []
    readonly property var buttonActions: actions.filter(function (action) {
        return String(action.identifier || "") !== "default" && !root.isSettingsAction(action)
    })
    readonly property var defaultAction: actions.find(function (action) {
        return String(action.identifier || "") === "default"
    })
    readonly property string actionState: service ? service.actionState(snapshot.key) : "expired"
    readonly property bool canActivate: actionState === "available" && defaultAction !== undefined
    readonly property string stateRole: service ? service.viewState(snapshot) : "info"
    readonly property color stateColor: stateRole === "info" && service && snapshot.sourceKey
                                        ? service.sourceTint(snapshot.sourceKey) :
                                          theme.component.notification[stateRole]
    readonly property string imageSource: service ? service.imageForSnapshot(snapshot) : ""
    readonly property real progress: service ? service.progressFor(snapshot) : -1
    readonly property bool reducedMotion: context.settings && context.settings.values
                                          && context.settings.values.reducedMotion === true
    readonly property real dismissThreshold: Math.min(width * 0.25, 80)
    readonly property real flickVelocity: 420
    readonly property bool hovered: hoverMouse.containsMouse
    readonly property string sourceText: (snapshot.sourceLabel || snapshot.appName
                                          || "Notification") + (snapshot.context ? " · "
                                                                                   + snapshot.context :
                                                                                   "")

    kind: "notification"
    implicitWidth: theme.metrics.panelWidth - theme.metrics.panelPadding * 2
    implicitHeight: contentColumn.implicitHeight + 24

    function cleanBody(value) {
        return String(value || "").replace(/<img[^>]*>/gi, "").trim()
    }

    function isSettingsAction(action) {
        var identifier = String((action || {}).identifier || "").trim().toLowerCase()
        var label = String((action || {}).text || "").trim().toLowerCase()
        return identifier === "settings" || label === "settings"
    }

    function iconForState(state) {
        if (state === "success")
            return "success"
        if (state === "warning")
            return "warning"
        if (state === "danger")
            return "danger"
        if (state === "info")
            return "info"
        return "notifications"
    }

    function withAlpha(value, alpha) {
        var parsed = Qt.color(value)
        return Qt.rgba(parsed.r, parsed.g, parsed.b, Math.max(0, Math.min(1, alpha)))
    }

    // A click opens the sender when it has a default action, else dismisses.
    function activate() {
        if (!root.service)
            return
        if (root.canActivate)
            root.service.invokeAction(root.snapshot.key, "default")
        else
            root.service.dismiss(root.snapshot.key)
    }

    MouseArea {
        id: gestureMouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.interactive
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        preventStealing: dragging
        property real pressX: 0
        property real pressY: 0
        property bool dragging: false
        property bool gestureConsumed: false
        property real lastX: 0
        property real lastT: 0

        onPressed: mouse => {
            pressX = mouse.x
            pressY = mouse.y
            lastX = mouse.x
            lastT = Date.now()
            root.dragVelocity = 0
            dragging = false
            gestureConsumed = false
        }

        onPositionChanged: mouse => {
            if (!pressed)
                return
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
                    root.dragVelocity = root.dragVelocity * 0.6 + instant * 0.4
                    lastX = mouse.x
                    lastT = now
                }
                root.dragOffset = dx
            }
        }

        onReleased: {
            if (!dragging)
                return
            var offset = root.dragOffset
            var direction = offset < 0 ? -1 : 1
            var flicked = Math.abs(root.dragVelocity) >= root.flickVelocity && ((root.dragVelocity
                                                                                 < 0) === (offset
                                                                                           < 0))
            dragging = false
            root.swipeEnded(flicked || Math.abs(offset) >= root.dismissThreshold, direction,
                            root.dragVelocity)

        }

        onCanceled: {
            if (dragging) {
                dragging = false
                root.swipeEnded(false, root.dragOffset < 0 ? -1 : 1, 0)
            }
        }

        onClicked: if (!gestureConsumed)
                       root.activate()
    }

    ColumnLayout {
        id: contentColumn

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
        }
        spacing: 8
        opacity: root.contentOpacity
        enabled: root.interactive

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                id: leadingTile
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                Layout.alignment: Qt.AlignTop
                radius: root.theme.metrics.radiusSmall
                color: picture.status === Image.Ready ? "transparent" : root.withAlpha(
                                                            root.stateColor, 0.16)

                Ui.ShellIcon {
                    anchors.centerIn: parent
                    visible: picture.status !== Image.Ready
                    theme: root.theme
                    name: root.iconForState(root.stateRole)
                    color: root.stateColor
                    accessibleName: root.stateRole + " notification"
                    source: root.service ? root.service.iconForSnapshot(root.snapshot) : ""
                }

                Image {
                    id: picture
                    anchors.fill: parent
                    visible: false
                    source: root.imageSource
                    sourceSize.width: 60
                    sourceSize.height: 60
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    layer.enabled: status === Image.Ready
                }

                Rectangle {
                    id: pictureMask
                    anchors.fill: parent
                    visible: false
                    radius: parent.radius
                    layer.enabled: true
                }

                MultiEffect {
                    anchors.fill: parent
                    visible: picture.status === Image.Ready
                    source: picture
                    maskEnabled: true
                    maskSource: pictureMask
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Ui.ShellText {
                    Layout.fillWidth: true
                    theme: root.theme
                    text: root.sourceText
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

            Ui.ShellButton {
                theme: root.theme
                label: ""
                iconName: "close"
                compact: true
                ghost: true
                accessibleName: "Dismiss notification"
                onClicked: root.service.dismiss(root.snapshot.key)
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
            maximumLineCount: 3
            elide: Text.ElideRight
        }

        Rectangle {
            id: progressTrack
            visible: root.progress >= 0
            Layout.fillWidth: true
            Layout.preferredHeight: 4
            radius: 2
            color: root.withAlpha(root.stateColor, 0.18)

            Rectangle {
                height: parent.height
                radius: parent.radius
                width: parent.width * Math.max(0, Math.min(1, progressSpring.value))
                color: root.stateColor
            }

            SpringValue {
                id: progressSpring
                spring: Motion.LAYOUT
                target: Math.max(0, root.progress)
                epsilon: 0.001
                instant: root.reducedMotion
            }
        }

        // Buttons sit right-aligned on one line; when they need more room the
        // row takes the card's width and wraps.
        Flow {
            id: buttonFlow
            readonly property real naturalWidth: {
                var total = 0
                var shown = 0
                for (var index = 0; index < children.length; index++) {
                    var child = children[index]
                    if (!child.visible || child.implicitWidth <= 0)
                        continue
                    total += child.implicitWidth
                    shown += 1
                }
                return total + Math.max(0, shown - 1) * spacing
            }
            Layout.alignment: Qt.AlignRight
            Layout.preferredWidth: Math.min(naturalWidth, contentColumn.width)
            spacing: 6
            visible: root.snapshot.link !== null || (root.buttonActions.length > 0
                                                     && root.actionState === "available")

            Repeater {
                model: root.actionState === "available" ? root.buttonActions : []

                Ui.ShellButton {
                    required property var modelData

                    theme: root.theme
                    label: modelData.text || modelData.identifier
                    accessibleName: label
                    compact: true
                    onClicked: root.service.invokeAction(root.snapshot.key, modelData.identifier)
                }
            }

            Ui.ShellButton {
                visible: root.snapshot.link !== null
                theme: root.theme
                label: root.snapshot.link ? root.snapshot.link.label : "Open link"
                iconName: root.snapshot.link && root.snapshot.link.meeting ? "notifications" :
                                                                             "chevron-right"
                compact: true
                onClicked: if (root.snapshot.link)
                               Qt.openUrlExternally(root.snapshot.link.url)
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
