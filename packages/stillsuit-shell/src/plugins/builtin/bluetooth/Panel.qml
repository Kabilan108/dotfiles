import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../ui" as Ui

Item {
    id: root
    readonly property bool hostedPanel: true
    implicitWidth: root.context.theme.metrics.panelWidth
    implicitHeight: panelContent.implicitHeight + root.context.theme.metrics.panelPadding * 2
    visible: false
    property bool opened: false

    required property var context
    required property var service
    required property var screen
    required property string outputId

    Ui.ShellSurface {
        id: panelSurface

        anchors.fill: parent

        theme: root.context.theme
        kind: "panel"

        MouseArea {
            anchors.fill: parent
            onClicked: function (mouse) {
                mouse.accepted = true;
            }
        }

        ColumnLayout {
            id: panelContent

            anchors.fill: parent
            anchors.margins: root.context.theme.metrics.panelPadding
            spacing: 10

            Ui.ShellPanelHeader {
                Layout.fillWidth: true
                theme: root.context.theme
                title: "Bluetooth"
                Ui.ShellButton {
                    theme: root.context.theme
                    label: ""
                    iconName: "settings"
                    compact: true
                    ghost: true
                    accessibleName: "Open bluetooth settings"
                    onClicked: root.openManager()
                }
            }

            Ui.ShellToggle {
                Layout.fillWidth: true
                theme: root.context.theme
                label: "BlueZ adapter"
                checked: Boolean(root.service && root.service.enabled)
                busy: root.service && root.service.operation === "adapter"
                interactive: Boolean(root.service && root.service.available)
                onToggled: function (requested) {
                    root.service.setEnabled(requested);
                }
            }

            Ui.ShellStatus {
                Layout.fillWidth: true
                visible: root.service && root.service.lastError !== ""
                theme: root.context.theme
                status: "danger"
                iconName: "danger"
                label: root.service ? root.service.lastError : ""
            }

            Ui.ShellStateView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !root.service || !root.service.available
                theme: root.context.theme
                mode: "error"
                title: "Bluetooth unavailable"
                message: "No BlueZ adapter is available."
                iconName: "bluetooth"
            }

            ColumnLayout {
                id: deviceColumn

                Layout.fillWidth: true
                visible: root.service && root.service.available && root.service.enabled
                spacing: 6

                Ui.ShellScrollArea {
                    theme: root.context.theme
                    maximumHeight: 203
                    Layout.fillWidth: true
                    visible: root.service.connectedDevices.length > 0 || root.service.pairedDevices.length > 0
                    contentHeight: knownDeviceColumn.implicitHeight

                    ColumnLayout {
                        id: knownDeviceColumn

                        width: parent.width
                        spacing: 6

                        Ui.ShellSectionLabel {
                            visible: root.service.connectedDevices.length > 0
                            Layout.fillWidth: true
                            theme: root.context.theme
                            text: "Connected"
                        }

                        Repeater {
                            model: root.service.connectedDevices

                            delegate: DeviceRow {
                                required property var modelData
                                Layout.fillWidth: true
                                device: modelData
                                group: "connected"
                            }
                        }

                        Ui.ShellSectionLabel {
                            visible: root.service.pairedDevices.length > 0
                            Layout.fillWidth: true
                            theme: root.context.theme
                            text: "Paired"
                        }

                        Repeater {
                            model: root.service.pairedDevices

                            delegate: DeviceRow {
                                required property var modelData
                                Layout.fillWidth: true
                                device: modelData
                                group: "paired"
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Ui.ShellSectionLabel {
                        Layout.fillWidth: true
                        theme: root.context.theme
                        text: "Available"
                    }

                    Ui.ShellButton {
                        theme: root.context.theme
                        label: root.service.scanning ? "Stop" : "Scan"
                        iconName: root.service.scanning ? "close" : "refresh"
                        compact: true
                        ghost: true
                        accessibleName: root.service.scanning ? "Stop scanning for Bluetooth devices" : "Scan for Bluetooth devices"
                        onClicked: root.service.scanning ? root.service.stopScan() : root.service.scan()
                    }
                }

                Ui.ShellScrollArea {
                    theme: root.context.theme
                    maximumHeight: 244
                    Layout.fillWidth: true
                    contentHeight: availableDeviceColumn.implicitHeight

                    ColumnLayout {
                        id: availableDeviceColumn

                        width: parent.width
                        spacing: 6

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            visible: root.service.availableDevices.length === 0
                            spacing: 8

                            Ui.ShellBusyIndicator {
                                visible: root.service.scanning
                                theme: root.context.theme
                                sizeRole: "small"
                                role: "muted"
                            }

                            Ui.ShellIcon {
                                visible: !root.service.scanning
                                theme: root.context.theme
                                name: "bluetooth"
                                sizeRole: "small"
                                role: "muted"
                            }

                            Ui.ShellText {
                                theme: root.context.theme
                                text: root.service.scanning ? "Scanning" : "No available devices"
                                sizeRole: "caption"
                                role: "muted"
                            }
                        }

                        Repeater {
                            model: root.service.availableDevices

                            delegate: DeviceRow {
                                required property var modelData
                                Layout.fillWidth: true
                                device: modelData
                                group: "available"
                            }
                        }
                    }
                }
            }
        }
    }

    component DeviceRow: Ui.ShellRow {
        id: row

        required property var device
        required property string group
        readonly property string stateLabel: root.service.statusFor(device)
        readonly property string failure: root.service.failureFor(device)
        readonly property string battery: root.service.batteryText(device)

        theme: root.context.theme
        label: root.service.deviceName(device)
        description: failure !== "" ? failure : battery !== "" ? battery : group === "available" ? String(device.address || "Ready to pair") : "Paired with BlueZ"
        iconName: group === "connected" ? "headphones" : "bluetooth"
        trailingText: stateLabel
        selected: group === "connected"
        danger: failure !== ""
        busy: ["pairing", "connecting", "disconnecting", "forgetting", "selecting audio"].indexOf(stateLabel) !== -1
        interactive: root.service.operation === "idle" && failure === ""
        accessibleName: label + ", " + stateLabel
        onClicked: root.service.toggle(device)

        Ui.ShellButton {
            visible: row.group !== "available"
            theme: root.context.theme
            label: "Forget"
            iconName: "delete"
            compact: true
            ghost: true
            destructive: true
            interactive: root.service.operation === "idle"
            accessibleName: "Forget " + row.label
            onClicked: root.service.forgetDevice(row.device)
        }
    }

    function open(payloadJson) {
        root.opened = true;
    }

    function openManager() {
        return service ? service.openManager() : "unavailable";
    }

    function close() {
        if (service)
            service.stopScan();
        root.opened = false;
    }
}
