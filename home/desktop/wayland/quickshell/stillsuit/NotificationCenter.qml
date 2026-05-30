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
    property bool doNotDisturb: false
    property var popupIds: []
    property int popupRevision: 0
    property bool _hydrating: false
    property var policy: fallbackPolicy

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
                right: true
            }
            margins {
                top: 42
                right: Theme.screenMargin
            }
            exclusiveZone: 0
            focusable: true
            implicitWidth: panel.implicitWidth
            implicitHeight: panel.implicitHeight
            color: "transparent"

            PopupPanel {
                id: panel
                implicitWidth: 456
                padding: 18

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.paddingSmall

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "Notifications"
                            color: Theme.text
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: Theme.fontSizeLarge
                            font.bold: true
                        }

                        Text {
                            text: root.doNotDisturb
                                ? "Silenced, with policy exceptions"
                                : server.trackedNotifications.values.length + " tracked"
                            color: root.doNotDisturb ? Theme.warning : Theme.dimText
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }

                    Ui.StPill {
                        text: root.doNotDisturb ? "DND" : "Live"
                        icon: root.doNotDisturb ? "󰂛" : "󰂚"
                        active: root.doNotDisturb
                        accentColor: Theme.warning
                        onClicked: root.doNotDisturb = !root.doNotDisturb
                    }

                    Ui.StButton {
                        text: "Clear"
                        danger: true
                        subtle: true
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
                    visible: server.trackedNotifications.values.length > 0
                }

                Rectangle {
                    id: statusBanner
                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: Theme.radiusMedium
                    color: Qt.rgba(statusAccent.r, statusAccent.g, statusAccent.b, 0.10)
                    border.width: Theme.borderWidth
                    border.color: Qt.rgba(statusAccent.r, statusAccent.g, statusAccent.b, 0.26)

                    readonly property color statusAccent: root.doNotDisturb ? Theme.warning : Theme.accent

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 10
                            rightMargin: 10
                        }
                        spacing: 8

                        Text {
                            text: root.doNotDisturb ? "󰂛" : "󰂚"
                            color: statusBanner.statusAccent
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.doNotDisturb
                                ? "DND is active. Critical and policy-matched alerts can still surface."
                                : "Popups are live. Recent alerts stay here until cleared."
                            color: Theme.subtext1
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight
                        }
                    }
                }

                Flickable {
                    Layout.fillWidth: true
                    implicitHeight: Math.min(historyLayout.implicitHeight, 560)
                    contentHeight: historyLayout.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: historyLayout
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: server.trackedNotifications

                            NotificationToast {
                                required property var modelData
                                notification: modelData
                                inline: true
                                Layout.fillWidth: true
                                onDismissed: root.removePopup(root.notificationId(notification))
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 130
                            radius: Theme.radiusMedium
                            color: Theme.panelBgSoft
                            border.width: Math.max(1, Theme.borderWidth * 2)
                            border.color: Theme.panelBorder
                            visible: server.trackedNotifications.values.length === 0

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 8

                                Text {
                                    text: "󰂚"
                                    color: Theme.dimText
                                    font.family: Theme.fontFamily
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
                                    text: root.doNotDisturb ? "DND is active" : "Incoming alerts will appear here"
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
}
