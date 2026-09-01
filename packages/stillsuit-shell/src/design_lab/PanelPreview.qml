import QtQuick
import QtQuick.Layouts
import "../ui" as Ui

Ui.ShellSurface {
    id: root

    property bool wifiEnabled: true
    property bool dndEnabled: false
    property real volume: 0.58

    implicitWidth: theme.metrics.panelWidth
    implicitHeight: contentColumn.implicitHeight + theme.metrics.panelPadding * 2
    kind: "panel"

    ColumnLayout {
        id: contentColumn
        anchors {
            fill: parent
            margins: root.theme.metrics.panelPadding
        }
        spacing: root.theme.metrics.spaceUnit * 3

        RowLayout {
            Layout.fillWidth: true

            Ui.ShellIcon {
                theme: root.theme
                name: "network"
                role: "primary"
                sizeRole: "large"
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Ui.ShellText {
                    theme: root.theme
                    text: "Network"
                    sizeRole: "heading"
                }

                Ui.ShellText {
                    theme: root.theme
                    text: root.wifiEnabled ? "Connected to Arrakis" : "Wireless disabled"
                    role: "secondary"
                    sizeRole: "caption"
                }
            }

            Ui.ShellButton {
                theme: root.theme
                label: ""
                iconName: "refresh"
                compact: true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: root.theme.semantic.outline.subtle
        }

        Ui.ShellToggle {
            Layout.fillWidth: true
            theme: root.theme
            label: "Wi-Fi"
            description: "Radio and automatic connections"
            checked: root.wifiEnabled
            onToggled: checked => root.wifiEnabled = checked
        }

        Ui.ShellToggle {
            Layout.fillWidth: true
            theme: root.theme
            label: "Do not disturb"
            description: "Retain alerts without showing toasts"
            checked: root.dndEnabled
            onToggled: checked => root.dndEnabled = checked
        }

        Ui.ShellSlider {
            Layout.fillWidth: true
            theme: root.theme
            label: "Output volume"
            value: root.volume
            decimals: 0
            suffix: "%"
            to: 100
            Component.onCompleted: value = root.volume * 100
            onMoved: value => root.volume = value / 100
        }

        Ui.ShellText {
            theme: root.theme
            text: "AVAILABLE NETWORKS"
            sizeRole: "caption"
            role: "muted"
            monospace: true
        }

        Repeater {
            model: [
                { name: "Arrakis", detail: "connected · 866 Mbps", active: true },
                { name: "Sietch Guest", detail: "secured · strong signal", active: false },
                { name: "Guild Relay", detail: "secured · medium signal", active: false }
            ]

            Rectangle {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: root.theme.metrics.rowHeight
                radius: root.theme.metrics.radiusSmall
                color: modelData.active ? root.theme.component.panel.rowSelected : "transparent"

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 10
                    }
                    spacing: 8

                    Ui.ShellIcon {
                        theme: root.theme
                        name: "wifi"
                        sizeRole: "small"
                        color: modelData.active
                            ? root.theme.semantic.accent.primary
                            : root.theme.semantic.content.secondary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Ui.ShellText {
                            theme: root.theme
                            text: modelData.name
                            sizeRole: "label"
                        }

                        Ui.ShellText {
                            theme: root.theme
                            text: modelData.detail
                            role: "muted"
                            sizeRole: "caption"
                        }
                    }

                    Ui.ShellIcon {
                        visible: modelData.active
                        theme: root.theme
                        name: "check"
                        sizeRole: "small"
                        color: root.theme.semantic.accent.primary
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Ui.ShellButton {
                theme: root.theme
                label: "Cancel"
            }

            Item {
                Layout.fillWidth: true
            }

            Ui.ShellButton {
                theme: root.theme
                label: "Apply"
                iconName: "check"
                active: true
            }
        }
    }
}
