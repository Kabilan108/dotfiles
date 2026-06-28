import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "ui" as Ui

Scope {
    id: root

    property bool popupsVisible: true
    property bool centerVisible: false
    property var coordinator: null
    property bool doNotDisturb: false
    property var popupIds: []
    property int popupRevision: 0
    property var arrivalTimes: ({})
    property double nowMs: Date.now()
    property bool _hydrating: false
    property var policy: fallbackPolicy
    readonly property int trackedCount: server.trackedNotifications.values.length

    readonly property var fallbackPolicy: ({
        notifications: {
            dndBypass: {
                critical: true,
                appNames: ["battery", "Battery"],
                appUrgencies: [{ appName: "notify-send", urgency: "critical" }],
                summaryPatterns: []
            }
        }
    })

    readonly property string stateBase: {
        const xdgState = Quickshell.env("XDG_STATE_HOME")
        return xdgState && xdgState.length > 0 ? xdgState : Quickshell.env("HOME") + "/.local/state"
    }
    readonly property string stateDir: stateBase + "/stillsuit/"
    readonly property string statePath: stateDir + "notifications.json"
    readonly property string policyPath: Quickshell.env("HOME") + "/.config/quickshell/stillsuit-policy.json"

    function notificationId(notification) {
        return notification ? notification.id : -1
    }

    function relativeTime(id) {
        const arrived = root.arrivalTimes[id]
        if (!arrived) return ""
        const diff = Math.max(0, root.nowMs - arrived)
        const mins = Math.floor(diff / 60000)
        if (mins < 1) return "now"
        if (mins < 60) return mins + "m"
        const hours = Math.floor(mins / 60)
        if (hours < 24) return hours + "h"
        return Math.floor(hours / 24) + "d"
    }

    function urgencyName(notification) {
        if (!notification) return "normal"
        if (notification.urgency === NotificationUrgency.Critical) return "critical"
        if (notification.urgency === NotificationUrgency.Low) return "low"
        return "normal"
    }

    function dndPolicy() {
        const notifications = policy && policy.notifications ? policy.notifications : fallbackPolicy.notifications
        return notifications && notifications.dndBypass ? notifications.dndBypass : fallbackPolicy.notifications.dndBypass
    }

    function shouldBypassDnd(notification) {
        if (!notification) return false

        const bypass = dndPolicy()
        const appName = String(notification.appName || "")
        const summary = String(notification.summary || "")
        const urgency = urgencyName(notification)

        if (bypass.critical && notification.urgency === NotificationUrgency.Critical) return true

        const apps = Array.isArray(bypass.appNames) ? bypass.appNames : []
        for (let i = 0; i < apps.length; i++) {
            if (appName === String(apps[i])) return true
        }

        const appUrgencies = Array.isArray(bypass.appUrgencies) ? bypass.appUrgencies : []
        for (let i = 0; i < appUrgencies.length; i++) {
            const rule = appUrgencies[i]
            if (!rule) continue
            if (appName === String(rule.appName || "") && urgency === String(rule.urgency || "").toLowerCase()) return true
        }

        const patterns = Array.isArray(bypass.summaryPatterns) ? bypass.summaryPatterns : []
        for (let i = 0; i < patterns.length; i++) {
            try {
                if (new RegExp(String(patterns[i])).test(summary)) return true
            } catch (error) {
                console.warn("stillsuit notifications: invalid DND bypass summary pattern:", patterns[i])
            }
        }

        return false
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

    FileView {
        id: policyFile
        path: root.policyPath
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: {
            try {
                root.policy = JSON.parse(text())
            } catch (error) {
                console.warn("stillsuit notifications: failed to parse policy:", error)
                root.policy = root.fallbackPolicy
            }
        }
        onLoadFailed: root.policy = root.fallbackPolicy
    }

    Timer {
        id: saveTimer
        interval: 200
        repeat: false
        onTriggered: root.flushState()
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.centerVisible
        onTriggered: root.nowMs = Date.now()
    }

    onCenterVisibleChanged: if (centerVisible) nowMs = Date.now()

    Component.onCompleted: Qt.callLater(function() {
        stateFile.reload()
        policyFile.reload()
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

            const arrival = Object.assign({}, root.arrivalTimes)
            arrival[notification.id] = Date.now()
            root.arrivalTimes = arrival

            if (!root.doNotDisturb || root.shouldBypassDnd(notification)) {
                root.addPopup(notification)
                const timeout = root.timeoutFor(notification)
                if (timeout > 0) expireTimers.startTimer(notification.id, timeout)
            }
        }
    }

    IpcHandler {
        target: "notifications"

        function toggleCenter(): string {
            if (root.coordinator) return root.coordinator.togglePanel(root)
            root.centerVisible = !root.centerVisible
            return root.centerVisible ? "open" : "closed"
        }

        function showHistory(): string {
            if (root.coordinator) return root.coordinator.panelAction("notifications", "open")
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
        active: root.popupsVisible

        PanelWindow {
            visible: root.popupsVisible && !root.centerVisible && root.popupIds.length > 0
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
        active: true

        PanelWindow {
            visible: root.centerVisible
            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }
            margins {
                top: Theme.barHeight + Theme.screenMargin + Theme.panelGap
            }
            exclusiveZone: 0
            focusable: false
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                onClicked: root.centerVisible = false
            }

            MouseArea {
                anchors.fill: panel
                onClicked: {}
            }

            PopupPanel {
                id: panel
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.rightMargin: Theme.screenMargin
                implicitWidth: 380
                padding: 16
                color: "#f011111b"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Notifications"
                        color: Theme.text
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: Theme.fontSizeLarge
                        font.bold: true
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: server.trackedNotifications.values.length + " recent"
                        color: Theme.subtext1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Item { Layout.fillWidth: true }

                    Ui.StPill {
                        text: "DND"
                        icon: Theme.icon.dark_mode
                        radius: Theme.radiusSmall - 1
                        active: root.doNotDisturb
                        onClicked: root.doNotDisturb = !root.doNotDisturb
                    }

                    Ui.StButton {
                        text: "clear all"
                        icon: Theme.icon.delete
                        danger: true
                        visible: server.trackedNotifications.values.length > 0
                        onClicked: {
                            const notifs = server.trackedNotifications.values.slice()
                            root.popupIds = []
                            root.popupRevision += 1
                            for (const n of notifs) n.dismiss()
                        }
                    }
                }

                Ui.StSeparator {
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 42
                    radius: Theme.radiusSmall
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                    border.width: Theme.borderWidth
                    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.38)
                    visible: root.doNotDisturb

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 12
                            rightMargin: 12
                        }
                        spacing: 10

                        Text {
                            text: Theme.icon.dark_mode
                            color: Theme.accent
                            font.family: Theme.iconFamily
                            font.variableAxes: ({ "wght": 500, "opsz": 20 })
                            font.pixelSize: 17
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "notifications silenced — alerts are held quietly"
                            color: Theme.subtext1
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: Theme.fontSizeMedium
                            elide: Text.ElideRight
                        }
                    }
                }

                Flickable {
                    Layout.fillWidth: true
                    implicitHeight: Math.min(historyLayout.implicitHeight, 360)
                    contentHeight: historyLayout.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height

                    ColumnLayout {
                        id: historyLayout
                        width: parent.width
                        spacing: 0

                        Repeater {
                            model: server.trackedNotifications

                            NotificationCard {
                                required property var modelData
                                required property int index
                                notification: modelData
                                inline: true
                                divider: index < server.trackedNotifications.values.length - 1
                                timeText: root.relativeTime(modelData.id)
                                Layout.fillWidth: true
                                onDismissed: root.removePopup(root.notificationId(notification))
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 26
                            Layout.bottomMargin: 26
                            spacing: 8
                            visible: server.trackedNotifications.values.length === 0

                            Text {
                                text: Theme.icon.notifications
                                color: Theme.dimText
                                font.family: Theme.iconFamily
                                font.variableAxes: ({ "wght": 500, "opsz": 20 })
                                font.pixelSize: Theme.fontSizeIconLarge
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: "No notifications"
                                color: Theme.text
                                font.family: Theme.bodyFontFamily
                                font.pixelSize: Theme.fontSizeTitle
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: root.doNotDisturb ? "Do Not Disturb is active" : "Incoming alerts will appear here"
                                color: Theme.dimText
                                font.family: Theme.bodyFontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }
            }
        }
    }
}
