import QtQuick
import QtQuick.Layouts
import "../ui" as Ui

ColumnLayout {
    id: root

    required property var theme
    property int stateIndex: 0
    readonly property var states: [
        {
            label: "Unread",
            colorRole: "unread",
            icon: "notifications",
            title: "Meeting notes are ready",
            body: "The transcript, summary, and task candidates passed validation.",
            time: "now",
            secondaryAction: "Dismiss",
            primaryAction: "Open"
        },
        {
            label: "Info",
            colorRole: "info",
            icon: "info",
            title: "System update available",
            body: "The update can be downloaded without interrupting this session.",
            time: "1m",
            secondaryAction: "Later",
            primaryAction: "Review"
        },
        {
            label: "Success",
            colorRole: "success",
            icon: "success",
            title: "Backup complete",
            body: "Coppermind finished syncing 148 changed files.",
            time: "1m",
            secondaryAction: "Dismiss",
            primaryAction: "Details"
        },
        {
            label: "Warning",
            colorRole: "warning",
            icon: "warning",
            title: "Battery at 15%",
            body: "Connect power or switch to the power-saver profile.",
            time: "2m",
            secondaryAction: "Dismiss",
            primaryAction: "Power"
        },
        {
            label: "Urgent",
            colorRole: "danger",
            icon: "danger",
            title: "Recording stopped",
            body: "The capture process exited before the meeting was queued.",
            time: "now",
            secondaryAction: "Dismiss",
            primaryAction: "Retry"
        },
        {
            label: "Quiet",
            colorRole: "muted",
            icon: "notifications",
            title: "Notification retained",
            body: "Do not disturb hid the toast. The item remains in history.",
            time: "8m",
            secondaryAction: "Clear",
            primaryAction: "View"
        }
    ]
    readonly property var stateData: states[stateIndex]
    readonly property color stateColor: theme.component.notification[stateData.colorRole]

    spacing: 8

    Ui.ShellText {
        theme: root.theme
        text: "NOTIFICATION STATE"
        sizeRole: "caption"
        role: "muted"
        monospace: true
    }

    Flow {
        Layout.fillWidth: true
        width: parent.width
        spacing: 7

        Repeater {
            model: root.states

            Ui.ShellButton {
                required property var modelData
                required property int index

                theme: root.theme
                label: modelData.label
                compact: true
                active: index === root.stateIndex
                onClicked: root.stateIndex = index
            }
        }
    }

    Ui.ShellSurface {
        Layout.fillWidth: true
        Layout.preferredHeight: contentColumn.implicitHeight + 28
        theme: root.theme
        kind: "notification"
        border.width: root.stateData.colorRole === "danger" ? 2 : 1
        border.color: root.stateData.colorRole === "danger"
            ? root.stateColor
            : root.theme.component.notification.border

        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: 3
            color: root.stateColor
        }

        ColumnLayout {
            id: contentColumn
            anchors {
                fill: parent
                margins: 14
            }
            spacing: 8

            RowLayout {
                Layout.fillWidth: true

                Ui.ShellIcon {
                    theme: root.theme
                    name: root.stateData.icon
                    color: root.stateColor
                }

                Ui.ShellText {
                    Layout.fillWidth: true
                    theme: root.theme
                    text: root.stateData.title
                    sizeRole: "label"
                }

                Ui.ShellText {
                    theme: root.theme
                    text: root.stateData.time
                    sizeRole: "caption"
                    role: "muted"
                    monospace: true
                }
            }

            Ui.ShellText {
                Layout.fillWidth: true
                theme: root.theme
                text: root.stateData.body
                role: "secondary"
                wrapMode: Text.Wrap
            }

            RowLayout {
                Layout.fillWidth: true

                Item {
                    Layout.fillWidth: true
                }

                Ui.ShellButton {
                    theme: root.theme
                    label: root.stateData.secondaryAction
                    compact: true
                }

                Ui.ShellButton {
                    theme: root.theme
                    label: root.stateData.primaryAction
                    compact: true
                    active: true
                }
            }
        }
    }
}
