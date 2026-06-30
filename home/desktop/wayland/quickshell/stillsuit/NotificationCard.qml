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
    property string timeText: ""
    property color accentColor: isCritical ? Theme.urgent
        : isLow ? Theme.textSecondary
        : Theme.accent

    signal dismissed()

    readonly property bool isCritical: notification.urgency === NotificationUrgency.Critical
    readonly property bool isLow: notification.urgency === NotificationUrgency.Low
    readonly property var actionList: notification.actions || []
    readonly property int actionCount: actionList && actionList.length ? actionList.length : 0
    readonly property string appName: notification.appName || "notification"
    readonly property string bodyText: sanitizeBody(notification.body || "")
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

    implicitWidth: inline ? Theme.panelWidth - Theme.paddingLarge * 2 : 360
    implicitHeight: layout.implicitHeight + 20
    radius: Theme.radiusSmall
    color: root.inline
        ? (hover.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
        : Theme.panelChrome
    border.width: root.inline ? 0 : Theme.borderWidth
    border.color: root.isCritical ? Theme.urgent : Theme.panelBorderStrong
    clip: true

    Behavior on color {
        ColorAnimation { duration: Theme.animationFast }
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
                    text: root.timeText
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    visible: root.timeText !== ""
                    Layout.rightMargin: hover.containsMouse ? 16 : 0

                    Behavior on Layout.rightMargin {
                        NumberAnimation { duration: Theme.animationFast }
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

    Rectangle {
        anchors {
            top: parent.top
            right: parent.right
            topMargin: 6
            rightMargin: 5
        }
        width: 18
        height: 18
        radius: Theme.radiusSmall - 1
        color: closeMouse.containsMouse ? Theme.panelSurfaceHover : "transparent"
        visible: hover.containsMouse || closeMouse.containsMouse

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
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.dismissNotification()
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
