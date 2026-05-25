import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Scope {
    id: root

    property bool popupsVisible: true
    property bool centerVisible: false
    property bool doNotDisturb: false
    property var popupIds: []
    property int popupRevision: 0
    property bool _hydrating: false

    readonly property string stateBase: {
        const xdgState = Quickshell.env("XDG_STATE_HOME")
        return xdgState && xdgState.length > 0 ? xdgState : Quickshell.env("HOME") + "/.local/state"
    }
    readonly property string stateDir: stateBase + "/stillsuit/"
    readonly property string statePath: stateDir + "notifications.json"

    function notificationId(notification) {
        return notification ? notification.id : -1
    }

    function isPopupVisible(notification) {
        const id = notificationId(notification)
        return popupIds.indexOf(id) !== -1
    }

    function addPopup(notification) {
        const id = notificationId(notification)
        if (id < 0 || !root.popupsVisible) return

        const next = popupIds.filter(existing => existing !== id)
        next.unshift(id)
        root.popupIds = next.slice(0, 5)
        root.popupRevision += 1
    }

    function removePopup(id) {
        const next = popupIds.filter(existing => existing !== id)
        if (next.length === popupIds.length) return

        root.popupIds = next
        root.popupRevision += 1
    }

    function dismissNotification(notification) {
        if (!notification) return
        removePopup(notificationId(notification))
        notification.dismiss()
    }

    function timeoutFor(notification) {
        if (notification.urgency === NotificationUrgency.Critical) return 0
        if (notification.urgency === NotificationUrgency.Low) return Theme.notificationLowMs

        const requested = notification.expireTimeout
        if (requested > 0) return requested * 1000
        return Theme.notificationDefaultMs
    }

    function saveState() {
        if (_hydrating) return
        saveTimer.restart()
    }

    function flushState() {
        stateFile.setText(JSON.stringify({
            dnd: root.doNotDisturb
        }, null, 2) + "\n")
    }

    function loadState(raw) {
        const text = String(raw || "").trim()
        if (!text) return

        try {
            const parsed = JSON.parse(text)
            if (typeof parsed.dnd === "boolean") {
                _hydrating = true
                root.doNotDisturb = parsed.dnd
                _hydrating = false
            }
        } catch (error) {
            console.warn("stillsuit notifications: failed to parse state:", error)
        }
    }

    onDoNotDisturbChanged: saveState()

    Process {
        id: ensureStateDir
        command: ["mkdir", "-p", root.stateDir]
        running: true
    }

    FileView {
        id: stateFile
        path: root.statePath
        watchChanges: false
        atomicWrites: true
        printErrors: false
        onLoaded: root.loadState(text())
        onLoadFailed: root.loadState("")
    }

    Timer {
        id: saveTimer
        interval: 200
        repeat: false
        onTriggered: root.flushState()
    }

    Component.onCompleted: Qt.callLater(function() {
        stateFile.reload()
    })

    NotificationServer {
        id: server
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notification => {
            notification.tracked = true

            const bypassDnd = notification.urgency === NotificationUrgency.Critical
            if (!root.doNotDisturb || bypassDnd) {
                root.addPopup(notification)
                const timeout = root.timeoutFor(notification)
                if (timeout > 0) expireTimers.startTimer(notification.id, timeout)
            }
        }
    }

    IpcHandler {
        target: "notifications"

        function toggleCenter(): string {
            root.centerVisible = !root.centerVisible
            return root.centerVisible ? "open" : "closed"
        }

        function showHistory(): string {
            root.centerVisible = true
            return "open"
        }

        function hideCenter(): string {
            root.centerVisible = false
            return "closed"
        }

        function togglePopups(): string {
            root.popupsVisible = !root.popupsVisible
            return root.popupsVisible ? "on" : "off"
        }

        function toggleDnd(): string {
            root.doNotDisturb = !root.doNotDisturb
            return root.doNotDisturb ? "on" : "off"
        }

        function setDnd(value: string): string {
            const normalized = String(value || "").toLowerCase()
            root.doNotDisturb = normalized === "1" || normalized === "true" || normalized === "on" || normalized === "yes"
            return root.doNotDisturb ? "on" : "off"
        }

        function dndState(): string {
            return root.doNotDisturb ? "on" : "off"
        }

        function dismissAll(): string {
            const notifs = server.trackedNotifications.values.slice()
            root.popupIds = []
            root.popupRevision += 1
            for (const n of notifs) n.dismiss()
            return "ok"
        }

        function ping(): string {
            return "ok"
        }
    }

    QtObject {
        id: expireTimers

        function startTimer(notificationId: int, timeoutMs: int): void {
            const timer = timerComponent.createObject(root, {
                "interval": timeoutMs,
                "notificationId": notificationId,
            })
            timer.triggered.connect(() => {
                root.removePopup(notificationId)
                timer.destroy()
            })
            timer.start()
        }

        property Component timerComponent: Component {
            Timer {
                property int notificationId
            }
        }
    }

    LazyLoader {
        active: root.popupsVisible && !root.centerVisible && root.popupIds.length > 0

        PanelWindow {
            anchors {
                top: true
                right: true
            }
            margins {
                top: Theme.screenMargin
                right: Theme.screenMargin
            }
            exclusiveZone: 0
            focusable: false
            implicitWidth: popupColumn.implicitWidth
            implicitHeight: popupColumn.implicitHeight
            color: "transparent"
            mask: Region { item: popupColumn }

            ColumnLayout {
                id: popupColumn
                spacing: Theme.panelGap

                Repeater {
                    model: {
                        void(root.popupRevision)
                        const notifs = server.trackedNotifications.values
                        const popups = []
                        for (let i = notifs.length - 1; i >= 0 && popups.length < 5; i--) {
                            const n = notifs[i]
                            if (root.isPopupVisible(n)) popups.push(n)
                        }
                        return popups
                    }

                    NotificationToast {
                        required property var modelData
                        notification: modelData
                        onDismissed: root.removePopup(root.notificationId(notification))
                    }
                }
            }
        }
    }

    LazyLoader {
        active: root.centerVisible

        PanelWindow {
            anchors {
                top: true
                right: true
            }
            margins {
                top: 40
                right: Theme.screenMargin
            }
            exclusiveZone: 0
            focusable: true
            implicitWidth: panel.implicitWidth
            implicitHeight: panel.implicitHeight
            color: "transparent"

            PopupPanel {
                id: panel
                implicitWidth: Theme.panelWidth

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.paddingSmall

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: "Notifications"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeTitle
                            font.bold: true
                        }

                        Text {
                            text: root.doNotDisturb ? "Silenced" : "Ready"
                            color: root.doNotDisturb ? Theme.warning : Theme.dimText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }

                    Rectangle {
                        implicitWidth: dndRow.implicitWidth + 16
                        implicitHeight: 28
                        radius: Theme.radiusPill
                        color: dndMouse.containsMouse || root.doNotDisturb ? Theme.panelSurfaceHover : Theme.panelSurface
                        border.width: Theme.borderWidth
                        border.color: root.doNotDisturb ? Theme.warning : Theme.panelBorder

                        RowLayout {
                            id: dndRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: root.doNotDisturb ? "󰂛" : "󰂚"
                                color: root.doNotDisturb ? Theme.warning : Theme.dimText
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                            }

                            Text {
                                text: root.doNotDisturb ? "DND" : "Live"
                                color: root.doNotDisturb ? Theme.warning : Theme.dimText
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }

                        MouseArea {
                            id: dndMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: root.doNotDisturb = !root.doNotDisturb
                        }
                    }

                    Text {
                        text: "Clear"
                        color: Theme.urgent
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        visible: server.trackedNotifications.values.length > 0

                        MouseArea {
                            anchors {
                                fill: parent
                                margins: -6
                            }
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const notifs = server.trackedNotifications.values.slice()
                                root.popupIds = []
                                root.popupRevision += 1
                                for (const n of notifs) n.dismiss()
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.panelBorder
                    visible: server.trackedNotifications.values.length > 0
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.leftMargin: -panel.padding
                    Layout.rightMargin: -panel.padding
                    implicitHeight: Math.min(historyLayout.implicitHeight, 520)
                    contentHeight: historyLayout.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: historyLayout
                        width: parent.width
                        spacing: 0

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
                                    onDismissed: root.removePopup(root.notificationId(notification))
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 1
                                    color: Theme.panelBorder
                                }
                            }
                        }

                        Text {
                            text: "No notifications"
                            color: Theme.mutedText
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
