import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import "ui" as Ui

Rectangle {
    id: root

    required property var notification
    property bool inline: false
    property bool compact: false
    property color accentColor: isCritical ? Theme.urgent
        : isLow ? Theme.mutedText
        : Theme.accent

    signal dismissed()

    readonly property bool isCritical: notification.urgency === NotificationUrgency.Critical
    readonly property bool isLow: notification.urgency === NotificationUrgency.Low
    readonly property bool singleLine: bodyText === ""
    readonly property int iconSize: inline ? 32 : 42
    readonly property int contentPad: inline ? 10 : 14
    readonly property var actionList: notification.actions || []
    readonly property int actionCount: actionList && actionList.length ? actionList.length : 0
    readonly property string appName: notification.appName || "notification"
    readonly property string bodyText: sanitizeBody(notification.body || "")
    readonly property string iconSource: {
        if (notification.image) return notification.image
        const icon = notification.appIcon
        if (!icon || icon === "") return ""
        if (icon.startsWith("file://") || icon.startsWith("image://")) return icon
        if (icon.startsWith("/")) return "file://" + icon
        return Quickshell.iconPath(icon, true)
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

    implicitWidth: inline ? Theme.panelWidth - Theme.paddingMedium * 2 : 420
    implicitHeight: cardContent.implicitHeight + contentPad * 2
    radius: Theme.radiusSmall
    color: inline ? Theme.panelBgSoft : Theme.panelBgStrong
    border.width: Theme.borderWidth
    border.color: isCritical ? Theme.urgent : mouse.containsMouse ? Theme.panelBorderStrong : Theme.panelBorder
    clip: true

    Behavior on color {
        ColorAnimation { duration: Theme.animationFast }
    }

    RowLayout {
        id: cardContent
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: root.contentPad
            rightMargin: root.contentPad
            topMargin: root.contentPad
        }
        spacing: inline ? 10 : 12

        Rectangle {
            Layout.preferredWidth: root.iconSize
            Layout.preferredHeight: root.iconSize
            Layout.alignment: Qt.AlignTop
            radius: Theme.radiusSmall
            color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
            border.width: Theme.borderWidth
            border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.36)
            clip: true

            Image {
                id: appIcon
                anchors.fill: parent
                anchors.margins: 6
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
                font.variableAxes: ({ "wght": 500, "opsz": 20 })
                font.pixelSize: inline ? 14 : 19
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: inline ? 4 : 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: root.appName
                    color: Theme.dimText
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: 10
                    font.bold: true
                    elide: Text.ElideRight
                }

                Rectangle {
                    visible: root.isCritical
                    Layout.preferredWidth: criticalLabel.implicitWidth + 16
                    Layout.preferredHeight: 22
                    radius: Theme.radiusPill
                    color: Qt.rgba(Theme.urgent.r, Theme.urgent.g, Theme.urgent.b, 0.16)
                    border.width: Theme.borderWidth
                    border.color: Theme.urgent

                    Text {
                        id: criticalLabel
                        anchors.centerIn: parent
                        text: "critical"
                        color: Theme.urgent
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: 10
                        font.bold: true
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    radius: Theme.radiusSmall
                    color: closeMouse.containsMouse ? Theme.panelSurfaceHover : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: Theme.icon.close
                        color: closeMouse.containsMouse ? Theme.text : Theme.mutedText
                        font.family: Theme.iconFamily
                        font.variableAxes: ({ "wght": 500, "opsz": 20 })
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dismissNotification()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: notification.summary || "Notification"
                color: Theme.text
                font.family: Theme.bodyFontFamily
                font.pixelSize: inline ? Theme.fontSizeTitle : Theme.fontSizeLarge
                font.bold: true
                wrapMode: Text.WordWrap
                maximumLineCount: inline ? 1 : 2
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: root.bodyText
                color: Theme.subtext1
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontSizeMedium
                textFormat: Text.StyledText
                wrapMode: Text.WordWrap
                maximumLineCount: inline ? 2 : 3
                elide: Text.ElideRight
                visible: text !== ""
                lineHeight: 1.08
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: root.actionCount > 0

                Repeater {
                    model: root.actionList

                    Ui.StButton {
                        required property var modelData
                        text: modelData.text
                        subtle: false
                        onClicked: modelData.invoke()
                    }
                }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
