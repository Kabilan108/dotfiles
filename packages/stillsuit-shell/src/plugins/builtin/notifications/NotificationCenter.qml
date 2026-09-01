import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../ui" as Ui

Scope {
    id: root

    required property var context
    required property var screen
    required property var service

    property string outputId: String(screen.name || "")
    readonly property var rows: service ? service.centerRows() : []
    readonly property var theme: context.theme

    function open(payloadJson) {
        return service ? service.openCenter(outputId) : "error"
    }

    function close() {
        return service ? service.closeCenter(outputId) : "error"
    }

    function toggle(payloadJson) {
        return service ? service.toggleCenter(outputId) : "error"
    }

    function relativeTime(timestamp) {
        var minutes = Math.floor(Math.max(0, Date.now() - Number(timestamp || 0)) / 60000)
        if (minutes < 1) return "now"
        if (minutes < 60) return String(minutes) + "m"
        var hours = Math.floor(minutes / 60)
        return hours < 24 ? String(hours) + "h" : String(Math.floor(hours / 24)) + "d"
    }

    PanelWindow {
        id: centerWindow

        screen: root.screen
        visible: root.service && root.service.centerOutputId === root.outputId
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusiveZone: 0
        focusable: true
        color: "transparent"
        mask: Region {
            y: root.theme.metrics.barHeight
            width: centerWindow.width
            height: Math.max(0, centerWindow.height - y)
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.service.closeCenter(root.outputId)
        }

        Ui.ShellSurface {
            id: panel

            anchors {
                top: parent.top
                right: parent.right
                topMargin: root.theme.metrics.barHeight + root.theme.metrics.spaceUnit * 2
                rightMargin: root.theme.metrics.spaceUnit * 2
            }
            width: root.theme.metrics.panelWidth
            height: Math.min(panelLayout.implicitHeight + root.theme.metrics.panelPadding * 2,
                parent.height - anchors.topMargin - root.theme.metrics.spaceUnit * 2)
            theme: root.theme
            kind: "panel"

            MouseArea {
                anchors.fill: parent
                onClicked: mouse => mouse.accepted = true
            }

            ColumnLayout {
                id: panelLayout

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: root.theme.metrics.panelPadding
                }
                spacing: root.theme.metrics.spaceUnit * 2

                RowLayout {
                    Layout.fillWidth: true

                    Ui.ShellText {
                        theme: root.theme
                        text: "Notifications"
                        sizeRole: "heading"
                    }

                    Ui.ShellText {
                        theme: root.theme
                        text: String(root.rows.length) + " recent"
                        sizeRole: "caption"
                        role: "muted"
                        monospace: true
                    }

                    Item { Layout.fillWidth: true }

                    Ui.ShellButton {
                        visible: root.rows.length > 0
                        theme: root.theme
                        label: "Clear all"
                        iconName: "delete"
                        compact: true
                        ghost: true
                        destructive: true
                        accessibleName: "Delete all notification history"
                        onClicked: root.service.clearHistory()
                    }
                }

                Ui.ShellToggle {
                    Layout.fillWidth: true
                    theme: root.theme
                    label: "Do not disturb"
                    description: "Hide banners and retain notifications in history"
                    checked: root.service ? root.service.doNotDisturb : false
                    onToggled: requestedChecked => root.service.setDnd(requestedChecked)
                }

                Ui.ShellStatus {
                    visible: root.service && root.service.doNotDisturb
                    Layout.fillWidth: true
                    theme: root.theme
                    status: "muted"
                    iconName: "notifications"
                    label: "Banners hidden; history is still retained"
                    accessibleName: label
                }

                Flickable {
                    Layout.fillWidth: true
                    implicitHeight: Math.min(centerColumn.implicitHeight, 420)
                    contentHeight: centerColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height

                    ColumnLayout {
                        id: centerColumn

                        width: parent.width
                        spacing: root.theme.metrics.spaceUnit * 2

                        Repeater {
                            model: root.rows

                            NotificationCard {
                                required property var modelData

                                context: root.context
                                service: root.service
                                snapshot: modelData
                                inline: true
                                timeText: root.relativeTime(modelData.timestamp)
                                Layout.fillWidth: true
                            }
                        }

                        Ui.ShellStateView {
                            visible: root.rows.length === 0
                            Layout.fillWidth: true
                            theme: root.theme
                            mode: "empty"
                            iconName: "notifications"
                            title: "No notifications"
                            message: "New alerts will appear here."
                        }
                    }
                }
            }
        }
    }
}
