import QtQuick
import QtQuick.Layouts
import "../ui" as Ui

Ui.ShellSurface {
    id: root

    property int previewStateIndex: 0
    property real volume: 0.45
    readonly property var previewStates: [
        { key: "connected", label: "Connected" },
        { key: "scanning", label: "Scanning" },
        { key: "joining", label: "Joining" },
        { key: "off", label: "Wi-Fi off" },
        { key: "error", label: "Failure" }
    ]
    readonly property var previewState: previewStates[previewStateIndex]
    readonly property bool wifiEnabled: previewState.key !== "off"

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
                spacing: 1

                Ui.ShellText {
                    theme: root.theme
                    text: "Network"
                    sizeRole: "heading"
                }

                Ui.ShellText {
                    theme: root.theme
                    text: root._headerDetail()
                    role: root.previewState.key === "error" ? "primary" : "secondary"
                    color: root.previewState.key === "error"
                        ? root.theme.semantic.status.danger
                        : root.theme.semantic.content.secondary
                    sizeRole: "caption"
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Ui.ShellButton {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                theme: root.theme
                label: "Scan"
                iconName: "refresh"
                compact: true
                ghost: true
                enabled: root.wifiEnabled
                onClicked: root.previewStateIndex = 1
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
            onToggled: checked => root.previewStateIndex = checked ? 0 : 3
        }

        Ui.ShellSlider {
            Layout.fillWidth: true
            theme: root.theme
            label: "Output volume"
            value: root.volume * 100
            decimals: 0
            suffix: "%"
            to: 100
            onMoved: value => root.volume = value / 100
        }

        Ui.ShellText {
            theme: root.theme
            text: "NETWORK PREVIEW STATE"
            sizeRole: "caption"
            role: "muted"
            monospace: true
        }

        Flow {
            Layout.fillWidth: true
            width: parent.width
            spacing: 6

            Repeater {
                model: root.previewStates

                Ui.ShellButton {
                    required property var modelData
                    required property int index

                    theme: root.theme
                    label: modelData.label
                    compact: true
                    active: index === root.previewStateIndex
                    onClicked: root.previewStateIndex = index
                }
            }
        }

        Ui.ShellText {
            theme: root.theme
            text: "AVAILABLE NETWORKS"
            sizeRole: "caption"
            role: "muted"
            monospace: true
        }

        Item {
            visible: root.previewState.key === "off"
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 94 : 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 4

                Ui.ShellIcon {
                    Layout.alignment: Qt.AlignHCenter
                    theme: root.theme
                    name: "wifi-off"
                    sizeRole: "large"
                    role: "muted"
                }

                Ui.ShellText {
                    Layout.alignment: Qt.AlignHCenter
                    theme: root.theme
                    text: "Wi-Fi is off"
                    sizeRole: "label"
                }

                Ui.ShellText {
                    Layout.alignment: Qt.AlignHCenter
                    theme: root.theme
                    text: "Turn it on to scan for nearby networks."
                    sizeRole: "caption"
                    role: "muted"
                }
            }
        }

        Repeater {
            model: root.previewState.key === "off" ? [] : root._rowsForState()

            Rectangle {
                required property var modelData

                Layout.fillWidth: true
                Layout.preferredHeight: root.theme.metrics.rowHeight
                radius: root.theme.metrics.radiusSmall
                color: modelData.state === "error"
                    ? root.theme.component.panel.rowDanger
                    : modelData.selected ? root.theme.component.panel.rowSelected : "transparent"
                border.width: 0
                opacity: modelData.state === "scanning" ? 0.64 : 1

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 10
                    }
                    spacing: 8

                    Ui.ShellIcon {
                        Layout.preferredWidth: root.theme.metrics.iconMedium
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                        theme: root.theme
                        name: modelData.icon || "wifi"
                        sizeRole: "small"
                        color: root._rowColor(modelData)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Ui.ShellText {
                            theme: root.theme
                            text: modelData.name
                            sizeRole: "label"
                            color: modelData.state === "error"
                                ? root.theme.semantic.status.danger
                                : root.theme.semantic.content.primary
                        }

                        Ui.ShellText {
                            theme: root.theme
                            text: modelData.detail
                            role: "muted"
                            sizeRole: "caption"
                        }
                    }

                    Ui.ShellIcon {
                        visible: modelData.trailing !== ""
                        Layout.preferredWidth: root.theme.metrics.iconMedium
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                        theme: root.theme
                        name: modelData.trailing
                        sizeRole: "small"
                        color: root._rowColor(modelData)
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
                label: root.previewState.key === "error" ? "Retry" : "Apply"
                iconName: root.previewState.key === "error" ? "refresh" : "check"
                active: true
            }
        }
    }

    function _headerDetail() {
        if (previewState.key === "scanning")
            return "Scanning for nearby networks"
        if (previewState.key === "joining")
            return "Joining Sietch Guest"
        if (previewState.key === "off")
            return "Wireless disabled"
        if (previewState.key === "error")
            return "Could not join Sietch Guest"
        return "Connected to Arrakis"
    }

    function _rowsForState() {
        if (previewState.key === "scanning") {
            return [
                { name: "Scanning nearby networks", detail: "Checking 2.4 and 5 GHz bands", state: "scanning", selected: false, icon: "refresh", trailing: "" },
                { name: "Arrakis", detail: "saved network", state: "saved", selected: false, icon: "wifi", trailing: "" },
                { name: "Sietch Guest", detail: "secured · strong signal", state: "available", selected: false, icon: "wifi", trailing: "" }
            ]
        }
        if (previewState.key === "joining") {
            return [
                { name: "Arrakis", detail: "saved network", state: "saved", selected: false, icon: "wifi", trailing: "" },
                { name: "Sietch Guest", detail: "requesting an address…", state: "joining", selected: true, icon: "wifi", trailing: "refresh" },
                { name: "Guild Relay", detail: "secured · medium signal", state: "available", selected: false, icon: "wifi", trailing: "" }
            ]
        }
        if (previewState.key === "error") {
            return [
                { name: "Sietch Guest", detail: "Authentication failed. Check the password.", state: "error", selected: false, icon: "danger", trailing: "warning" },
                { name: "Arrakis", detail: "saved network", state: "saved", selected: false, icon: "wifi", trailing: "" },
                { name: "Guild Relay", detail: "secured · medium signal", state: "available", selected: false, icon: "wifi", trailing: "" }
            ]
        }
        return [
            { name: "Arrakis", detail: "connected · 866 Mbps", state: "connected", selected: true, icon: "wifi", trailing: "check" },
            { name: "Sietch Guest", detail: "saved · strong signal", state: "saved", selected: false, icon: "wifi", trailing: "" },
            { name: "Guild Relay", detail: "secured · weak signal", state: "available", selected: false, icon: "wifi", trailing: "" }
        ]
    }

    function _rowColor(row) {
        if (row.state === "error")
            return theme.semantic.status.danger
        if (row.state === "joining" || row.state === "connected")
            return theme.semantic.accent.primary
        return theme.semantic.content.secondary
    }
}
