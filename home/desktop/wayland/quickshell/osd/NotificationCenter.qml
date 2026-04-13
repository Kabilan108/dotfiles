import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Scope {
    id: root

    property bool popupsVisible: true
    property bool centerVisible: false

    readonly property int defaultTimeout: 5

    NotificationServer {
        id: server
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notification => {
            notification.tracked = true
            if (notification.urgency === NotificationUrgency.Critical) return

            let timeout = notification.expireTimeout
            if (timeout < 0) timeout = root.defaultTimeout
            if (timeout > 0) {
                expireTimers.startTimer(notification, timeout)
            }
        }
    }

    IpcHandler {
        target: "notifications"
        function toggleCenter(): void {
            root.centerVisible = !root.centerVisible
        }
        function togglePopups(): void {
            root.popupsVisible = !root.popupsVisible
        }
        function dismissAll(): void {
            const notifs = server.trackedNotifications.values.slice()
            for (const n of notifs) n.dismiss()
        }
    }

    QtObject {
        id: expireTimers

        function startTimer(notification: Notification, seconds: real): void {
            const timer = timerComponent.createObject(root, {
                "interval": seconds * 1000,
                "notification": notification,
            })
            timer.triggered.connect(() => {
                if (notification.tracked) notification.dismiss()
                timer.destroy()
            })
            timer.start()
        }

        property Component timerComponent: Component {
            Timer {
                property var notification
            }
        }
    }

    // Popup toasts — single window, column layout handles variable heights
    LazyLoader {
        active: root.popupsVisible && !root.centerVisible
            && server.trackedNotifications.values.length > 0

        PanelWindow {
            anchors {
                top: true
                right: true
            }
            margins {
                top: 8
                right: 8
            }
            exclusiveZone: 0
            focusable: false
            implicitWidth: popupColumn.implicitWidth
            implicitHeight: popupColumn.implicitHeight
            color: "transparent"
            mask: Region { item: popupColumn }

            ColumnLayout {
                id: popupColumn
                spacing: 6

                Repeater {
                    model: {
                        const notifs = server.trackedNotifications.values
                        const popups = []
                        for (let i = notifs.length - 1; i >= 0 && popups.length < 5; i--) {
                            const n = notifs[i]
                            if (!n.lastGeneration) popups.push(n)
                        }
                        return popups
                    }

                    NotificationToast {
                        required property var modelData
                        notification: modelData
                    }
                }
            }
        }
    }

    // Notification center panel
    LazyLoader {
        active: root.centerVisible

        PanelWindow {
            anchors {
                top: true
                right: true
            }
            margins {
                top: 40
                right: 12
            }
            exclusiveZone: 0
            focusable: true
            implicitWidth: panel.implicitWidth
            implicitHeight: panel.implicitHeight
            color: "transparent"

            PopupPanel {
                id: panel
                implicitWidth: 380

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Notifications"
                        color: Theme.dimText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.popupsVisible ? "󰂞" : "󰂛"
                        color: root.popupsVisible ? Theme.text : Theme.overlay0
                        font.family: Theme.fontFamily
                        font.pixelSize: 14

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.popupsVisible = !root.popupsVisible
                        }
                    }

                    Text {
                        text: "Clear"
                        color: Theme.red
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        visible: server.trackedNotifications.values.length > 0

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const notifs = server.trackedNotifications.values.slice()
                                for (const n of notifs) n.dismiss()
                            }
                        }
                    }
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.leftMargin: -panel.padding
                    Layout.rightMargin: -panel.padding
                    implicitHeight: Math.min(historyLayout.implicitHeight, 500)
                    contentHeight: historyLayout.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: historyLayout
                        width: parent.width
                        spacing: 0

                        // Top divider
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: Theme.surface0
                            visible: server.trackedNotifications.values.length > 0
                        }

                        Repeater {
                            model: server.trackedNotifications

                            ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 0

                                NotificationToast {
                                    notification: modelData
                                    inline: true
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 1
                                    color: Theme.surface0
                                }
                            }
                        }

                        Text {
                            text: "No notifications"
                            color: Theme.overlay0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: Theme.paddingSmall
                            visible: server.trackedNotifications.values.length === 0
                        }
                    }
                }
            }
        }
    }
}
