pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../ui" as Ui

Scope {
    id: root

    required property var context
    required property var service
    required property var screen
    required property string outputId
    property double nowMs: Date.now()

    function open(payloadJson) {
        panel.visible = true
        service.refresh(false)
    }

    function close() {
        panel.visible = false
    }

    Timer {
        interval: 30000
        repeat: true
        running: panel.visible
        onTriggered: root.nowMs = Date.now()
    }

    PanelWindow {
        id: panel

        screen: root.screen
        visible: false
        color: "transparent"
        exclusiveZone: 0
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        mask: Region { item: dismissArea }

        MouseArea {
            id: dismissArea

            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                topMargin: root.context.theme.metrics.barHeight
            }
            acceptedButtons: Qt.AllButtons
            onClicked: root.context.actions.surfaceClose("stillsuit.agent-usage")
        }

        Ui.ShellSurface {
            id: panelSurface

            anchors {
                top: parent.top
                right: parent.right
                topMargin: root.context.theme.metrics.barHeight
                    + root.context.theme.metrics.spaceUnit
                rightMargin: root.context.theme.metrics.spaceUnit
            }
            width: root.context.theme.metrics.panelWidth
            height: Math.min(content.implicitHeight
                    + root.context.theme.metrics.panelPadding * 2,
                parent.height - anchors.topMargin
                    - root.context.theme.metrics.spaceUnit)
            theme: root.context.theme
            kind: "panel"

            MouseArea {
                anchors.fill: parent
                onClicked: function(mouse) { mouse.accepted = true }
            }

            ColumnLayout {
                id: content

                anchors.fill: parent
                anchors.margins: root.context.theme.metrics.panelPadding
                spacing: root.context.theme.metrics.spaceUnit * 3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.context.theme.metrics.spaceUnit * 2

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Ui.ShellText {
                            Layout.fillWidth: true
                            theme: root.context.theme
                            text: "Agent limits"
                            sizeRole: "heading"
                        }

                        Ui.ShellText {
                            Layout.fillWidth: true
                            theme: root.context.theme
                            text: root.service.accountCount + " accounts · "
                                + root.service.readyCount + " reporting"
                            sizeRole: "caption"
                            role: "muted"
                        }
                    }

                    Ui.ShellButton {
                        theme: root.context.theme
                        label: ""
                        iconName: "refresh"
                        compact: true
                        ghost: true
                        busy: root.service.refreshing
                        accessibleName: "Refresh agent limits"
                        onClicked: root.service.refresh(true)
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: root.context.theme.semantic.outline.subtle
                }

                Ui.ShellStatus {
                    Layout.fillWidth: true
                    visible: root.service.lastError !== ""
                    theme: root.context.theme
                    status: "danger"
                    iconName: "error"
                    label: root.service.lastError
                    wrap: true
                    maximumLines: 3
                }

                Ui.ShellStateView {
                    Layout.fillWidth: true
                    visible: !root.service.available
                    theme: root.context.theme
                    mode: "error"
                    title: "Usage helper unavailable"
                    message: "The fixed Stillsuit usage collector is not configured."
                    iconName: "agent"
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(accountList.implicitHeight, 520)
                    visible: root.service.available
                    clip: true
                    contentWidth: width
                    contentHeight: accountList.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height

                    ColumnLayout {
                        id: accountList

                        width: parent.width
                        spacing: root.context.theme.metrics.spaceUnit * 2

                        Ui.ShellStateView {
                            Layout.fillWidth: true
                            visible: root.service.accountCount === 0
                            theme: root.context.theme
                            mode: "empty"
                            title: "No accounts found"
                            message: "Sign in with Codex or Claude Code, or add a configured account."
                            iconName: "agent"
                        }

                        Repeater {
                            model: root.service.accounts

                            delegate: Ui.ShellSurface {
                                id: accountCard

                                required property var modelData
                                readonly property var account: modelData || ({})
                                readonly property var windows: account && account.windows
                                    ? account.windows : []
                                readonly property color providerColor:
                                    String(account.provider) === "claude"
                                        ? root.context.theme.semantic.status.warning
                                        : root.context.theme.semantic.accent.primary

                                Layout.fillWidth: true
                                Layout.preferredHeight: cardContent.implicitHeight + 18
                                theme: root.context.theme
                                kind: "raised"

                                Rectangle {
                                    anchors {
                                        top: parent.top
                                        bottom: parent.bottom
                                        left: parent.left
                                    }
                                    width: 3
                                    color: accountCard.providerColor
                                }

                                ColumnLayout {
                                    id: cardContent

                                    anchors {
                                        top: parent.top
                                        left: parent.left
                                        right: parent.right
                                        leftMargin: 12
                                        rightMargin: 10
                                        topMargin: 9
                                    }
                                    spacing: root.context.theme.metrics.spaceUnit * 2

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: root.context.theme.metrics.spaceUnit * 2

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0

                                            Ui.ShellText {
                                                Layout.fillWidth: true
                                                theme: root.context.theme
                                                text: String(accountCard.account.provider) === "claude"
                                                    ? "CLAUDE CODE" : "CODEX"
                                                sizeRole: "section"
                                                monospace: true
                                                color: accountCard.providerColor
                                            }

                                            Ui.ShellText {
                                                Layout.fillWidth: true
                                                theme: root.context.theme
                                                text: String(accountCard.account.label || "Account")
                                                sizeRole: "label"
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Ui.ShellText {
                                            visible: String(accountCard.account.plan || "") !== ""
                                            theme: root.context.theme
                                            text: String(accountCard.account.plan || "")
                                            sizeRole: "caption"
                                            role: "secondary"
                                        }

                                    }

                                    Ui.ShellText {
                                        Layout.fillWidth: true
                                        visible: String(accountCard.account.identity || "") !== ""
                                        theme: root.context.theme
                                        text: String(accountCard.account.identity || "")
                                        sizeRole: "caption"
                                        role: "muted"
                                        elide: Text.ElideRight
                                    }

                                    Ui.ShellStatus {
                                        Layout.fillWidth: true
                                        visible: String(accountCard.account.status || "") !== "ready"
                                        theme: root.context.theme
                                        status: root.service.statusRole(accountCard.account)
                                        showIcon: false
                                        label: String(accountCard.account.statusText || "Unavailable")
                                        compact: true
                                    }

                                    Repeater {
                                        model: accountCard.windows

                                        delegate: ColumnLayout {
                                            id: windowRow

                                            required property var modelData
                                            readonly property var windowData: modelData || ({})
                                            readonly property real used: Math.max(0,
                                                Math.min(1, Number(windowData.used || 0)))

                                            Layout.fillWidth: true
                                            spacing: 3

                                            RowLayout {
                                                Layout.fillWidth: true

                                                Ui.ShellText {
                                                    Layout.fillWidth: true
                                                    theme: root.context.theme
                                                    text: String(windowRow.windowData.label || "Limit")
                                                    sizeRole: "caption"
                                                    role: "secondary"
                                                }

                                                Ui.ShellText {
                                                    theme: root.context.theme
                                                    text: Math.round(windowRow.used * 100) + "%"
                                                    sizeRole: "caption"
                                                    monospace: true
                                                    color: root._usageColor(windowRow.used)
                                                }
                                            }

                                            Rectangle {
                                                Layout.fillWidth: true
                                                implicitHeight: 6
                                                radius: 3
                                                color: root.context.theme.semantic.outline.subtle

                                                Rectangle {
                                                    anchors {
                                                        top: parent.top
                                                        bottom: parent.bottom
                                                        left: parent.left
                                                    }
                                                    width: parent.width * windowRow.used
                                                    radius: parent.radius
                                                    color: root._usageColor(windowRow.used)
                                                }
                                            }

                                            Ui.ShellText {
                                                Layout.fillWidth: true
                                                visible: String(windowRow.windowData.resetsAt || "") !== ""
                                                theme: root.context.theme
                                                text: root._resetText(windowRow.windowData.resetsAt)
                                                sizeRole: "caption"
                                                role: "muted"
                                                horizontalAlignment: Text.AlignRight
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Ui.ShellText {
                    Layout.fillWidth: true
                    visible: root.service.updatedAt !== ""
                    theme: root.context.theme
                    text: root._updatedText(root.service.updatedAt)
                    sizeRole: "caption"
                    role: "muted"
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }

    function _usageColor(used) {
        if (used >= 0.9)
            return context.theme.semantic.status.danger
        if (used >= 0.7)
            return context.theme.semantic.status.warning
        return context.theme.semantic.status.success
    }

    function _resetText(value) {
        var resetMs = Date.parse(String(value || ""))
        if (!isFinite(resetMs))
            return ""
        var remaining = Math.max(0, resetMs - nowMs)
        if (remaining === 0)
            return "Resetting now"
        var minutes = Math.ceil(remaining / 60000)
        var days = Math.floor(minutes / 1440)
        var hours = Math.floor((minutes % 1440) / 60)
        var rest = minutes % 60
        if (days > 0)
            return "Resets in " + days + "d " + hours + "h"
        if (hours > 0)
            return "Resets in " + hours + "h " + rest + "m"
        return "Resets in " + rest + "m"
    }

    function _updatedText(value) {
        var updated = Date.parse(String(value || ""))
        if (!isFinite(updated))
            return ""
        var seconds = Math.max(0, Math.floor((nowMs - updated) / 1000))
        if (seconds < 60)
            return "Updated just now"
        var minutes = Math.floor(seconds / 60)
        return "Updated " + minutes + "m ago"
    }
}
