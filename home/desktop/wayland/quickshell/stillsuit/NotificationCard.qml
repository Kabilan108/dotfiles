import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import "ui" as Ui

Rectangle {
    id: root

    required property var notification
    property bool inline: false
    property bool divider: false
    property bool closeButtonAlwaysVisible: inline
    property bool dismissGesturesEnabled: true
    property string timeText: ""
    property color accentColor: isCritical ? Theme.urgent
        : isLow ? Theme.textSecondary
        : Theme.accent
    property real dragOffset: 0

    signal dismissed()

    readonly property bool isCritical: notification.urgency === NotificationUrgency.Critical
    readonly property bool isLow: notification.urgency === NotificationUrgency.Low
    readonly property var actionList: notification.actions || []
    readonly property int actionCount: actionList && actionList.length ? actionList.length : 0
    readonly property string appName: notification.appName || "notification"
    readonly property string bodyText: sanitizeBody(notification.body || "")
    readonly property real dismissThreshold: Math.min(width * 0.25, 80)
    readonly property real flickVelocity: 420
    readonly property string iconSource: {
        const icon = notification.appIcon
        if (icon && icon !== "") {
            if (icon.startsWith("file://") || icon.startsWith("image://")) return icon
            if (icon.startsWith("/")) return "file://" + icon
            return Quickshell.iconPath(icon, true)
        }
        if (notification.image) return notification.image
        return ""
    }

    function sanitizeBody(raw) {
        return String(raw || "")
            .replace(/<img[^>]*>/gi, "")
            .replace(/^\s*(?:https?:\/\/|www\.)?(?:[a-z0-9-]+\.)+[a-z]{2,}(?::\d+)?(?:\/\S*)?\s+/i, "")
            .trim()
    }

    function dismissNotification() {
        if (root.notification && typeof root.notification.dismiss === "function") {
            root.notification.dismiss()
        }
        root.dismissed()
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

    implicitWidth: inline ? Theme.panelWidth - Theme.paddingLarge * 2 : 360
    implicitHeight: layout.implicitHeight + 20
    radius: Theme.radiusSmall
    color: root.inline
        ? (hover.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
        : Theme.panelChrome
    border.width: root.inline ? 0 : Theme.borderWidth
    border.color: root.isCritical ? Theme.urgent : Theme.panelBorderStrong
    clip: true
    opacity: 1 - Math.min(Math.abs(root.dragOffset) / Math.max(root.width, 1), 0.48)

    transform: Translate {
        x: root.dragOffset
    }

    Behavior on color {
        ColorAnimation { duration: Theme.animationFast }
    }

    NumberAnimation {
        id: snapBackAnimation
        target: root
        property: "dragOffset"
        to: 0
        duration: Theme.animationFast
        easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        id: slideAwayAnimation
        property real targetOffset: 0

        NumberAnimation {
            target: root
            property: "dragOffset"
            to: slideAwayAnimation.targetOffset
            duration: Theme.animationMedium
            easing.type: Easing.OutCubic
        }

        ScriptAction {
            script: root.dismissNotification()
        }
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: Theme.panelBorder
        visible: root.inline && root.divider
    }

    Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: 3
        color: Theme.urgent
        visible: root.inline && root.isCritical
    }

    MouseArea {
        id: gestureMouse
        anchors.fill: parent
        acceptedButtons: root.dismissGesturesEnabled ? Qt.LeftButton : Qt.NoButton
        preventStealing: dragging
        property real pressX: 0
        property real pressY: 0
        property bool dragging: false
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
        }

        onPositionChanged: mouse => {
            if (!pressed || !root.dismissGesturesEnabled) return

            const dx = mouse.x - pressX
            const dy = mouse.y - pressY
            if (!dragging && Math.abs(dx) > 6 && Math.abs(dx) > Math.abs(dy) * 1.2) {
                dragging = true
                lastX = mouse.x
                lastT = Date.now()
            }
            if (dragging) {
                const now = Date.now()
                const dt = now - lastT
                if (dt > 0) {
                    const instant = (mouse.x - lastX) / dt * 1000
                    velocity = velocity * 0.6 + instant * 0.4
                    lastX = mouse.x
                    lastT = now
                }
                root.dragOffset = dx
            }
        }

        onReleased: mouse => {
            if (!dragging) return

            const direction = root.dragOffset < 0 ? -1 : 1
            const flicked = Math.abs(velocity) >= root.flickVelocity
                && ((velocity < 0) === (root.dragOffset < 0))
            if (flicked || Math.abs(root.dragOffset) >= root.dismissThreshold) {
                root.dismissWithSlide(direction)
            } else {
                root.snapBack()
            }
            dragging = false
        }

        onCanceled: {
            if (dragging) root.snapBack()
            dragging = false
        }

        onDoubleClicked: mouse => root.dismissWithSlide(1)
    }

    RowLayout {
        id: layout
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: 8
            rightMargin: 8
            topMargin: 10
        }
        spacing: 11

        Item {
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            Layout.alignment: Qt.AlignTop

            Image {
                id: appIcon
                anchors.fill: parent
                source: root.iconSource
                sourceSize.width: width * Screen.devicePixelRatio
                sourceSize.height: height * Screen.devicePixelRatio
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                visible: status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                visible: appIcon.status !== Image.Ready
                text: root.isCritical ? Theme.icon.warning : Theme.icon.notifications
                color: root.accentColor
                font.family: Theme.iconFamily
                font.variableAxes: ({ "FILL": 0, "wght": 500, "opsz": 20 })
                font.pixelSize: 19
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: root.appName
                    color: root.isCritical ? Theme.urgent : Theme.textTertiary
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.capitalization: Font.AllLowercase
                    elide: Text.ElideRight
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.timeText
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    visible: root.timeText !== ""
                }

                Rectangle {
                    id: closeButton
                    readonly property bool shown: root.closeButtonAlwaysVisible || hover.containsMouse || closeMouse.containsMouse
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    radius: Theme.radiusSmall - 1
                    color: closeMouse.containsMouse ? Theme.panelSurfaceHover : "transparent"
                    opacity: shown ? 1 : 0
                    clip: true

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.animationFast }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: Theme.icon.close
                        color: closeMouse.containsMouse ? Theme.textPrimary : Theme.textTertiary
                        font.family: Theme.iconFamily
                        font.variableAxes: ({ "wght": 500, "opsz": 20 })
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        enabled: closeButton.shown
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dismissNotification()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: notification.summary || "Notification"
                color: Theme.textPrimary
                font.family: Theme.bodyFontFamily
                font.pixelSize: 13
                font.bold: true
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: root.bodyText
                color: Theme.textSecondary
                font.family: Theme.bodyFontFamily
                font.pixelSize: 12
                textFormat: Text.StyledText
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                visible: text !== ""
                lineHeight: 1.2
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 6
                visible: root.actionCount > 0

                Repeater {
                    model: root.actionList

                    Ui.StButton {
                        required property var modelData
                        text: modelData.text
                        subtle: false
                        compact: true
                        onClicked: modelData.invoke()
                    }
                }
            }
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
